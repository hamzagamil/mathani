// The reminder on each platform (specs/014 contracts/khatma-ui-and-reminders.md › Dart
// interfaces, research R9). Plain Dart.

/// Whether the phone lets the app show notifications, read without prompting.
enum ReminderPermission { granted, denied, notDetermined, unsupported }

class ReminderStatus {
  const ReminderStatus(this.permission, {this.exactAlarms});
  final ReminderPermission permission;

  /// Android 12 and later; null elsewhere. Without exact alarms a reminder may come late.
  final bool? exactAlarms;
}

/// One reminder handed to the platform.
class KhatmaReminder {
  const KhatmaReminder({
    required this.id,
    required this.atUtc,
    required this.title,
    required this.body,
  });

  final int id;
  final DateTime atUtc;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is KhatmaReminder &&
      other.id == id &&
      other.atUtc == atUtc &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(id, atUtc, title, body);
}

abstract interface class KhatmaReminderPlatform {
  Future<ReminderStatus> status();

  /// Called only when the reader turns the reminder on (FR-020).
  Future<ReminderStatus> requestPermission();
  Future<void> openSettings();

  /// Cancels the reminders that are not in [reminders] and schedules the rest; returns how many
  /// are pending.
  Future<int> replace(List<KhatmaReminder> reminders);

  /// Removes delivered reminders [ids] from the notification list (research R8).
  Future<void> clearDelivered(List<int> ids);

  /// A reminder was tapped while the app runs.
  Stream<void> get opened;

  /// Whether a reminder launched the app. Asked once, after the first frame.
  Future<bool> takeLaunchOpen();
}

/// No reminders: the web (FR-042), desktops and tests.
class NoKhatmaReminders implements KhatmaReminderPlatform {
  const NoKhatmaReminders();
  @override
  Future<ReminderStatus> status() async => const ReminderStatus(ReminderPermission.unsupported);
  @override
  Future<ReminderStatus> requestPermission() => status();
  @override
  Future<void> openSettings() async {}
  @override
  Future<int> replace(List<KhatmaReminder> reminders) async => 0;
  @override
  Future<void> clearDelivered(List<int> ids) async {}
  @override
  Stream<void> get opened => const Stream.empty();
  @override
  Future<bool> takeLaunchOpen() async => false;
}
