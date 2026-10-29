import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_services.dart';
import 'package:mathani/platform/prayer_notifications_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.mathani.notifications');
  const iosChannel = MethodChannel('dexterous.com/flutter/local_notifications');
  final now = DateTime.now().toUtc().add(const Duration(days: 2));
  final place = SavedLocation(
    id: 'home',
    label: 'Private place',
    latitude: 30,
    longitude: 31,
    timezoneId: 'Africa/Cairo',
    source: LocationSource.manual,
    confirmedAtUtc: now,
  );
  PrayerState state() => PrayerState(
    generation: 1,
    locations: [place],
    activeLocationId: 'home',
    reminders: ReminderPreferences(
      enabledPrayers: {PrayerKind.fajr},
      acknowledgedFallbacks: {'system_notification': 1},
    ),
  );
  ScheduledReminder event(String id, int minutes) => ScheduledReminder(
    eventId: id,
    locationId: 'home',
    generation: 1,
    kind: PrayerKind.fajr,
    dueAtUtc: now.add(Duration(minutes: minutes)),
    expiresAtUtc: now.add(Duration(minutes: minutes, seconds: 60)),
    audioId: 'system_default',
    mode: AthanMode.opening,
    deliveryMechanism: 'systemDefault',
  );
  late List<MethodCall> calls;
  late List<dynamic> pending;
  late bool loseFirst;
  late bool ignoreCancellation;
  setUp(() {
    calls = [];
    pending = [];
    loseFirst = false;
    ignoreCancellation = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'capabilities') {
            return {
              'permissionStatus': 'granted',
              'exactAlarmAccess': true,
              'dailyRestricted': false,
              'qiyamRestricted': true,
            };
          }
          if (call.method == 'replace') {
            final args = call.arguments as Map;
            pending = [
              for (final row in args['events'] as List)
                {
                  'eventId': row['eventId'],
                  'generation': args['generation'],
                  'dueAtMs': row['dueAtMs'],
                },
            ];
          }
          if (call.method == 'pending') {
            return loseFirst ? pending.skip(1).toList() : pending;
          }
          if (call.method == 'cancelAll' && !ignoreCancellation) pending = [];
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(iosChannel, null);
  });
  PrayerNativeNotifications adapter() => PrayerNativeNotifications(
    title: 'Mathani',
    body: (kind) => kind.name,
    android: true,
    channel: channel,
    clock: () => now,
  );
  test(
    'cancellation is not confirmed while a native pending token remains',
    () async {
      final subject = adapter();
      await subject.replace(state(), [event('a', 1)]);
      ignoreCancellation = true;
      await expectLater(subject.cancelAll(), throwsA(isA<PrayerException>()));
    },
  );
  test('native capabilities never prompt and channel restrictions stay independent', () async {
    final capability = await adapter().capabilities();
    expect(calls.map((call) => call.method), ['capabilities']);
    expect(capability.restrictedPrayers, {PrayerKind.qiyam});
    expect(capability.backgroundModes, {AthanMode.opening});
  });
  test('replace verifies every returned token, contains no location presentation or coordinates', () async {
    final result = await adapter().replace(state(), [
      event('a', 1),
      event('b', 2),
    ]);
    expect(result.scheduledThroughUtc, event('b', 2).dueAtUtc);
    final data = calls
        .firstWhere((call) => call.method == 'replace')
        .arguments
        .toString();
    expect(data.contains('Private place'), false);
    expect(data.contains('latitude'), false);
    expect(data.contains('longitude'), false);
    loseFirst = true;
    await expectLater(
      adapter().replace(state(), [event('a', 1), event('b', 2)]),
      throwsA(isA<PrayerException>()),
    );
    expect(pending, isEmpty);
  });
  test(
    'no implicit audio fallback is accepted by the native adapter',
    () async {
      final unacknowledged = PrayerState(
        generation: 1,
        locations: [place],
        activeLocationId: 'home',
        reminders: ReminderPreferences(enabledPrayers: {PrayerKind.fajr}),
      );
      await expectLater(
        adapter().replace(unacknowledged, [event('a', 1)]),
        throwsA(isA<PrayerException>()),
      );
      expect(calls.any((call) => call.method == 'replace'), false);
    },
  );
  test('iOS initializes without permission prompts, bounds IDs and verifies pending OS requests', () async {
    final nativeCalls = <MethodCall>[];
    final requests = <Map<String, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(iosChannel, (call) async {
          nativeCalls.add(call);
          switch (call.method) {
            case 'initialize':
              return true;
            case 'checkPermissions':
              return {
                'isEnabled': true,
                'isSoundEnabled': true,
                'isAlertEnabled': true,
              };
            case 'pendingNotificationRequests':
              return requests;
            case 'zonedSchedule':
              final args = call.arguments as Map;
              requests.add({
                'id': args['id'],
                'title': args['title'],
                'body': args['body'],
                'payload': args['payload'],
              });
              return null;
            case 'cancel':
              requests.removeWhere((item) => item['id'] == call.arguments);
              return null;
          }
          return null;
        });
    final subject = PrayerNativeNotifications(
      title: 'Mathani',
      body: (_) => 'Prayer',
      android: false,
      clock: () => now,
    );
    await subject.capabilities();
    final init =
        nativeCalls.firstWhere((call) => call.method == 'initialize').arguments
            as Map;
    expect(init['requestAlertPermission'], false);
    expect(init['requestSoundPermission'], false);
    final result = await subject.replace(state(), [
      event('a', 1),
      event('b', 2),
    ]);
    expect(result.scheduledThroughUtc, event('b', 2).dueAtUtc);
    expect(
      nativeCalls.any((call) => call.method == 'requestPermissions'),
      false,
    );
    await subject.cancelAll();
    expect(requests, isEmpty);
  });
}
