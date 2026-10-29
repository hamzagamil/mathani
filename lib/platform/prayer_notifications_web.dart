import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../features/prayer_times/prayer_models.dart';
import '../features/prayer_times/prayer_services.dart';
import 'prayer_notifications_page.dart';

export 'prayer_notifications_page.dart';

Stream<void> get prayerNotificationOpens => const Stream.empty();
Future<bool> takePrayerNotificationOpen() async => false;

PrayerNotificationAdapter shortPrayerNotifications({
  required String title,
  required String Function(PrayerKind kind) body,
}) => const NoPrayerNotifications();

PrayerPageNotifications prayerNotifications({
  required PrayerAudio audio,
  required Future<void> Function(ScheduledReminder event) playFromUser,
  required void Function(PrayerPageDelivery delivery) onDelivery,
  required String notificationTitle,
  required String Function(PrayerKind kind) notificationBody,
}) => PrayerPageNotifications(
  port: BrowserPrayerPagePort(
    notificationTitle: notificationTitle,
    notificationBody: notificationBody,
  ),
  audio: audio,
  playFromUser: playFromUser,
  onDelivery: onDelivery,
);

class BrowserPrayerPagePort implements PrayerPagePort {
  BrowserPrayerPagePort({
    required this.notificationTitle,
    required this.notificationBody,
  });
  final String notificationTitle;
  final String Function(PrayerKind kind) notificationBody;
  bool _pageHidden = false;
  @override
  bool get active => !_pageHidden && web.document.visibilityState == 'visible';
  @override
  bool get secureContext => web.window.isSecureContext;
  @override
  bool get notificationsSupported =>
      secureContext && globalContext.hasProperty('Notification'.toJS).toDart;
  @override
  String get notificationPermission =>
      notificationsSupported ? web.Notification.permission : 'unsupported';
  @override
  Future<void> requestNotificationPermission() async {
    if (notificationsSupported) {
      await web.Notification.requestPermission().toDart;
    }
  }

  @override
  Stream<bool> get activityChanges {
    late StreamController<bool> controller;
    final visibility = ((web.Event _) => controller.add(active)).toJS;
    final hide = ((web.Event _) {
      _pageHidden = true;
      controller.add(false);
    }).toJS;
    final show = ((web.Event _) {
      _pageHidden = false;
      controller.add(active);
    }).toJS;
    controller = StreamController<bool>.broadcast(
      onListen: () {
        web.document.addEventListener('visibilitychange', visibility);
        web.window.addEventListener('pagehide', hide);
        web.window.addEventListener('pageshow', show);
      },
      onCancel: () {
        web.document.removeEventListener('visibilitychange', visibility);
        web.window.removeEventListener('pagehide', hide);
        web.window.removeEventListener('pageshow', show);
      },
    );
    return controller.stream;
  }

  @override
  void Function()? showSilentNotification(ScheduledReminder event) {
    if (notificationPermission != 'granted') return null;
    final notice = web.Notification(
      notificationTitle,
      web.NotificationOptions(
        body: notificationBody(event.kind),
        tag: 'mathani-prayer-${event.generation}-${event.eventId}',
        silent: true,
      ),
    );
    return () => notice.close();
  }
}
