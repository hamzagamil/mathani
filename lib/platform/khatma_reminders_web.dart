import '../features/khatma/khatma_reminder_platform.dart';

/// Browsers have no reminder: one that works only while the page is open would almost never be
/// shown at its time (specs/014 FR-042).
KhatmaReminderPlatform khatmaReminderPlatform({String Function()? channelName}) =>
    const NoKhatmaReminders();
