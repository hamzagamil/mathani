// Shared UI scenarios: run on the VM and through integration_test on devices.
// Location and persistence are scripted so these do not certify OS permissions
// or Keychain/Keystore. Those require the separate manual acceptance matrix.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:mathani/app/l10n/app_localizations.dart';
import 'package:mathani/features/prayer_times/prayer_calculator.dart';
import 'package:mathani/features/prayer_times/prayer_controller.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_repository.dart';
import 'package:mathani/features/prayer_times/prayer_services.dart';
import 'package:mathani/features/prayer_times/prayer_times_screen.dart';
import 'package:mathani/features/prayer_times/prayer_time_zones.dart';

class _Store implements PrayerSnapshotStore {
  String? value;
  int writes = 0;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async {
    value = data;
    writes++;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

class _Locations implements PrayerLocationClient {
  bool offline = false;
  int calls = 0;
  Map<String, dynamic> place = {
    'city': 'Cairo',
    'region': 'Cairo',
    'countryCode': 'EG',
    'latitude': 30.0444,
    'longitude': 31.2357,
    'timezoneId': 'Africa/Cairo',
    'source': 'manual',
    'approximate': false,
    'requiresConfirmation': true,
  };
  void _access() {
    calls++;
    if (offline) throw const PrayerException(PrayerFailure.offline);
  }

  @override
  Future<Map<String, dynamic>> detect(String language) async {
    _access();
    throw const PrayerException(PrayerFailure.locationDenied);
  }

  @override
  Future<List<Map<String, dynamic>>> search(
    String query,
    String language,
  ) async {
    _access();
    return query.trim().length < 2 ? [] : [Map.of(place)];
  }

  @override
  Future<Map<String, dynamic>> resolve(
    Map<String, dynamic> candidate,
    String language,
  ) async {
    _access();
    return {...candidate, 'timezoneId': place['timezoneId']};
  }

  @override
  Future<Map<String, dynamic>> approximate(String language) async {
    _access();
    return {...place, 'source': 'ip', 'approximate': true};
  }

  @override
  void cancelSearch() {}
  @override
  void dispose() {}
}

void prayerSetupScenarios() {
  Future<PrayerController> launch(
    WidgetTester tester,
    _Store store,
    _Locations locations, {
    DateTime? now,
    PrayerClock? clock,
  }) async {
    final calculator = await tester.runAsync(PrayerCalculator.load);
    final controller = PrayerController(
      repository: PrayerRepository(store),
      locationClient: locations,
      calculator: calculator!,
      clock: clock ?? () => now ?? DateTime.utc(2026, 10, 29, 12),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PrayerTimesScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.initialized, isTrue);
    return controller;
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final target = find.text(label).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'three saved places retain conventions through view, activation, DST and deletion',
    (tester) async {
      final store = _Store();
      var now = DateTime.utc(2026, 3, 8, 6, 59);
      final c = await launch(tester, store, _Locations(), clock: () => now);
      Future<String> save(
        String label,
        double latitude,
        double longitude,
        String zone,
        String country,
      ) async {
        await c.choose({
          'city': label,
          'latitude': latitude,
          'longitude': longitude,
          'timezoneId': zone,
          'countryCode': country,
          'source': 'manual',
        });
        await c.confirmCandidate(label: label);
        await tester.pumpAndSettle();
        return c.state.locations.last.id;
      }

      final home = await save('Home', 30.0444, 31.2357, 'Africa/Cairo', 'EG');
      final newYork = await save(
        'New York',
        40.7128,
        -74.006,
        'America/New_York',
        'US',
      );
      final sydney = await save(
        'Sydney',
        -33.8688,
        151.2093,
        'Australia/Sydney',
        'AU',
      );
      expect(c.state.activeLocationId, home);
      expect(find.text('Australia/Sydney'), findsOneWidget);
      await tester.tap(find.byTooltip('Saved locations'));
      await tester.pumpAndSettle();
      await tap(tester, 'New York');
      expect(c.viewedLocationId, newYork);
      expect(c.state.activeLocationId, home);
      for (final method in PrayerMethod.values) {
        for (final madhhab in PrayerMadhhab.values) {
          await c.updateCalculation(
            newYork,
            CalculationPreferences(method: method, madhhab: madhhab),
          );
          expect(c.failure, isNull);
        }
      }
      final before = tz.TZDateTime.from(
        now,
        prayerTimeZone('America/New_York'),
      ).timeZoneOffset;
      now = DateTime.utc(2026, 3, 8, 7, 1);
      c.refresh();
      await tester.pumpAndSettle();
      expect(
        tz.TZDateTime.from(
              now,
              prayerTimeZone('America/New_York'),
            ).timeZoneOffset -
            before,
        const Duration(hours: 1),
      );
      expect(c.schedule!.localDate, DateTime.utc(2026, 3, 8));
      expect(c.nextPrayer!.dueAtUtc!.isAfter(now), isTrue);
      await c.activateLocation(newYork, confirmed: true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime.utc(2026, 3, 9, 4, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(c.schedule!.localDate, DateTime.utc(2026, 3, 9));
      expect(c.activeSchedule!.timezoneId, 'America/New_York');
      final offline = _Locations()..offline = true;
      await tester.pumpWidget(const SizedBox.shrink());
      final restarted = await launch(tester, store, offline, clock: () => now);
      expect(restarted.state.locations, hasLength(3));
      expect(restarted.viewedLocationId, newYork);
      expect(
        restarted.viewedLocation!.calculation.madhhab,
        PrayerMadhhab.hanbali,
      );
      expect(offline.calls, 0);
      await restarted.renameLocation(sydney, 'Family');
      await restarted.deleteLocation(newYork, replacementId: sydney);
      expect(restarted.state.activeLocationId, sydney);
      expect(restarted.viewedLocation!.label, 'Family');
      await restarted.clearPrayerData(confirmed: true);
      await tester.pumpAndSettle();
      expect(store.value, isNull);
      expect(restarted.schedule, isNull);
    },
  );

  testWidgets(
    'denied detection -> manual confirmation -> offline route restart',
    (tester) async {
      final store = _Store(), locations = _Locations();
      final controller = await launch(tester, store, locations);
      expect(
        locations.calls,
        0,
        reason: 'Opening the screen must not request location',
      );
      await tap(tester, 'Choose location');
      await tap(tester, 'Detect my location');
      expect(controller.failure, PrayerFailure.locationDenied);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Cairo');
      await tester.pumpAndSettle();
      await tap(tester, 'Cairo');
      expect(store.writes, 0);
      expect(controller.state.locations, isEmpty);
      await tap(tester, 'Use this location');
      expect(controller.state.activeLocation!.source, LocationSource.manual);
      expect(controller.schedule!.events, hasLength(6));
      expect(controller.nextPrayer!.kind, isNot(PrayerKind.sunrise));
      final id = controller.state.activeLocationId;
      final events = controller.schedule!.events
          .map((e) => e.dueAtUtc)
          .toList();
      await tester.pumpWidget(const SizedBox.shrink());
      final offline = _Locations()..offline = true;
      final restarted = await launch(tester, store, offline);
      expect(restarted.state.activeLocationId, id);
      expect(
        restarted.schedule!.events.map((e) => e.dueAtUtc).toList(),
        events,
      );
      expect(offline.calls, 0);
      expect(find.text('Africa/Cairo'), findsOneWidget);
    },
  );

  testWidgets(
    'IP candidate can be rejected and is saved only on confirmation',
    (tester) async {
      final store = _Store();
      final controller = await launch(tester, store, _Locations());
      await tap(tester, 'Choose location');
      await tap(tester, 'Try approximate location');
      expect(controller.candidate!['approximate'], isTrue);
      expect(store.writes, 0);
      expect(controller.state.activeLocationId, isNull);
      await tap(tester, 'Change location');
      expect(controller.candidate, isNull);
      expect(store.writes, 0);
      await tap(tester, 'Try approximate location');
      await tap(tester, 'Use this location');
      expect(controller.state.activeLocation!.source, LocationSource.ip);
      expect(controller.state.activeLocation!.approximate, isTrue);
      expect(store.writes, 1);
    },
  );

  testWidgets('failed replacement preserves the confirmed saved schedule', (
    tester,
  ) async {
    final store = _Store(), locations = _Locations();
    final controller = await launch(tester, store, locations);
    await tap(tester, 'Choose location');
    await tap(tester, 'Try approximate location');
    await tap(tester, 'Use this location');
    final id = controller.state.activeLocationId, snapshot = store.value;
    locations.offline = true;
    await tester.tap(find.byTooltip('Choose location'));
    await tester.pumpAndSettle();
    await tap(tester, 'Detect my location');
    expect(controller.failure, PrayerFailure.offline);
    expect(controller.state.activeLocationId, id);
    expect(store.value, snapshot);
    expect(controller.schedule!.events, hasLength(6));
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('polar unavailable rows show a label rather than midnight', (
    tester,
  ) async {
    final locations = _Locations();
    locations.place = {
      ...locations.place,
      'city': 'Tromso',
      'countryCode': 'NO',
      'latitude': 69.6492,
      'longitude': 18.9553,
      'timezoneId': 'Europe/Oslo',
    };
    final controller = await launch(
      tester,
      _Store(),
      locations,
      now: DateTime.utc(2026, 6, 21, 12),
    );
    await tap(tester, 'Choose location');
    await tap(tester, 'Try approximate location');
    await tap(tester, 'Use this location');
    final unavailable = controller.schedule!.events.where(
      (e) => e.dueAtUtc == null,
    );
    expect(unavailable, isNotEmpty);
    final list = find.byType(ListView).first;
    await tester.drag(list, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Unavailable'), findsWidgets);
    expect(find.text('00:00'), findsNothing);
    expect(find.text('12:00 AM'), findsNothing);
  });
}
