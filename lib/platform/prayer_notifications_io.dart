import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../features/prayer_times/prayer_models.dart';
import '../features/prayer_times/prayer_services.dart';
import 'prayer_notifications_page.dart';
export 'prayer_notifications_page.dart';

final _opens = StreamController<void>.broadcast();
bool _launchChecked = false, _pendingOpen = false;
Stream<void> get prayerNotificationOpens => _opens.stream;
Future<bool> takePrayerNotificationOpen() async {
  if (Platform.isAndroid) {
    const channel = MethodChannel('app.mathani/prayer_notifications');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'notificationOpen') _opens.add(null);
    });
    return await channel.invokeMethod<bool>('takeNotificationOpen') ?? false;
  }
  if (!Platform.isIOS) return false;
  if (_pendingOpen) {
    _pendingOpen = false;
    return true;
  }
  if (_launchChecked) return false;
  _launchChecked = true;
  final launch = await FlutterLocalNotificationsPlugin()
      .getNotificationAppLaunchDetails();
  return launch?.didNotificationLaunchApp == true &&
      launch?.notificationResponse?.payload?.startsWith('mathani.prayer.v1|') ==
          true;
}

PrayerNotificationAdapter shortPrayerNotifications({
  required String title,
  required String Function(PrayerKind kind) body,
}) => Platform.isAndroid || Platform.isIOS
    ? PrayerNativeNotifications(
        title: title,
        body: body,
        android: Platform.isAndroid,
      )
    : const NoPrayerNotifications();

PrayerNotificationAdapter prayerNotifications({
  required PrayerAudio audio,
  required Future<void> Function(ScheduledReminder event) playFromUser,
  required void Function(PrayerPageDelivery delivery) onDelivery,
  required String notificationTitle,
  required String Function(PrayerKind kind) notificationBody,
}) => Platform.isAndroid || Platform.isIOS
    ? PrayerNativeNotifications(
        title: notificationTitle,
        body: notificationBody,
        android: Platform.isAndroid,
      )
    : const NoPrayerNotifications();

