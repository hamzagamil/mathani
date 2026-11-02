import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../features/prayer_times/prayer_models.dart';
import '../features/prayer_times/prayer_services.dart';
import 'prayer_notifications_page.dart';

export 'prayer_notifications_page.dart';

PrayerAlertPlatform prayerAlertPlatform({
  required Map<String, String> Function() channels,
}) => PageAlerts(port: BrowserPrayerPagePort());

/// Removes the first draft's encrypted prayer snapshot and its key from this browser
/// (`flutter_secure_storage` 10.3.4 web defaults; research R6).
Future<void> clearLegacyPrayerStorage() async {
  try {
    final storage = web.window.localStorage;
    storage.removeItem('FlutterSecureStorage.mathani.prayer.snapshot.v1');
    storage.removeItem('FlutterSecureStorage');
  } on Object {
    /* storage blocked: nothing to clean */
  }
}

class BrowserPrayerPagePort implements PrayerPagePort {
  bool _pageHidden = false;
  @override
  bool get active => !_pageHidden && web.document.visibilityState == 'visible';
  @override
  bool get notificationsSupported =>
      web.window.isSecureContext &&
      globalContext.hasProperty('Notification'.toJS).toDart;
  @override
  String get notificationPermission =>
      notificationsSupported ? web.Notification.permission : 'denied';
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
  void showNotification(Alert alert) {
    web.Notification(
      alert.title,
      web.NotificationOptions(
        body: alert.body,
        tag: 'mathani-prayer-${alert.id}',
        silent: true,
      ),
    );
  }
}
