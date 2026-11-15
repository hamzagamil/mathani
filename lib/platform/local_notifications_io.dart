// What prayer alerts (specs/009) and the khatma reminder (specs/014) share on phones (research
// R9): one Android method channel and one iOS tap callback. Two owners of either would replace
// each other, so this file owns them and hands each event to its feature.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// A tap on a notification: Android's `kind` (`fajr` … `qiyam`, or `wird`), or iOS's payload.
class NotificationTap {
  const NotificationTap({this.kind, this.alertId, this.payload});
  final String? kind;
  final int? alertId;
  final String? payload;
}

/// The Android channel shared by prayer alerts and reminders (contracts › Native contract).
abstract final class AndroidAlertChannel {
  static const channel = MethodChannel('app.mathani/prayer_notifications');
  static final _taps = StreamController<NotificationTap>.broadcast();
  static final _athan = StreamController<void>.broadcast();
  static bool _listening = false;
  static Future<NotificationTap?>? _launch;

  static void _listen() {
    if (_listening) return;
    _listening = true;
    channel.setMethodCallHandler((call) async {
      final args = call.arguments is Map ? call.arguments as Map : const {};
      switch (call.method) {
        case 'opened':
          _taps.add(NotificationTap(kind: args['kind'] as String?, alertId: args['alertId'] as int?));
        case 'athanStarted':
          _athan.add(null);
      }
    });
  }

  /// Taps while the app runs, of every kind.
  static Stream<NotificationTap> get taps {
    _listen();
    return _taps.stream;
  }

  /// The Android athan service started (specs/009).
  static Stream<void> get athanStarted {
    _listen();
    return _athan.stream;
  }

  /// The tap that launched the app, asked of the platform once and shared by both owners.
  static Future<NotificationTap?> takeLaunch() => _launch ??= () async {
        _listen();
        final raw = await channel.invokeMapMethod<Object?, Object?>('takeOpened');
        return raw == null
            ? null
            : NotificationTap(kind: raw['kind'] as String?, alertId: raw['alertId'] as int?);
      }();
}

/// The iOS plugin, initialised once, with taps handed out by payload.
abstract final class IosNotifications {
  static IOSFlutterLocalNotificationsPlugin plugin = IOSFlutterLocalNotificationsPlugin();
  static final _taps = StreamController<NotificationTap>.broadcast();
  static Future<void>? _initializing;

  static Future<void> initialize() => _initializing ??= plugin
      .initialize(
        settings: const DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        onDidReceiveNotificationResponse: (response) =>
            _taps.add(NotificationTap(payload: response.payload)),
      )
      .then((_) {});

  /// Taps while the app runs, with their payloads.
  static Stream<NotificationTap> get taps {
    unawaited(initialize());
    return _taps.stream;
  }

  /// The payload of the notification that launched the app, if any.
  static Future<String?> launchPayload() async {
    await initialize();
    final launch = await plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true ? launch?.notificationResponse?.payload : null;
  }

  /// Pending notifications whose payload starts with [prefix].
  static Future<List<PendingNotificationRequest>> pending(String prefix) async {
    await initialize();
    return [
      for (final r in await plugin.pendingNotificationRequests())
        if (r.payload?.startsWith(prefix) == true) r,
    ];
  }
}