/// Short OS notifications only. No automatic full playback or second media owner.
class PrayerNativeNotifications
    implements PrayerNotificationAdapter, PrayerNotificationSettings {
  PrayerNativeNotifications({
    required this.title,
    required this.body,
    required this.android,
    this.channel = const MethodChannel('app.mathani/prayer_notifications'),
    IOSFlutterLocalNotificationsPlugin? ios,
    this.clock = prayerNow,
  }) : _ios = ios ?? IOSFlutterLocalNotificationsPlugin();
  final String title;
  final String Function(PrayerKind kind) body;
  final bool android;
  final PrayerClock clock;
  final MethodChannel channel;
  final IOSFlutterLocalNotificationsPlugin _ios;
  Future<void>? _initializing;
  Future<void> _tail = Future.value();
  int _generation = -1;
  final _known = <String, ScheduledReminder>{};
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _initializeIOS() => _initializing ??= () async {
    await _ios.initialize(
      settings: const DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload?.startsWith('mathani.prayer.v1|') == true) {
          _pendingOpen = true;
          _opens.add(null);
        }
      },
    );
  }();
  @override
  Future<ReminderCapability> capabilities() async {
    if (android) {
      final raw =
          await channel.invokeMapMethod<String, dynamic>('capabilities') ?? {};
      return ReminderCapability(
        permissionStatus: raw['permissionStatus'] as String? ?? 'unsupported',
        exactAlarmAccess: raw['exactAlarmAccess'] == true,
        foregroundModes: const {AthanMode.opening},
        backgroundModes: const {AthanMode.opening},
        restrictedPrayers: {
          if (raw['dailyRestricted'] == true) ...dailyPrayers,
          if (raw['qiyamRestricted'] == true) PrayerKind.qiyam,
        },
        reason: 'systemSoundOnly',
        recoveryAction: 'notificationSettings',
      );
    }
    await _initializeIOS();
    final settings = await _ios.checkPermissions();
    return ReminderCapability(
      permissionStatus: settings?.isEnabled == true ? 'granted' : 'denied',
      foregroundModes: const {AthanMode.opening},
      backgroundModes: const {AthanMode.opening},
      channelRestricted: settings?.isSoundEnabled == false,
      reason: 'systemSoundOnly',
      recoveryAction: 'notificationSettings',
    );
  }

  @override
  Future<ReminderCapability> requestAuthorization() async {
    if (android) {
      await channel.invokeMethod<Object?>('requestAuthorization');
    } else {
      await _initializeIOS();
      await _ios.requestPermissions(alert: true, sound: true, badge: false);
    }
    return capabilities();
  }

  @override
  Future<void> openNotificationSettings({bool exactAlarm = false}) async {
    if (android) {
      await channel.invokeMethod<void>(
        exactAlarm ? 'requestExactAccess' : 'openSettings',
      );
    } else {
      await _initializeIOS();
      await _ios.openAppNotificationSettings();
    }
  }

  Map<String, Object> _event(ScheduledReminder event) => {
    'eventId': event.eventId,
    'locationId': event.locationId,
    'kind': event.kind.name,
    'dueAtMs': event.dueAtUtc.millisecondsSinceEpoch,
    'expiresAtMs': event.expiresAtUtc.millisecondsSinceEpoch,
    'assetId':
        '${event.audioId}${event.deliveryMechanism.startsWith('inexact') ? '_inexact' : ''}',
    'title': title,
    'body': body(event.kind),
  };
  @override
  Future<ReminderCapability> replace(
    PrayerState state,
    List<ScheduledReminder> events,
  ) => _serial(() async {
    try {
      if (state.generation < _generation ||
          events.length > (android ? 192 : 60)) {
        throw const PrayerException(PrayerFailure.schedulePartial);
      }
      final ids = <String>{};
      for (final event in events) {
        if (!ids.add(event.eventId) ||
            event.generation != state.generation ||
            event.locationId != state.activeLocationId ||
            event.mode != AthanMode.opening ||
            event.consumed ||
            event.state != ReminderState.pending ||
            event.claimOwner != null ||
            !event.dueAtUtc.isAfter(clock()) ||
            event.dueAtUtc.difference(clock()) > const Duration(days: 30) ||
            event.expiresAtUtc.isBefore(event.dueAtUtc) ||
            event.expiresAtUtc.difference(event.dueAtUtc) >
                const Duration(seconds: 60) ||
            !{
              'system',
              'systemDefault',
              'inexactSystem',
              'inexactSystemDefault',
            }.contains(event.deliveryMechanism) ||
            (event.deliveryMechanism.startsWith('inexact') &&
                state.reminders.acknowledgedFallbacks['android_exact_alarm'] !=
                    1) ||
            (event.kind == PrayerKind.qiyam
                ? !state.reminders.qiyamEnabled || event.audioId != 'qiyam_tone'
                : !dailyPrayers.contains(event.kind) ||
                      !state.reminders.enabledPrayers.contains(event.kind) ||
                      event.audioId != 'system_default' ||
                      state
                              .reminders
                              .acknowledgedFallbacks['system_notification'] !=
                          1)) {
          throw const PrayerException(PrayerFailure.modeUnsupported);
        }
      }
      _generation = state.generation;
      if (android) {
        await channel.invokeMethod<Object?>('replace', {
          'generation': state.generation,
          'events': events.map(_event).toList(),
          'dailyChannelName': title,
          'qiyamChannelName': body(PrayerKind.qiyam),
        });
      } else {
        await _initializeIOS();
        await _cancelIOS();
        if (events.any((event) => event.kind == PrayerKind.qiyam)) {
          final sounds = Directory(
            '${(await getLibraryDirectory()).path}/Sounds',
          );
          await sounds.create(recursive: true);
          final bytes = await rootBundle.load('assets/prayer/qiyam_tone.caf');
          final partial = File('${sounds.path}/mathani_qiyam_v1.caf.part');
          await partial.writeAsBytes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
            flush: true,
          );
          await partial.rename('${sounds.path}/mathani_qiyam_v1.caf');
        }
        for (var index = 0; index < events.length; index++) {
          final event = events[index];
          await _ios.zonedSchedule(
            id: 0x50000000 + index,
            title: title,
            body: body(event.kind),
            scheduledDate: tz.TZDateTime.from(event.dueAtUtc, tz.UTC),
            payload:
                'mathani.prayer.v1|${event.generation}|${event.eventId}|${event.dueAtUtc.millisecondsSinceEpoch}',
            notificationDetails: DarwinNotificationDetails(
              presentAlert: true,
              presentBanner: true,
              presentSound: true,
              sound: event.kind == PrayerKind.qiyam
                  ? 'mathani_qiyam_v1.caf'
                  : null,
              threadIdentifier: 'mathani.prayer',
            ),
          );
        }
      }
      _known
        ..clear()
        ..addEntries(events.map((event) => MapEntry(event.eventId, event)));
      final actual = await _pending();
      final future = events
          .where((event) => event.dueAtUtc.isAfter(clock()))
          .toList();
      if (future.any((event) => !actual.contains(event.eventId))) {
        throw const PrayerException(PrayerFailure.schedulePartial);
      }
      final capability = await capabilities();
      final queued =
          future.where((event) => actual.contains(event.eventId)).toList()
            ..sort((a, b) => a.dueAtUtc.compareTo(b.dueAtUtc));
      return ReminderCapability(
        permissionStatus: capability.permissionStatus,
        exactAlarmAccess: capability.exactAlarmAccess,
        foregroundModes: capability.foregroundModes,
        backgroundModes: capability.backgroundModes,
        channelRestricted: capability.channelRestricted,
        restrictedPrayers: capability.restrictedPrayers,
        reason: capability.reason,
        scheduledThroughUtc: queued.lastOrNull?.dueAtUtc,
      );
    } on Object {
      try {
        if (android) {
          await channel.invokeMethod<void>('cancelAll');
        } else {
          await _cancelIOS();
        }
      } on Object {
        /* no ready state is reported */
      }
      _known.clear();
      rethrow;
    }
  });
  Future<Set<String>> _pending() async {
    if (android) {
      final raw = await channel.invokeListMethod<dynamic>('pending') ?? [];
      return {
        for (final item in raw)
          if (item is Map &&
              item['generation'] == _generation &&
              _known[item['eventId']]?.dueAtUtc.millisecondsSinceEpoch ==
                  item['dueAtMs'])
            item['eventId'] as String,
      };
    }
    final requests = await _ios.pendingNotificationRequests();
    return {
      for (final item in requests)
        if (item.payload?.startsWith('mathani.prayer.v1|$_generation|') ==
                true &&
            item.payload!.split('|').length == 4 &&
            _known[item.payload!.split('|')[2]]?.dueAtUtc.millisecondsSinceEpoch
                    .toString() ==
                item.payload!.split('|')[3])
          item.payload!.split('|')[2],
    };
  }

  Future<void> _cancelIOS() async {
    for (final item in await _ios.pendingNotificationRequests()) {
      if (item.payload?.startsWith('mathani.prayer.v1|') == true) {
        await _ios.cancel(id: item.id);
      }
    }
    if ((await _ios.pendingNotificationRequests()).any(
      (item) => item.payload?.startsWith('mathani.prayer.v1|') == true,
    )) {
      throw const PrayerException(PrayerFailure.schedulePartial);
    }
  }

  @override
  Future<void> cancelAll() => _serial(() async {
    if (android) {
      await channel.invokeMethod<void>('cancelAll');
      if ((await channel.invokeListMethod<dynamic>('pending'))?.isNotEmpty ==
          true) {
        throw const PrayerException(PrayerFailure.schedulePartial);
      }
    } else {
      await _initializeIOS();
      await _cancelIOS();
    }
    _known.clear();
  });
  @override
  Future<void> cancelLocation(String locationId) async {
    if (_known.isEmpty ||
        _known.values.any((event) => event.locationId == locationId)) {
      await cancelAll();
    }
  }
}
