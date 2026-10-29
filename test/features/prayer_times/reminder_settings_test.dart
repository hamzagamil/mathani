import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/l10n/app_localizations.dart';
import 'package:mathani/features/prayer_times/prayer_calculator.dart';
import 'package:mathani/features/prayer_times/prayer_controller.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_repository.dart';
import 'package:mathani/features/prayer_times/prayer_reminder_scheduler.dart';
import 'package:mathani/features/prayer_times/prayer_services.dart';
import 'package:mathani/features/prayer_times/reminder_settings.dart';

import '../../support/prayer_reminder_fixtures.dart';
import 'prayer_locations_test.dart' show addPlace;
import 'prayer_setup_test.dart' show Store, Locations;

class WriteFailStore extends Store {
  bool failWrite = false;
  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('unavailable');
    await super.write(value);
  }
}

class PendingPreview extends NoPrayerNotifications implements PrayerAudio {
  final waiting = Completer<void>();
  int stops = 0;
  @override
  Future<void> preview(AthanRecording recording) => waiting.future;
  @override
  Future<void> play(ScheduledReminder reminder) async {}
  @override
  Future<void> stop() async {
    stops++;
    if (!waiting.isCompleted) waiting.complete();
  }
}

void main() {
  PrayerController controller(
    Store store,
    FixtureNotifications adapter, {
    bool ready = true,
    PrayerReminderTarget target = PrayerReminderTarget.ios,
    PrayerAudio? audio,
  }) => PrayerController(
    repository: PrayerRepository(store),
    locationClient: Locations(),
    calculator: PrayerCalculator(
      jsonDecode(
        File('assets/prayer/ramadan_intervals.json').readAsStringSync(),
      ) as Map<String, dynamic>,
    ),
    notifications: adapter,
    reminderTarget: target,
    recordings: [fixtureAthan],
    audioReadiness: (_) async => (openingReady: ready, fullReady: ready),
    reminderAudio: audio,
    clock: () => DateTime.utc(2026, 10, 29, 12),
  );

  test(
    'daily intent persists after denial; only explicit authorization prompts',
    () async {
      final store = Store(), adapter = FixtureNotifications();
      adapter.current = const ReminderCapability(permissionStatus: 'denied');
      final c = controller(store, adapter);
      addTearDown(c.dispose);
      await c.initialize();
      await addPlace(c, 'Home');
      await c.selectAthan('fixture');
      await c.setDailyReminder(PrayerKind.fajr, true);
      expect(c.state.reminders.enabledPrayers, {PrayerKind.fajr});
      expect(c.reminderStatus.status, PrayerScheduleStatus.blocked);
      expect(c.reminderStatus.effectiveMode, isNull);
      expect(adapter.prompts, 0);
      await c.requestReminderAuthorization();
      expect(adapter.prompts, 1);
      final saved = PrayerState.fromJson(
        jsonDecode(store.data!) as Map<String, dynamic>,
      );
      expect(saved.reminders.enabledPrayers, {PrayerKind.fajr});
      await c.setDailyReminder(PrayerKind.sunrise, true);
      expect(c.failure, PrayerFailure.needsAttention);
      expect(c.state.reminders.enabledPrayers, {PrayerKind.fajr});
    },
  );
  test('full choice stays blocked until the exact fallback is acknowledged and readiness is real', () async {
    final store = Store(), adapter = FixtureNotifications();
    final c = controller(store, adapter);
    addTearDown(c.dispose);
    await c.initialize();
    await addPlace(c, 'Home');
    await c.selectAthan('fixture');
    await c.setAthanMode(AthanMode.full);
    await c.setDailyReminder(PrayerKind.fajr, true);
    expect(c.reminderStatus.requiredAcknowledgement, 'ios_background_full');
    expect(c.reminderStatus.effectiveMode, isNull);
    await c.acknowledgeReminderFallback('android_exact_alarm');
    expect(c.failure, PrayerFailure.needsAttention);
    await c.acknowledgeReminderFallback('ios_background_full');
    expect(c.reminderStatus.status, PrayerScheduleStatus.scheduled);
    expect(c.reminderStatus.effectiveMode, AthanMode.opening);
    expect(c.state.reminders.requestedMode, AthanMode.full);
    expect(c.reminderStatus.scheduledThroughUtc, isNotNull);
    await c.selectAthan('not-in-catalogue');
    expect(c.state.reminders.selectedAthanId, 'fixture');
    await c.setDailyReminder(PrayerKind.fajr, false);
    expect(c.reminderStatus.status, PrayerScheduleStatus.disabled);
    expect(adapter.queued, isEmpty);
  });
  test('failed persistence leaves existing intent and queue intact', () async {
    final store = WriteFailStore(), adapter = FixtureNotifications();
    final c = controller(store, adapter);
    addTearDown(c.dispose);
    await c.initialize();
    await addPlace(c, 'Home');
    await c.selectAthan('fixture');
    final revision = c.state.revision;
    store.failWrite = true;
    await c.setDailyReminder(PrayerKind.fajr, true);
    expect(c.state.revision, revision);
    expect(c.state.reminders.anyEnabled, false);
    expect(c.failure, PrayerFailure.secureStorageUnavailable);
  });
  test('Qiyam retains its own preference and cancelling it preserves daily choices', () async {
    final adapter = FixtureNotifications(), store = Store();
    final c = controller(store, adapter, ready: false);
    addTearDown(c.dispose);
    await c.initialize();
    await addPlace(c, 'Home');
    expect(c.state.reminders.qiyamEnabled, false);
    await c.setQiyamReminder(true);
    expect(c.state.reminders.enabledPrayers, isEmpty);
    expect(c.reminderStatus.status, PrayerScheduleStatus.scheduled);
    expect(
      adapter.queued.every((event) => event.kind == PrayerKind.qiyam),
      true,
    );
    await c.setDailyReminder(PrayerKind.fajr, true);
    expect(c.reminderStatus.requiredAcknowledgement, 'system_notification');
    expect(
      adapter.queued.every((event) => event.kind == PrayerKind.qiyam),
      true,
    );
    await c.acknowledgeReminderFallback('system_notification');
    await c.setQiyamReminder(false);
    expect(c.state.reminders.enabledPrayers, {PrayerKind.fajr});
    expect(
      adapter.queued.every((event) => event.kind == PrayerKind.fajr),
      true,
    );
    expect(
      PrayerState.fromJson(jsonDecode(store.data!) as Map<String, dynamic>)
          .reminders
          .qiyamEnabled,
      false,
    );
  });
  test(
    'Qiyam is recomputed for the active place and its calculation method',
    () async {
      final c = controller(Store(), FixtureNotifications(), ready: false);
      addTearDown(c.dispose);
      await c.initialize();
      final home = await addPlace(c, 'Home');
      final travel = await addPlace(
        c,
        'Travel',
        latitude: 40.7128,
        longitude: -74.006,
        zone: 'America/New_York',
        country: 'US',
      );
      await c.setQiyamReminder(true);
      final before = c.nextQiyam;
      await c.activateLocation(travel, confirmed: true);
      expect(c.nextQiyam, isNot(before));
      final travelTime = c.nextQiyam;
      c.viewLocation(home);
      expect(c.nextQiyam, travelTime);
      await c.updateCalculation(
        travel,
        c.state.activeLocation!.calculation.copyWith(
          method: PrayerMethod.egyptian,
        ),
      );
      expect(c.nextQiyam, isNot(travelTime));
      expect(
        c.reminderStatus.events.every((event) => event.locationId == travel),
        true,
      );
    },
  );
  testWidgets(
    'Stop stays visible and interrupts a preview that is still loading',
    (tester) async {
      final audio = PendingPreview();
      final c = controller(Store(), FixtureNotifications(), audio: audio);
      addTearDown(c.dispose);
      await c.initialize();
      await addPlace(c, 'Home');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ReminderSettings(controller: c)),
        ),
      );
      final preview = c.previewAthan(fixtureAthan);
      await tester.pump();
      final l = AppLocalizations.of(
        tester.element(find.byType(ReminderSettings)),
      );
      final stop = find.text(l.prayerAthanStop);
      expect(stop, findsOneWidget);
      expect(c.busy, true);
      await tester.tap(stop);
      await tester.pumpAndSettle();
      await preview;
      expect(audio.stops, 1);
      expect(c.previewingAthan, false);
      expect(c.busy, false);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final language in ['en', 'ar']) {
    testWidgets(
      'five prayer switches and platform disclosure fit large text in $language',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final c = controller(Store(), FixtureNotifications(), ready: false);
        addTearDown(c.dispose);
        await c.initialize();
        await addPlace(c, 'Home');
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(body: ReminderSettings(controller: c)),
          ),
        );
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(ReminderSettings)),
        );
        expect(find.byKey(const ValueKey('reminder-sunrise')), findsNothing);
        for (final prayer in dailyPrayers) {
          final field = find.byKey(ValueKey('reminder-${prayer.name}'));
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pump();
          await tester.scrollUntilVisible(field, 160);
          expect((tester.widget<SwitchListTile>(field)).value, false);
        }
        final disclosure = find.text(l.prayerIosFullLimit);
        final qiyam = find.byKey(const ValueKey('reminder-qiyam'));
        await tester.scrollUntilVisible(qiyam, 160);
        expect(tester.widget<SwitchListTile>(qiyam).value, false);
        final qiyamToggle = find.descendant(
          of: qiyam,
          matching: find.byType(Switch),
        );
        await tester.ensureVisible(qiyamToggle);
        await tester.pumpAndSettle();
        await tester.tap(qiyamToggle);
        await tester.pumpAndSettle();
        expect(c.state.reminders.qiyamEnabled, true);
        expect(c.state.reminders.enabledPrayers, isEmpty);
        await tester.scrollUntilVisible(disclosure, -160);
        expect(disclosure, findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
