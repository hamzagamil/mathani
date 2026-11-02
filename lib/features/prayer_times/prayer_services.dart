import 'prayer_models.dart';

enum PrayerFailure {
  locationDenied,
  locationUnavailable,
  timezoneUnresolved,
  providerUnavailable,
  offline,
  rateLimited,
  calculationUnavailable,
  conventionOutOfRange,
  audioUnavailable,
  notificationsDenied,
}

class PrayerException implements Exception {
  const PrayerException(this.reason);
  final PrayerFailure reason;
  @override
  String toString() => 'PrayerException(${reason.name})';
}

typedef PrayerClock = DateTime Function();
DateTime prayerNow() => DateTime.now().toUtc();

/// City search, place resolution and the phone's position (contracts/location-api.md).
abstract interface class PrayerLocationClient {
  /// Detects the phone's approximate position, asking for permission if needed, then resolves it.
  Future<Map<String, dynamic>> detect(String language);

  /// Whether location permission is already granted, checked without prompting.
  Future<bool> canLocate();

  /// The position without ever prompting: null unless permission is already granted (R4).
  Future<({double latitude, double longitude})?> passivePosition();
  Future<Map<String, dynamic>> resolve(
    double latitude,
    double longitude,
    String language, {
    String source,
  });
  Future<List<Map<String, dynamic>>> search(String query, String language);

  /// The internet-based estimate (`GET /api/prayer-location`).
  Future<Map<String, dynamic>> approximate(String language);
  void cancelSearch();
  void dispose();
}

enum NotificationPermission { granted, denied, notDetermined, unsupported }

/// What the phone allows, read without prompting.
class AlertStatus {
  const AlertStatus(this.notifications, {this.exactAlarms});
  final NotificationPermission notifications;

  /// Android 12+ only; null elsewhere.
  final bool? exactAlarms;
}

sealed class PrayerPlatformEvent {
  const PrayerPlatformEvent();
}

/// The reader tapped an alert.
class AlertOpened extends PrayerPlatformEvent {
  const AlertOpened(this.kind, this.alertId);
  final PrayerKind? kind;
  final int? alertId;
}

/// The Android athan service started while the app process is alive.
class AthanStarted extends PrayerPlatformEvent {
  const AthanStarted();
}

/// Schedules alerts on each platform (contracts/prayer-ui-and-reminders.md).
abstract interface class PrayerAlertPlatform {
  Future<AlertStatus> status();

  /// Only called when the reader turns an alert on.
  Future<AlertStatus> requestPermission();
  Future<void> openSettings({bool exactAlarms = false});

  /// Replaces every app-owned alert with [alerts]; returns how many are pending.
  Future<int> replace(List<Alert> alerts, int generation);
  Future<void> cancelAll();
  Stream<PrayerPlatformEvent> get events;

  /// The alert that launched the app, if any. Asked once, after the first frame.
  Future<AlertOpened?> takeLaunchOpen();
}

/// No alerts at all: desktop and tests.
class NoPrayerAlerts implements PrayerAlertPlatform {
  const NoPrayerAlerts();
  @override
  Future<AlertStatus> status() async =>
      const AlertStatus(NotificationPermission.unsupported);
  @override
  Future<AlertStatus> requestPermission() => status();
  @override
  Future<void> openSettings({bool exactAlarms = false}) async {}
  @override
  Future<int> replace(List<Alert> alerts, int generation) async => 0;
  @override
  Future<void> cancelAll() async {}
  @override
  Stream<PrayerPlatformEvent> get events => const Stream.empty();
  @override
  Future<AlertOpened?> takeLaunchOpen() async => null;
}
