import 'dart:async';

import '../features/prayer_times/prayer_models.dart';
import '../features/prayer_times/prayer_services.dart';

/// Browser APIs, kept apart so the timer queue can be tested without a browser.
abstract interface class PrayerPagePort {
  bool get active;
  bool get notificationsSupported;

  /// `granted`, `denied` or `default`.
  String get notificationPermission;
  Stream<bool> get activityChanges;
  Future<void> requestNotificationPermission();

  /// Silent: the app plays the sound itself.
  void showNotification(Alert alert);
}

/// Web alerts: timers that run only while the page is open (FR-028). Missed alerts are dropped,
/// never replayed when the reader comes back.
class PageAlerts implements PrayerAlertPlatform {
  PageAlerts({required this.port, this.clock = prayerNow});
  final PrayerPagePort port;
  final PrayerClock clock;

  /// Plays the alert's sound; set by the app-level coordinator.
  void Function(Alert alert)? onDue;
  final _pending = <int, Alert>{};
  StreamSubscription<bool>? _activity;
  Timer? _timer;
  bool _missed = false;

  /// An alert more than this late is treated as missed (contracts › Android receiver).
  static const lateness = Duration(minutes: 15);

  @override
  Future<AlertStatus> status() async => AlertStatus(
    !port.notificationsSupported
        ? NotificationPermission.unsupported
        : switch (port.notificationPermission) {
            'granted' => NotificationPermission.granted,
            'denied' => NotificationPermission.denied,
            _ => NotificationPermission.notDetermined,
          },
  );

  @override
  Future<AlertStatus> requestPermission() async {
    if (port.notificationsSupported &&
        port.notificationPermission == 'default') {
      try {
        await port.requestNotificationPermission();
      } on Object {
        /* optional: in-page sound works without it */
      }
    }
    return status();
  }

  @override
  Future<void> openSettings({bool exactAlarms = false}) async {}

  @override
  Future<int> replace(List<Alert> alerts, int generation) async {
    final now = clock();
    _pending
      ..clear()
      ..addAll({
        for (final a in alerts)
          if (a.atUtc.isAfter(now)) a.id: a,
      });
    _activity ??= port.activityChanges.listen((active) {
      if (active) {
        unawaited(checkDue());
      } else {
        _missed = true;
      }
    });
    _arm();
    return _pending.length;
  }

  void _arm() {
    _timer?.cancel();
    _timer = _pending.isEmpty
        ? null
        : Timer.periodic(const Duration(seconds: 1), (_) => checkDue());
  }

  Future<void> checkDue() async {
    if (!port.active) {
      _missed = true;
      return;
    }
    final now = clock();
    final due = _pending.values.where((a) => !a.atUtc.isAfter(now)).toList()
      ..sort((a, b) => a.atUtc.compareTo(b.atUtc));
    final missed = _missed;
    _missed = false;
    for (final alert in due) {
      _pending.remove(alert.id);
      if (missed || now.difference(alert.atUtc) > lateness) continue;
      if (port.notificationsSupported &&
          port.notificationPermission == 'granted') {
        try {
          port.showNotification(alert);
        } on Object {
          /* the in-page sound still plays */
        }
      }
      onDue?.call(alert);
    }
    if (due.isNotEmpty) _arm();
  }

  @override
  Future<void> cancelAll() async {
    _pending.clear();
    _arm();
  }

  @override
  Stream<PrayerPlatformEvent> get events => const Stream.empty();

  @override
  Future<AlertOpened?> takeLaunchOpen() async => null;

  Future<void> dispose() async {
    _timer?.cancel();
    await _activity?.cancel();
  }
}
