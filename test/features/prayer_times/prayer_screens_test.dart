import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/l10n/app_localizations.dart';
import 'package:mathani/features/prayer_times/prayer_alerts.dart';
import 'package:mathani/features/prayer_times/prayer_controller.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_notification_open_host.dart';
import 'package:mathani/features/prayer_times/prayer_services.dart';
import 'package:mathani/features/prayer_times/prayer_times_screen.dart';

import '../../support/prayer_fakes.dart';

void main() {
  final now = DateTime.utc(2026, 3, 15, 8);

  Future<(Harness, PrayerController)> setUpScreen(
    WidgetTester tester, {
    PrayerState? state,
    Locale locale = const Locale('en'),
  }) async {
    // A narrow phone with large text (FR-032). Tall, so lazily built lists build every row.
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    // Created in the real zone: the repository's future chain must not belong to fake time.
    final (h, c) = (await tester.runAsync(() async {
      final h = Harness(
        stored: state == null ? null : jsonEncode(state.toJson()),
        now: now,
      );
      final c = PrayerController(hub: h.hub, clock: () => h.clock);
      await c.initialize();
      return (h, c);
    }))!;
    await tester.pumpWidget(
      PrayerScope(
        alerts: h.hub,
        child: MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: PrayerTimesScreen(controller: c),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return (h, c);
  }

  /// The screen ticks every second for the countdown, so it never "settles". Futures from
  /// the real zone (the harness) and fake time (the widgets) are given turns in alternation.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tearDownScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  PrayerState cairoState({Set<PrayerKind> prayers = const {}}) {
    final p = place(cairoResult());
    return PrayerState(
      places: [p],
      current: p.id,
      alerts: AlertSettings(prayers: prayers),
    );
  }

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('first time: two choices and no permission before a tap '
        '(${locale.languageCode})', (tester) async {
      final (h, _) = await setUpScreen(tester, locale: locale);
      final l = lookupAppLocalizations(locale);
      expect(find.text(l.prayerUseMyLocation), findsOneWidget);
      expect(find.text(l.prayerSearchCity), findsOneWidget);
      expect(h.location.detects, 0);
      expect(h.alerts.requests, 0);
      expect(tester.takeException(), isNull);
      await tearDownScreen(tester);
    });

    testWidgets('schedule: six rows, sunrise marked, day arrows '
        '(${locale.languageCode})', (tester) async {
      await setUpScreen(tester, state: cairoState(), locale: locale);
      final l = lookupAppLocalizations(locale);
      for (final name in [
        l.prayerFajr,
        l.prayerSunrise,
        l.prayerDhuhr,
        l.prayerMaghrib,
        l.prayerIsha,
      ]) {
        expect(find.text(name), findsWidgets);
      }
      expect(find.text(l.prayerNotAPrayer), findsOneWidget);
      expect(find.textContaining(l.prayerNext), findsOneWidget);
      await tester.tap(find.byTooltip(l.prayerNextDay));
      await tester.pump();
      expect(find.text(l.prayerToday), findsOneWidget);
      expect(find.textContaining(l.prayerNext), findsNothing);
      expect(tester.takeException(), isNull);
      await tearDownScreen(tester);
    });
  }

  testWidgets('search: the Suggested row sets the place without a confirm '
      'step', (tester) async {
    final (h, c) = await setUpScreen(tester);
    await tester.tap(find.text('Search for a city'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Suggested: Cairo'), findsOneWidget);
    await tester.tap(find.textContaining('Suggested: Cairo'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await settle(tester);
    expect(c.state.currentPlace?.source, PlaceSource.estimate);
    expect(find.text('Cairo'), findsWidgets);
    await tearDownScreen(tester);
  });

  testWidgets('alerts sheet: five switches and no sunrise switch; blocked '
      'status explains how to fix it', (tester) async {
    final (h, c) = await setUpScreen(
      tester,
      state: cairoState(prayers: {PrayerKind.fajr}),
    );
    h.alerts.permission = NotificationPermission.denied;
    await tester.tap(find.byTooltip('Alerts'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await settle(tester);
    expect(find.byType(SwitchListTile), findsNWidgets(6)); // 5 prayers + Qiyam
    expect(find.byKey(const ValueKey('alert-sunrise')), findsNothing);
    expect(
      find.text('Alerts are blocked. Your choices are saved.'),
      findsOneWidget,
    );
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.text('Simple tone'), findsOneWidget);
    expect(find.text('Silent'), findsOneWidget);
    await tester.tap(find.byType(IconButton).last); // close
    await settle(tester);
    await tearDownScreen(tester);
  });

  testWidgets('an alert tap opens Prayer Times once', (tester) async {
    final h = (await tester.runAsync(() async {
      final h = Harness(stored: jsonEncode(cairoState().toJson()), now: now);
      await h.hub.services();
      return h;
    }))!;
    await tester.pumpWidget(
      PrayerScope(
        alerts: h.hub,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PrayerNotificationOpenHost(
            destination: (_) => const Text('prayer route'),
            child: const Text('reader'),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.text('reader'), findsOneWidget);
    await tester.runAsync(h.hub.onAppActive);
    h.alerts.controller.add(const AlertOpened(PrayerKind.fajr, 1));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await settle(tester);
    expect(find.text('prayer route'), findsOneWidget);
  });

  testWidgets('first-time screen keeps "Use my location" off after a refusal', (
    tester,
  ) async {
    final (h, c) = await setUpScreen(tester);
    h.location.detectFailure = PrayerFailure.locationDenied;
    await tester.tap(find.text('Use my location'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Use my location'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(
      find.text("Location wasn't allowed. Search for a city instead."),
      findsOneWidget,
    );
    await tearDownScreen(tester);
  });
}
