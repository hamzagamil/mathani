import 'prayer_models.dart';

enum PrayerFailure {
  locationDenied,
  locationUnavailable,
  timezoneUnresolved,
  providerUnavailable,
  offline,
  calculationUnavailable,
  conventionOutOfRange,
  audioUnavailable,
  notificationsDenied,
  exactAlarmDenied,
  modeUnsupported,
  secureStorageUnavailable,
  schedulePartial,
  horizonExpired,
  needsAttention,
}

class PrayerException implements Exception {
  const PrayerException(this.reason);
  final PrayerFailure reason;
  @override
  String toString() => 'PrayerException(${reason.name})';
}

typedef PrayerClock = DateTime Function();
DateTime prayerNow() => DateTime.now().toUtc();

abstract interface class PrayerSnapshotStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

abstract interface class PrayerLocationClient {
  Future<Map<String, dynamic>> resolve(
    Map<String, dynamic> candidate,
    String language,
  );
  Future<List<Map<String, dynamic>>> search(String query, String language);
  Future<Map<String, dynamic>> detect(String language);
  Future<Map<String, dynamic>> approximate(String language);
  void cancelSearch();
  void dispose();
}

abstract interface class PrayerNotificationAdapter {
  Future<ReminderCapability> capabilities();
  Future<ReminderCapability> requestAuthorization();
  Future<ReminderCapability> replace(
    PrayerState state,
    List<ScheduledReminder> events,
  );
  Future<void> cancelLocation(String locationId);
  Future<void> cancelAll();
}

/// Explicitly owns no queue before the notification increment is implemented.
class NoPrayerNotifications implements PrayerNotificationAdapter {
  const NoPrayerNotifications();
  @override
  Future<ReminderCapability> capabilities() async => const ReminderCapability(
    permissionStatus: 'unsupported',
    reason: 'modeUnsupported',
  );
  @override
  Future<ReminderCapability> requestAuthorization() => capabilities();
  @override
  Future<ReminderCapability> replace(
    PrayerState state,
    List<ScheduledReminder> events,
  ) async {
    if (state.reminders.anyEnabled) {
      throw const PrayerException(PrayerFailure.modeUnsupported);
    }
    return capabilities();
  }

  @override
  Future<void> cancelLocation(String locationId) async {}
  @override
  Future<void> cancelAll() async {}
}

abstract interface class PrayerAudio {
  Future<void> preview(AthanRecording recording);
  Future<void> play(ScheduledReminder reminder);
  Future<void> stop();
}
