import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/prayer_times/prayer_calculator.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_services.dart';
import 'package:mathani/features/prayer_times/prayer_reminder_scheduler.dart';

import '../../support/prayer_reminder_fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 10, 29, 12);
  final calculator = PrayerCalculator(
    jsonDecode(File('assets/prayer/ramadan_intervals.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final place = SavedLocation(
    id: 'opaque',
    label: 'Home',
    latitude: 30.0444,
    longitude: 31.2357,
    timezoneId: 'Africa/Cairo',
    source: LocationSource.manual,
    confirmedAtUtc: now,
  );
  PrayerState state({
    int generation = 1,
    Set<PrayerKind> prayers = dailyPrayers,
    AthanMode mode = AthanMode.opening,
    Map<String, int> acknowledgements = const {},
  }) => PrayerState(
    generation: generation,
    locations: [place],
    activeLocationId: place.id,
    reminders: ReminderPreferences(
      enabledPrayers: prayers,
      selectedAthanId: 'fixture',
      requestedMode: mode,
      acknowledgedFallbacks: acknowledgements,
    ),
  );
  PrayerReminderScheduler scheduler(
    FixtureNotifications adapter,
    PrayerReminderTarget target, {
    bool proven = false,
  }) => PrayerReminderScheduler(
    adapter: adapter,
    calculator: calculator,
    target: target,
    clock: () => now,
    androidHeadlessVerified: proven,
  );
  test(
    'iOS keeps at most 60 future daily events, stable IDs and a real horizon',
    () async {
      final adapter = FixtureNotifications(),
          s = scheduler(FixtureNotifications(), PrayerReminderTarget.ios);
      final subject = scheduler(adapter, PrayerReminderTarget.ios);
      final result = await subject.reconcile(
        state(),
        recording: fixtureAthan,
        openingReady: true,
      );
      expect(result.status, PrayerScheduleStatus.scheduled);
      expect(result.events, hasLength(60));
      expect(
        result.events.every(
          (e) => e.dueAtUtc.isAfter(now) && dailyPrayers.contains(e.kind),
        ),
        isTrue,
      );
      expect(result.events.map((e) => e.eventId).toSet(), hasLength(60));
      final ids = result.events.map((e) => e.eventId).toList();
      expect(result.scheduledThroughUtc, result.events.last.dueAtUtc);
      expect(
        result.appMustReopenByUtc!.isBefore(result.scheduledThroughUtc!),
        isTrue,
      );
      expect(
        (await subject.reconcile(
          state(),
          recording: fixtureAthan,
          openingReady: true,
        )).events.map((e) => e.eventId),
        ids,
      );
      expect(adapter.prompts, 0);
      expect(
        adapter.cancellations,
        0,
        reason: 'A refill must not discard consumed event tokens',
      );
      expect(
        (await s.reconcile(state(prayers: {}))).status,
        PrayerScheduleStatus.disabled,
      );
    },
  );
  test('Android full mode requires empirical gate, and opening fallback acknowledgement', () async {
    final adapter = FixtureNotifications(),
        s = scheduler(FixtureNotifications(), PrayerReminderTarget.android);
    final unproven = await s.reconcile(
      state(mode: AthanMode.full),
      recording: fixtureAthan,
      fullReady: true,
      openingReady: true,
    );
    expect(unproven.status, PrayerScheduleStatus.blocked);
    expect(unproven.requiredAcknowledgement, 'android_background_full');
    final accepted = await s.reconcile(
      state(
        mode: AthanMode.full,
        acknowledgements: {'android_background_full': 1},
      ),
      recording: fixtureAthan,
      fullReady: true,
      openingReady: true,
    );
    expect(accepted.effectiveMode, AthanMode.opening);
    final verified = scheduler(
      adapter,
      PrayerReminderTarget.android,
      proven: true,
    );
    final result = await verified.reconcile(
      state(mode: AthanMode.full),
      recording: fixtureAthan,
      fullReady: true,
    );
    expect(result.effectiveMode, AthanMode.full);
    expect(result.events.length, greaterThan(60));
    expect(
      result.events.every(
        (e) => !e.dueAtUtc.isAfter(now.add(const Duration(days: 30))),
      ),
      isTrue,
    );
  });
  test('revoked permission cancels pending alerts; exact denial is never precise full playback', () async {
    final adapter = FixtureNotifications(),
        s = scheduler(FixtureNotifications(), PrayerReminderTarget.android);
    adapter.current = const ReminderCapability(permissionStatus: 'denied');
    final result = await scheduler(
      adapter,
      PrayerReminderTarget.ios,
    ).reconcile(state(), recording: fixtureAthan, openingReady: true);
    expect(result.failure, PrayerFailure.notificationsDenied);
    expect(adapter.queued, isEmpty);
    expect(adapter.cancellations, 1);
    final inexact = FixtureNotifications()
      ..current = const ReminderCapability(
        permissionStatus: 'granted',
        backgroundModes: {AthanMode.opening},
      );
    final queue = scheduler(inexact, PrayerReminderTarget.android);
    expect(
      (await queue.reconcile(
        state(),
        recording: fixtureAthan,
        openingReady: true,
      )).requiredAcknowledgement,
      'android_exact_alarm',
    );
    final accepted = await queue.reconcile(
      state(acknowledgements: {'android_exact_alarm': 1}),
      recording: fixtureAthan,
      openingReady: true,
    );
    expect(
      accepted.events.every((e) => e.deliveryMechanism == 'inexactSystem'),
      isTrue,
    );
    expect(
      (await s.reconcile(state(prayers: {}))).status,
      PrayerScheduleStatus.disabled,
    );
  });
  test(
    'iOS full remains requested but uses only acknowledged eligible opening',
    () async {
      final adapter = FixtureNotifications(),
          s = scheduler(FixtureNotifications(), PrayerReminderTarget.ios);
      final requested = state(mode: AthanMode.full);
      final blocked = await s.reconcile(
        requested,
        recording: fixtureAthan,
        openingReady: true,
        fullReady: true,
      );
      expect(blocked.requiredAcknowledgement, 'ios_background_full');
      expect(requested.reminders.requestedMode, AthanMode.full);
      final result = await scheduler(adapter, PrayerReminderTarget.ios)
          .reconcile(
            state(
              mode: AthanMode.full,
              acknowledgements: {'ios_background_full': 1},
            ),
            recording: fixtureAthan,
            openingReady: true,
          );
      expect(result.effectiveMode, AthanMode.opening);
    },
  );
  test('partial installation is not reported ready and stale generation cannot replace a newer queue', () async {
    final adapter = FixtureNotifications()..partial = true;
    final s = scheduler(adapter, PrayerReminderTarget.ios);
    expect(
      (await s.reconcile(
        state(generation: 3),
        recording: fixtureAthan,
        openingReady: true,
      )).status,
      PrayerScheduleStatus.partial,
    );
    final count = adapter.replacements;
    expect(
      (await s.reconcile(
        state(generation: 2),
        recording: fixtureAthan,
        openingReady: true,
      )).failure,
      PrayerFailure.needsAttention,
    );
    expect(adapter.replacements, count);
  });
  test(
    'delivery rejects expired, consumed, cancelled and wrong-generation events',
    () {
      ScheduledReminder event({
        int generation = 1,
        bool consumed = false,
        ReminderState status = ReminderState.pending,
      }) => ScheduledReminder(
        eventId: 'event',
        locationId: place.id,
        generation: generation,
        kind: PrayerKind.fajr,
        dueAtUtc: now,
        expiresAtUtc: now.add(const Duration(seconds: 60)),
        audioId: 'fixture',
        mode: AthanMode.opening,
        deliveryMechanism: 'system',
        state: status,
        consumed: consumed,
      );
      expect(
        PrayerReminderScheduler.isDeliverable(event(), state(), now),
        isTrue,
      );
      expect(
        PrayerReminderScheduler.isDeliverable(
          event(),
          state(),
          now.add(const Duration(seconds: 61)),
        ),
        isFalse,
      );
      expect(
        PrayerReminderScheduler.isDeliverable(
          event(generation: 0),
          state(),
          now,
        ),
        isFalse,
      );
      expect(
        PrayerReminderScheduler.isDeliverable(
          event(consumed: true),
          state(),
          now,
        ),
        isFalse,
      );
      expect(
        PrayerReminderScheduler.isDeliverable(
          event(status: ReminderState.cancelled),
          state(),
          now,
        ),
        isFalse,
      );
    },
  );
}
