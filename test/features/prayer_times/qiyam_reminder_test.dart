import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/prayer_times/prayer_calculator.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_reminder_scheduler.dart';

import '../../support/prayer_reminder_fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 10, 29, 12);
  final place = SavedLocation(
    id: 'home',
    label: 'Home',
    latitude: 30,
    longitude: 31,
    timezoneId: 'Africa/Cairo',
    source: LocationSource.manual,
    confirmedAtUtc: now,
  );
  PrayerState state(
    int generation, {
    bool qiyam = true,
    bool daily = false,
    bool fallback = false,
  }) => PrayerState(
    generation: generation,
    locations: [place],
    activeLocationId: place.id,
    reminders: ReminderPreferences(
      qiyamEnabled: qiyam,
      enabledPrayers: daily ? {PrayerKind.fajr} : {},
      acknowledgedFallbacks: fallback ? {'system_notification': 1} : {},
    ),
  );
  PrayerReminderScheduler scheduler(FixtureNotifications adapter) =>
      PrayerReminderScheduler(
        adapter: adapter,
        calculator: PrayerCalculator(
          jsonDecode(
            File('assets/prayer/ramadan_intervals.json').readAsStringSync(),
          ) as Map<String, dynamic>,
        ),
        target: PrayerReminderTarget.ios,
        clock: () => now,
      );
  test('Qiyam schedules independently without any athan recording and shares the 60-event limit', () async {
    final adapter = FixtureNotifications(),
        subject = scheduler(FixtureNotifications());
    final actual = scheduler(adapter);
    final result = await actual.reconcile(state(1));
    expect(result.status, PrayerScheduleStatus.scheduled);
    expect(adapter.queued, isNotEmpty);
    expect(
      adapter.queued.every(
        (event) =>
            event.kind == PrayerKind.qiyam &&
            event.audioId == 'qiyam_tone' &&
            event.mode == AthanMode.opening,
      ),
      true,
    );
    expect(
      adapter.queued.map((event) => event.eventId).toSet().length,
      adapter.queued.length,
    );
    final mixed = await actual.reconcile(state(2, daily: true, fallback: true));
    expect(mixed.events.length, lessThanOrEqualTo(60));
    expect(mixed.events.any((event) => event.kind == PrayerKind.fajr), true);
    await actual.reconcile(state(3, qiyam: false, daily: true, fallback: true));
    expect(
      adapter.queued.every((event) => event.kind == PrayerKind.fajr),
      true,
    );
    expect(
      (await subject.reconcile(state(1, qiyam: false))).status,
      PrayerScheduleStatus.disabled,
    );
  });
  test('default notification sound for daily prayer requires its own explicit acknowledgement', () async {
    final adapter = FixtureNotifications(),
        subject = scheduler(FixtureNotifications());
    final actual = scheduler(adapter);
    final blocked = await actual.reconcile(state(1, qiyam: false, daily: true));
    expect(blocked.status, PrayerScheduleStatus.blocked);
    expect(blocked.requiredAcknowledgement, 'system_notification');
    final result = await actual.reconcile(
      state(2, qiyam: false, daily: true, fallback: true),
    );
    expect(result.status, PrayerScheduleStatus.scheduled);
    expect(
      result.events.every(
        (event) =>
            event.audioId == 'system_default' &&
            event.mode == AthanMode.opening,
      ),
      true,
    );
    expect(subject.androidHeadlessVerified, false);
  });
  test(
    'after midnight the current night is queued, not skipped for tomorrow',
    () async {
      final calculator = PrayerCalculator(
        jsonDecode(
          File('assets/prayer/ramadan_intervals.json').readAsStringSync(),
        ) as Map<String, dynamic>,
      );
      final currentNight = calculator
          .schedule(place, DateTime.utc(2026, 10, 29))
          .qiyamUtc!;
      final adapter = FixtureNotifications();
      final actual = PrayerReminderScheduler(
        adapter: adapter,
        calculator: calculator,
        target: PrayerReminderTarget.ios,
        clock: () => currentNight.subtract(const Duration(minutes: 10)),
      );
      final result = await actual.reconcile(state(1));
      expect(result.events.first.dueAtUtc, currentNight);
    },
  );
  test(
    'unavailable daily athan does not block an independent Qiyam tone',
    () async {
      final result = await scheduler(FixtureNotifications())
          .reconcile(state(1, daily: true));
      expect(result.status, PrayerScheduleStatus.partial);
      expect(result.requiredAcknowledgement, 'system_notification');
      expect(result.events, isNotEmpty);
      expect(
        result.events.every((event) => event.kind == PrayerKind.qiyam),
        true,
      );
    },
  );
  test(
    'a blocked Qiyam channel does not remove enabled daily prayers',
    () async {
      final adapter = FixtureNotifications()
        ..current = const ReminderCapability(
          permissionStatus: 'granted',
          backgroundModes: {AthanMode.opening},
          restrictedPrayers: {PrayerKind.qiyam},
        );
      final result = await scheduler(adapter)
          .reconcile(state(1, daily: true, fallback: true));
      expect(result.status, PrayerScheduleStatus.partial);
      expect(result.events, isNotEmpty);
      expect(
        result.events.every((event) => event.kind == PrayerKind.fajr),
        true,
      );
    },
  );
}
