import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../features/announcements/announcements.dart';
import '../firebase_options.dart';
import 'local_notifications_io.dart';

/// Firebase Cloud Messaging on phones; nothing on desktop (specs/015 research R6–R9).
/// [channelName] names the Android channel in the app's language.
AnnouncementsPlatform announcementsPlatform({
  required String Function() channelName,
}) => Platform.isAndroid || Platform.isIOS
    ? FirebaseAnnouncements(channelName: channelName)
    : const NoAnnouncements();

class FirebaseAnnouncements implements AnnouncementsPlatform {
  FirebaseAnnouncements({required this.channelName});
  final String Function() channelName;
  final _links = StreamController<String>.broadcast();
  Future<bool>? _starting;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  static const _android = AndroidAlertChannel.channel;

  @override
  Future<bool> start() async {
    final ok = await (_starting ??= _start());
    // Retried on the next sync, e.g. after going online.
    if (!ok) _starting = null;
    return ok;
  }

  Future<bool> _start() async {
    final FirebaseOptions options;
    try {
      options = DefaultFirebaseOptions.currentPlatform;
    } on UnsupportedError {
      return false; // not configured yet (R11)
    }
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
      if (Platform.isAndroid) {
        await _android.invokeMethod('ensureAnnouncementChannel', {
          'name': channelName(),
        });
        // Taps on announcements the app showed itself, in the foreground (R8).
        AndroidAlertChannel.taps
            .where((t) => t.kind == 'announcement')
            .listen(_tapped);
        final launch = await AndroidAlertChannel.takeLaunch();
        if (launch?.kind == 'announcement') _tapped(launch!);
      } else {
        // Banner and list while the app is open, without sound (spec US4 scenario 2).
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: false,
          sound: false,
        );
      }
      FirebaseMessaging.onMessage.listen(_foreground);
      FirebaseMessaging.onMessageOpenedApp.listen(_opened);
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _opened(initial);
      return true;
    } on Object catch (e) {
      if (kDebugMode) debugPrint('Announcements unavailable: $e');
      return false;
    }
  }

  void _tapped(NotificationTap tap) {
    if (tap.link != null) _links.add(tap.link!);
  }

  void _opened(RemoteMessage message) {
    final link = message.data['link'];
    if (link is String) _links.add(link);
  }

  /// FCM does not show a message that arrives while the app is open on Android.
  void _foreground(RemoteMessage message) {
    final n = message.notification;
    if (!Platform.isAndroid || n == null) return;
    unawaited(
      _android.invokeMethod('showAnnouncement', {
        'id':
            (message.messageId ?? '${message.sentTime}').hashCode & 0x7fffffff,
        'title': n.title ?? '',
        'body': n.body ?? '',
        'link': message.data['link'],
        'channelName': channelName(),
      }),
    );
  }

  /// iOS refuses topic changes until the APNs token has arrived, shortly after launch.
  Future<void> _ready() async {
    await _messaging.setAutoInitEnabled(true);
    if (!Platform.isIOS) return;
    for (var i = 0; i < 20 && await _messaging.getAPNSToken() == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  Future<void> subscribe(Set<String> topics) async {
    await _ready();
    for (final t in topics) {
      await _messaging.subscribeToTopic(t);
    }
  }

  @override
  Future<void> unsubscribe(Set<String> topics) async {
    if (Platform.isIOS && await _messaging.getAPNSToken() == null) {
      await _ready();
    }
    for (final t in topics) {
      await _messaging.unsubscribeFromTopic(t);
    }
  }

  @override
  Future<void> requestPermission() async {
    if (Platform.isAndroid) {
      await _android.invokeMethod('requestPermission');
    } else {
      await _messaging.requestPermission(
        alert: true,
        sound: true,
        badge: false,
      );
    }
  }

  @override
  Stream<String> get openedLinks => _links.stream;
}
