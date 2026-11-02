import 'dart:convert';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mathani/features/prayer_times/athan_catalogue.dart';
import 'package:mathani/features/prayer_times/prayer_alerts.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_services.dart';

import '../../support/prayer_fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  final now = DateTime.utc(2026, 3, 15, 8);
  final calculator = testCalculator();

  PrayerState state({
    Set<PrayerKind> prayers = const {PrayerKind.fajr, PrayerKind.dhuhr},
    bool qiyam = false,
    String sound = toneSound,
    int generation = 3,
    Place? where,
  }) {
    final p = where ?? place(cairoResult());
    return PrayerState(
      places: [p],
      current: p.id,
      alerts: AlertSettings(prayers: prayers, qiyam: qiyam, sound: sound),
      generation: generation,
    );
  }

  List<Alert> build(PrayerState s, {DateTime? at}) => buildAlerts(
    state: s,
    now: at ?? now,
    calculator: calculator,
    catalogue: AthanCatalogue(const []),
    l10n: english(),
  );

  group('buildAlerts (SC-004)', () {
    test('at most 60, all in the future, in time order, never sunrise', () {
      final alerts = build(state(prayers: dailyPrayers, qiyam: true));
      expect(alerts, hasLength(60));
      expect(alerts.every((a) => a.atUtc.isAfter(now)), isTrue);
      expect(alerts.any((a) => a.kind == PrayerKind.sunrise), isFalse);
      for (var i = 1; i < alerts.length; i++) {
        expect(alerts[i].atUtc.isAfter(alerts[i - 1].atUtc), isTrue);
      }
      // 6 a day: at least 7 days ahead (FR-021).
      expect(
        alerts.last.atUtc.difference(now),
        greaterThan(const Duration(days: 7)),
      );
    });

    test('only enabled prayers, with the state generation', () {
      final alerts = build(state(prayers: {PrayerKind.isha}, generation: 9));
      expect(alerts.map((a) => a.kind).toSet(), {PrayerKind.isha});
      expect(alerts.every((a) => a.generation == 9), isTrue);
    });

    test('ids are stable across refills, so a refill never duplicates', () {
      final a = build(state()).map((a) => a.id).toList();
      final b = build(state(generation: 4)).map((a) => a.id).toList();
      expect(a, b);
      expect(a.toSet(), hasLength(a.length));
    });

    test('after a place change no alert keeps an old id and time', () {
      final cairo = build(state());
      final london = build(state(where: place(londonResult(), id: 'p2')));
      final old = {for (final a in cairo) a.id: a.atUtc};
      expect(london.where((a) => old[a.id] == a.atUtc), isEmpty);
    });

    test('nothing enabled gives no alerts; unknown sounds fall back to the '
        'tone', () {
      expect(build(state(prayers: const {})), isEmpty);
      final alerts = build(state(sound: 'gone'));
      expect(alerts.every((a) => a.sound == toneSound), isTrue);
    });

    test(
      'Qiyam adds one tone alert per night; prayer alerts are unchanged',
      () {
        final without = build(state());
        final withQiyam = build(state(qiyam: true));
        final qiyam = withQiyam
            .where((a) => a.kind == PrayerKind.qiyam)
            .toList();
        expect(qiyam, isNotEmpty);
        expect(qiyam.every((a) => a.sound == toneSound), isTrue);
        final days = qiyam.map(
          (a) => a.atUtc.toIso8601String().substring(0, 10),
        );
        expect(days.toSet(), hasLength(qiyam.length));
        final prayers = withQiyam
            .where((a) => a.kind != PrayerKind.qiyam)
            .map((a) => a.id);
        expect(without.map((a) => a.id).take(prayers.length), prayers);
      },
    );

    test('unavailable times get no alert and are never invented (FR-014)', () {
      final polar = Place(
        id: 'tromso',
        name: 'Tromsø',
        latitude: 69.65,
        longitude: 18.96,
        timezoneId: 'Europe/Oslo',
        source: PlaceSource.search,
        calculation: CalculationSettings(),
      );
      // Midnight sun: no normal day, so no alerts in the next two weeks.
      expect(
        build(
          state(prayers: dailyPrayers, qiyam: true, where: polar),
          at: DateTime.utc(2026, 6, 20),
        ),
        isEmpty,
      );
    });
  });

  group('PrayerAlerts', () {
    test('refill hands the list to the platform, and cancels when nothing is '
        'on', () async {
      final h = Harness(stored: jsonEncode(state().toJson()), now: now);
      await h.hub.onAppActive();
      expect(h.alerts.pending, isNotEmpty);
      expect(h.alerts.generations.last, 3);
      final s = await h.hub.state();
      await h.hub.save(
        s.copyWith(alerts: s.alerts.copyWith(prayers: const {})).bumped(),
      );
      expect(h.alerts.cancels, 1);
      expect(h.hub.pending, 0);
    });

    test(
      'a save that does not change the generation does not refill',
      () async {
        final h = Harness(stored: jsonEncode(state().toJson()), now: now);
        await h.hub.onAppActive();
        final calls = h.alerts.replaced.length;
        await h.hub.save((await h.hub.state()).copyWith(movedNotice: 'x'));
        expect(h.alerts.replaced.length, calls);
      },
    );

    test('nothing happens when not set up', () async {
      final h = Harness(now: now);
      await h.hub.onAppActive();
      expect(h.alerts.replaced, isEmpty);
    });

    group('My location refresh (R4)', () {
      Future<Harness> mine({bool chosen = false}) async {
        final me = place(
          cairoResult(source: 'location'),
          id: 'me',
          calculation: CalculationSettings(
            method: PrayerMethod.egyptian,
            methodChosen: chosen,
          ),
        );
        final s = PrayerState(
          myLocation: me,
          current: myLocationKey,
          alerts: AlertSettings(prayers: {PrayerKind.fajr}),
        );
        return Harness(stored: jsonEncode(s.toJson()), now: now)
          ..location.granted = true;
      }

      test('a 5 km move does not resolve', () async {
        final h = await mine();
        h.location.position = (latitude: 30.08, longitude: 31.24);
        await h.hub.onAppActive();
        expect(h.location.resolves, 0);
      });

      test('a move to London resolves, switches the method suggestion and '
          'sets the moved notice', () async {
        final h = await mine();
        h.location
          ..position = (latitude: 51.51, longitude: -0.13)
          ..resolved = londonResult(source: 'location');
        await h.hub.onAppActive();
        final s = await h.hub.state();
        expect(h.location.resolves, 1);
        expect(s.myLocation!.city, 'London');
        expect(s.myLocation!.id, 'me');
        expect(
          s.myLocation!.calculation.method,
          PrayerMethod.moonsightingCommittee,
        );
        expect(s.movedNotice, 'London');
        expect(h.alerts.generations.last, s.generation);
      });

      test('a method the reader chose is kept', () async {
        final h = await mine(chosen: true);
        h.location
          ..position = (latitude: 51.51, longitude: -0.13)
          ..resolved = londonResult(source: 'location');
        await h.hub.onAppActive();
        expect(
          (await h.hub.state()).myLocation!.calculation.method,
          PrayerMethod.egyptian,
        );
      });

      test('without permission there is no prompt and no lookup', () async {
        final h = await mine();
        h.location
          ..granted = false
          ..position = (latitude: 51.51, longitude: -0.13);
        await h.hub.onAppActive();
        expect(h.location.resolves, 0);
        expect(h.location.detects, 0);
      });

      test('a fixed city is never refreshed', () async {
        final h = Harness(stored: jsonEncode(state().toJson()), now: now)
          ..location.granted = true
          ..location.position = (latitude: 51.51, longitude: -0.13);
        await h.hub.onAppActive();
        expect(h.location.resolves, 0);
      });

      test('at most once per 30 minutes', () async {
        final h = await mine();
        h.location.position = (latitude: 51.51, longitude: -0.13);
        h.location.resolved = londonResult(source: 'location');
        await h.hub.onAppActive();
        h.location.position = (latitude: 30.04, longitude: 31.24);
        h.clock = now.add(const Duration(minutes: 10));
        await h.hub.onAppActive();
        expect(h.location.resolves, 1);
      });
    });

    test('alert taps reach the route host; Android athan pauses '
        'memorization', () async {
      final h = Harness(
        stored: jsonEncode(state().toJson()),
        now: now,
        target: TargetPlatform.android,
      );
      await h.hub.onAppActive();
      final opened = h.hub.opened.first;
      h.alerts.controller.add(const AlertOpened(PrayerKind.fajr, 1));
      expect((await opened).kind, PrayerKind.fajr);
      h.alerts.controller.add(const AthanStarted());
      await Future<void>.delayed(Duration.zero);
      expect(h.memorizationPauses, 1);
    });
  });
}
