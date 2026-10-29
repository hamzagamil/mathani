import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_services.dart';

const fixtureAthan = AthanRecording(
  id: 'fixture',
  titleAr: 'تسجيل اختباري',
  titleEn: 'Synthetic test recording',
  creditedRecorder: 'Test fixture',
  sourceUrl: 'https://example.org/source',
  sourceRevision: 'fixture-v1',
  licenseId: 'CC0-1.0',
  licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
  changeNotice: 'Synthetic fixture, not shipped',
  fullAssetUrl: 'https://get.mthani.app/athan/v1/fixture.m4a',
  sha256: '9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a',
  expectedBytes: 4,
  durationMs: 120000,
  encoding: 'aac-lc/m4a',
  openingAssetId: 'fixture_opening',
  openingEndMs: 10000,
  openingDurationMs: 10000,
  platformClipHashes: {},
  platformClipEncodings: {},
  completeRecordingReviewed: true,
  fourTakbirsReviewed: true,
);

class FixtureNotifications extends NoPrayerNotifications {
  ReminderCapability current = const ReminderCapability(
    permissionStatus: 'granted',
    exactAlarmAccess: true,
    foregroundModes: {AthanMode.full, AthanMode.opening},
    backgroundModes: {AthanMode.full, AthanMode.opening},
  );
  List<ScheduledReminder> queued = [];
  int prompts = 0, replacements = 0, cancellations = 0;
  bool partial = false;
  @override
  Future<ReminderCapability> capabilities() async => current;
  @override
  Future<ReminderCapability> requestAuthorization() async {
    prompts++;
    return current;
  }

  @override
  Future<void> cancelAll() async {
    cancellations++;
    queued = [];
  }

  @override
  Future<ReminderCapability> replace(
    PrayerState state,
    List<ScheduledReminder> events,
  ) async {
    replacements++;
    queued = partial ? events.take(events.length ~/ 2).toList() : events;
    return ReminderCapability(
      permissionStatus: current.permissionStatus,
      exactAlarmAccess: current.exactAlarmAccess,
      backgroundModes: current.backgroundModes,
      foregroundModes: current.foregroundModes,
      scheduledThroughUtc: queued.isEmpty ? null : queued.last.dueAtUtc,
    );
  }
}
