import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../features/khatma/khatma_reminder_platform.dart';
import 'local_notifications_io.dart';

/// The reminder on this phone (specs/014 contracts/khatma-ui-and-reminders.md › Native contract).
KhatmaReminderPlatform khatmaReminderPlatform({String Function()? channelName}) =>
    Platform.isAndroid
        ? AndroidKhatmaReminders(channelName: channelName ?? () => 'Daily reminder')
        : Platform.isIOS
            ? IosKhatmaReminders()
            : const NoKhatmaReminders();

ReminderStatus _status(Map<Object?, Object?>? raw) => ReminderStatus(
      raw?['notifications'] == true
          ? ReminderPermission.granted
          : ReminderPermission.values.firstWhere(
              (p) => p.name == raw?['permission'],
              orElse: () => ReminderPermission.denied,
            ),
      exactAlarms: raw?['exactAlarms'] as bool?,
    );

/// Android: the prayer alarm store, plugin and receiver, with a second store file and the `wird`
/// kind (research R9).
class AndroidKhatmaReminders implements KhatmaReminderPlatform {
  AndroidKhatmaReminders({required this.channelName});

  /// The notification channel's name, in the interface language.
  final String Function() channelName;
  static const _channel = AndroidAlertChannel.channel;
  int _generation = DateTime.now().millisecondsSinceEpoch;

  @override
  Future<ReminderStatus> status() async =>
      _status(await _channel.invokeMapMethod<Object?, Object?>('status'));

  @override
  Future<ReminderStatus> requestPermission() async =>
      _status(await _channel.invokeMapMethod<Object?, Object?>('requestPermission'));

  @override
  Future<void> openSettings() => _channel.invokeMethod('openSettings', {'exactAlarms': false});

  @override
  Future<int> replace(List<KhatmaReminder> reminders) async =>
      await _channel.invokeMethod<int>('replaceReminders', {
        'generation': ++_generation,
        'channelName': channelName(),
        'alerts': [
          for (final r in reminders)
            {
              'id': r.id,
              'kind': 'wird',
              'atUtcMs': r.atUtc.millisecondsSinceEpoch,
              'title': r.title,
              'body': r.body,
              'sound': 'default',
            },
        ],
      }) ??
      0;

  @override
  Future<void> clearDelivered(List<int> ids) =>
      _channel.invokeMethod('clearReminders', {'ids': ids});

  @override
  Stream<void> get opened => AndroidAlertChannel.taps.where((t) => t.kind == 'wird');

  @override
  Future<bool> takeLaunchOpen() async => (await AndroidAlertChannel.takeLaunch())?.kind == 'wird';
}

/// iOS: one-time notifications at absolute times, at most 10, with the default sound.
class IosKhatmaReminders implements KhatmaReminderPlatform {
  static const payload = 'mathani.khatma.v1';
  static const max = 10;
  IOSFlutterLocalNotificationsPlugin get _plugin => IosNotifications.plugin;

  @override
  Future<ReminderStatus> status() async {
    await IosNotifications.initialize();
    final settings = await _plugin.checkPermissions();
    return ReminderStatus(settings == null
        ? ReminderPermission.notDetermined
        : settings.isEnabled
            ? ReminderPermission.granted
            : ReminderPermission.denied);
  }

  @override
  Future<ReminderStatus> requestPermission() async {
    await IosNotifications.initialize();
    await _plugin.requestPermissions(alert: true, sound: true);
    return status();
  }

  @override
  Future<void> openSettings() async {
    await IosNotifications.initialize();
    await _plugin.openAppNotificationSettings();
  }

  @override
  Future<int> replace(List<KhatmaReminder> reminders) async {
    final wanted = {for (final r in reminders.take(max)) r.id: r};
    for (final p in await IosNotifications.pending('$payload|')) {
      if (!wanted.containsKey(p.id)) await _plugin.cancel(id: p.id);
    }
    for (final r in wanted.values) {
      await _plugin.zonedSchedule(
        id: r.id,
        title: r.title,
        body: r.body,
        scheduledDate: tz.TZDateTime.from(r.atUtc, tz.UTC),
        payload: '$payload|${r.id}',
        notificationDetails: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
          threadIdentifier: 'mathani.khatma',
        ),
      );
    }
    return (await IosNotifications.pending('$payload|')).length;
  }

  @override
  Future<void> clearDelivered(List<int> ids) async {
    await IosNotifications.initialize();
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
  }

  @override
  Stream<void> get opened =>
      IosNotifications.taps.where((t) => t.payload?.startsWith('$payload|') == true);

  @override
  Future<bool> takeLaunchOpen() async =>
      (await IosNotifications.launchPayload())?.startsWith('$payload|') == true;
}
