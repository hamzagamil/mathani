import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_services.dart';
import 'package:mathani/platform/prayer_notifications_page.dart';

class PagePort implements PrayerPagePort {
  bool visible = true, secure = true, supported = true;
  String permission = 'default';
  int prompts = 0, notices = 0, closed = 0;
  final changes = StreamController<bool>.broadcast(sync: true);
  @override
  bool get active => visible;
  @override
  bool get secureContext => secure;
  @override
  bool get notificationsSupported => supported;
  @override
  String get notificationPermission => permission;
  @override
  Stream<bool> get activityChanges => changes.stream;
  @override
  Future<void> requestNotificationPermission() async {
    prompts++;
    permission = 'denied';
  }

  @override
  void Function()? showSilentNotification(ScheduledReminder event) {
    notices++;
    return () {
      closed++;
    };
  }

  void hide() {
    visible = false;
    changes.add(false);
  }

  void show() {
    visible = true;
    changes.add(true);
  }
}

class PageAudio implements PrayerAudio {
  final played = <String>[];
  int stopped = 0;
  bool reject = false;
  Completer<void>? pending;
  @override
  Future<void> play(ScheduledReminder event) async {
    if (reject) throw const PrayerException(PrayerFailure.audioUnavailable);
    played.add(event.eventId);
    await pending?.future;
  }

  @override
  Future<void> stop() async {
    stopped++;
  }

  @override
  Future<void> preview(AthanRecording recording) async {}
}

void main() {
  final due = DateTime.utc(2026, 10, 29, 12);
  late DateTime now;
  late PagePort port;
  late PageAudio audio;
  late PrayerPageNotifications adapter;
  late List<PrayerPageDelivery> deliveries;
  final place = SavedLocation(
    id: 'home',
    label: 'Home',
    latitude: 30,
    longitude: 31,
    timezoneId: 'Africa/Cairo',
    source: LocationSource.manual,
    confirmedAtUtc: due,
  );
  PrayerState state(int generation) => PrayerState(
    generation: generation,
    locations: [place],
    activeLocationId: 'home',
    reminders: ReminderPreferences(enabledPrayers: {PrayerKind.fajr}),
  );
  ScheduledReminder event({
    int generation = 1,
    String id = 'fajr',
    PrayerKind kind = PrayerKind.fajr,
  }) => ScheduledReminder(
    eventId: id,
    locationId: 'home',
    generation: generation,
    kind: kind,
    dueAtUtc: due,
    expiresAtUtc: due.add(const Duration(seconds: 60)),
    audioId: 'fixture',
    mode: AthanMode.opening,
    deliveryMechanism: 'inPage',
  );
  setUp(() {
    now = due.subtract(const Duration(seconds: 5));
    port = PagePort();
    audio = PageAudio();
    deliveries = [];
    adapter = PrayerPageNotifications(
      port: port,
      audio: audio,
      playFromUser: audio.play,
      clock: () => now,
      onDelivery: deliveries.add,
    );
  });
  tearDown(() async {
    await adapter.dispose();
    await port.changes.close();
  });

  test('capabilities are prompt-free and never advertise background/exact delivery', () async {
    final capability = await adapter.capabilities();
    expect(port.prompts, 0);
    expect(capability.permissionStatus, 'notRequired');
    expect(capability.backgroundModes, isEmpty);
    expect(capability.exactAlarmAccess, false);
    expect(capability.foregroundModes, contains(AthanMode.full));
    await adapter.requestAuthorization();
    expect(port.prompts, 1);
    expect(
      (await adapter.capabilities()).foregroundModes,
      contains(AthanMode.opening),
    );
    port.secure = false;
    await adapter.requestAuthorization();
    expect(port.prompts, 1);
  });
  test('due delivery is once-only across same-generation refill; silent optional notice', () async {
    port.permission = 'granted';
    await adapter.replace(state(1), [event()]);
    now = due;
    await adapter.checkDue();
    await adapter.checkDue();
    expect(audio.played, ['fajr']);
    expect(port.notices, 1);
    await adapter.replace(state(1), [event()]);
    await adapter.checkDue();
    expect(audio.played, ['fajr']);
    expect((await adapter.capabilities()).scheduledThroughUtc, isNull);
  });
  test(
    'autoplay rejection exposes explicit Play and Stop invalidates retry',
    () async {
      audio.reject = true;
      await adapter.replace(state(1), [event()]);
      now = due;
      await adapter.checkDue();
      expect(deliveries.last.status, PrayerPageDeliveryStatus.needsPlay);
      audio.reject = false;
      await adapter.playExplicitly('fajr');
      expect(audio.played, ['fajr']);
      await adapter.stop();
      await adapter.playExplicitly('fajr');
      expect(audio.played, ['fajr']);
    },
  );
  test(
    'hidden page drops missed events on resume, never catches up a backlog',
    () async {
      await adapter.replace(state(1), [event()]);
      port.hide();
      now = due.add(const Duration(seconds: 2));
      await adapter.checkDue();
      port.show();
      await adapter.checkDue();
      expect(audio.played, isEmpty);
      expect((await adapter.capabilities()).backgroundModes, isEmpty);
      expect((await adapter.capabilities()).scheduledThroughUtc, isNull);
    },
  );
  test(
    'cancel/replacement reject stale starts and stop current owned audio',
    () async {
      await adapter.replace(state(1), [event()]);
      now = due;
      await adapter.checkDue();
      await adapter.replace(state(2), []);
      await expectLater(
        adapter.replace(state(1), [event()]),
        throwsA(isA<PrayerException>()),
      );
      await adapter.playExplicitly('fajr');
      expect(audio.played, ['fajr']);
      expect(audio.stopped, greaterThan(0));
      expect((await adapter.capabilities()).scheduledThroughUtc, isNull);
    },
  );
  test('invalid sunrise/duplicates/disabled events fail atomically; expired event never plays', () async {
    await expectLater(
      adapter.replace(state(1), [event(kind: PrayerKind.sunrise)]),
      throwsA(isA<PrayerException>()),
    );
    await expectLater(
      adapter.replace(state(1), [event(), event()]),
      throwsA(isA<PrayerException>()),
    );
    await adapter.replace(state(1), [event()]);
    now = due.add(const Duration(seconds: 61));
    await adapter.checkDue();
    await adapter.playExplicitly('fajr');
    expect(audio.played, isEmpty);
    expect((await adapter.capabilities()).scheduledThroughUtc, isNull);
  });
  test(
    'Stop while a start is pending suppresses its late acknowledgement',
    () async {
      audio.pending = Completer<void>();
      await adapter.replace(state(1), [event()]);
      now = due;
      final delivery = adapter.checkDue();
      for (var turn = 0; turn < 5; turn++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(audio.played, ['fajr']);
      await adapter.cancelLocation('home');
      audio.pending!.complete();
      await delivery;
      expect(
        deliveries.where((d) => d.status == PrayerPageDeliveryStatus.playing),
        isEmpty,
      );
      expect((await adapter.capabilities()).scheduledThroughUtc, isNull);
    },
  );
}
