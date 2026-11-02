import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../features/prayer_times/prayer_models.dart';
import '../features/prayer_times/prayer_services.dart';

/// Alerts on this platform (contracts/prayer-ui-and-reminders.md › Native contract). [channels]
/// names the Android notification channel of each sound.
PrayerAlertPlatform prayerAlertPlatform({
  required Map<String, String> Function() channels,
}) => Platform.isAndroid
    ? AndroidPrayerAlerts(channels: channels)
    : Platform.isIOS
    ? IosPrayerAlerts()
    : const NoPrayerAlerts();

/// Nothing to clean on phones: the encrypted snapshot of the first draft only reached browsers.
Future<void> clearLegacyPrayerStorage() async {}

const _channel = MethodChannel('app.mathani/prayer_notifications');
final _androidEvents = StreamController<PrayerPlatformEvent>.broadcast();

PrayerKind? _kind(Object? name) =>
    PrayerKind.values.where((k) => k.name == name).firstOrNull;

/// Android: the app's own alarm store, receiver and athan service (research R7, R9).
class AndroidPrayerAlerts implements PrayerAlertPlatform {
  AndroidPrayerAlerts({required this.channels}) {
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments is Map ? call.arguments as Map : const {};
      switch (call.method) {
        case 'opened':
          _androidEvents.add(
            AlertOpened(_kind(args['kind']), args['alertId'] as int?),
          );
        case 'athanStarted':
          _androidEvents.add(const AthanStarted());
      }
    });
  }
  final Map<String, String> Function() channels;

  AlertStatus _status(Map<Object?, Object?>? raw) => AlertStatus(
    raw?['notifications'] == true
        ? NotificationPermission.granted
        : NotificationPermission.values.firstWhere(
            (p) => p.name == raw?['permission'],
            orElse: () => NotificationPermission.denied,
          ),
    exactAlarms: raw?['exactAlarms'] as bool?,
  );

  @override
  Future<AlertStatus> status() async =>
      _status(await _channel.invokeMapMethod<Object?, Object?>('status'));
  @override
  Future<AlertStatus> requestPermission() async => _status(
    await _channel.invokeMapMethod<Object?, Object?>('requestPermission'),
  );
  @override
  Future<void> openSettings({bool exactAlarms = false}) =>
      _channel.invokeMethod('openSettings', {'exactAlarms': exactAlarms});
  @override
  Future<int> replace(List<Alert> alerts, int generation) async =>
      await _channel.invokeMethod<int>('replace', {
        'generation': generation,
        'alerts': [for (final a in alerts) a.toMap()],
        'channels': channels(),
      }) ??
      0;
  @override
  Future<void> cancelAll() => _channel.invokeMethod('cancelAll');
  @override
  Stream<PrayerPlatformEvent> get events => _androidEvents.stream;
  @override
  Future<AlertOpened?> takeLaunchOpen() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>('takeOpened');
    return raw == null
        ? null
        : AlertOpened(_kind(raw['kind']), raw['alertId'] as int?);
  }
}

/// iOS: pending local notifications owned by the OS, at most 60 of its 64 (research R7).
class IosPrayerAlerts implements PrayerAlertPlatform {
  IosPrayerAlerts({IOSFlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? IOSFlutterLocalNotificationsPlugin();
  final IOSFlutterLocalNotificationsPlugin _plugin;
  static const _payload = 'mathani.prayer.v2';
  static const max = 60;
  final _events = StreamController<PrayerPlatformEvent>.broadcast();
  Future<void>? _initializing;

  static AlertOpened? _opened(String? payload) {
    final parts = payload?.split('|');
    if (parts == null || parts.length != 3 || parts[0] != _payload) {
      return null;
    }
    return AlertOpened(_kind(parts[1]), int.tryParse(parts[2]));
  }

  Future<void> _initialize() => _initializing ??= _plugin
      .initialize(
        settings: const DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        onDidReceiveNotificationResponse: (response) {
          final opened = _opened(response.payload);
          if (opened != null) _events.add(opened);
        },
      )
      .then((_) {});

  @override
  Future<AlertStatus> status() async {
    await _initialize();
    final settings = await _plugin.checkPermissions();
    return AlertStatus(
      settings == null
          ? NotificationPermission.notDetermined
          : settings.isEnabled
          ? NotificationPermission.granted
          : NotificationPermission.denied,
    );
  }

  @override
  Future<AlertStatus> requestPermission() async {
    await _initialize();
    await _plugin.requestPermissions(alert: true, sound: true);
    return status();
  }

  @override
  Future<void> openSettings({bool exactAlarms = false}) async {
    await _initialize();
    await _plugin.openAppNotificationSettings();
  }

  Future<List<PendingNotificationRequest>> _owned() async => [
    for (final r in await _plugin.pendingNotificationRequests())
      if (r.payload?.startsWith('$_payload|') == true) r,
  ];

  @override
  Future<int> replace(List<Alert> alerts, int generation) async {
    await _initialize();
    final wanted = {for (final a in alerts.take(max)) a.id: a};
    for (final r in await _owned()) {
      if (!wanted.containsKey(r.id)) await _plugin.cancel(id: r.id);
    }
    for (final a in wanted.values) {
      // Full mode: no sound while the app is open, where the app plays the full athan itself;
      // the opening clip still plays when the phone is locked (FR-024).
      await _plugin.zonedSchedule(
        id: a.id,
        title: a.title,
        body: a.body,
        scheduledDate: tz.TZDateTime.from(a.atUtc, tz.UTC),
        payload: '$_payload|${a.kind.name}|${a.id}',
        notificationDetails: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: a.sound != silentSound && !a.full,
          sound: switch (a.sound) {
            silentSound => null,
            toneSound => 'qiyam_tone.caf',
            final id => 'athan_${id}_opening.caf',
          },
          threadIdentifier: 'mathani.prayer',
        ),
      );
    }
    return (await _owned()).length;
  }

  @override
  Future<void> cancelAll() async {
    await _initialize();
    for (final r in await _owned()) {
      await _plugin.cancel(id: r.id);
    }
  }

  @override
  Stream<PrayerPlatformEvent> get events {
    unawaited(_initialize());
    return _events.stream;
  }

  @override
  Future<AlertOpened?> takeLaunchOpen() async {
    await _initialize();
    final launch = await _plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true
        ? _opened(launch?.notificationResponse?.payload)
        : null;
  }
}
