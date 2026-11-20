import 'dart:convert';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mathani/features/prayer_times/athan_catalogue.dart';
import 'package:mathani/features/prayer_times/prayer_alerts.dart';
import 'package:mathani/features/prayer_times/prayer_calculator.dart';
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
    test('at most 52, all in the future, in time order, never sunrise', () {
      final alerts = build(state(prayers: dailyPrayers, qiyam: true));
      expect(alerts, hasLength(52));
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

    test('text: the prayer time and words from the athan, never the place', () {
      final alerts = build(state());
      final fajr = alerts.firstWhere((a) => a.kind == PrayerKind.fajr);
      final dhuhr = alerts.firstWhere((a) => a.kind == PrayerKind.dhuhr);
      expect(fajr.title, 'Time for Fajr prayer');
      expect(fajr.body, 'Prayer is better than sleep.');
      expect(dhuhr.title, 'Time for Dhuhr prayer');
      expect(dhuhr.body, 'Come to prayer, come to success.');
      expect(
        alerts.any((a) => '${a.title} ${a.body}'.contains('Cairo')),
        isFalse,
      );
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

  group("Jumu'ah and Duha (specs/015)", () {
    // 2026-03-20 is a Friday; `now` is Sunday 2026-03-15.
    final friday = DateTime.utc(2026, 3, 20);
    final cairo = place(cairoResult());

    PrayerState with_(AlertSettings alerts, {Place? where}) {
      final p = where ?? cairo;
      return PrayerState(
        places: [p],
        current: p.id,
        alerts: alerts,
        generation: 1,
      );
    }

    bool onFriday(Alert a) =>
        a.atUtc.isAfter(friday.subtract(const Duration(hours: 3))) &&
        a.atUtc.isBefore(friday.add(const Duration(hours: 21)));

    test(
      "Friday Dhuhr is named Jumu'ah, with the same id, time and body (FR-001)",
      () {
        final alerts = build(
          with_(AlertSettings(prayers: {PrayerKind.dhuhr}, jumuah: false)),
        );
        final dhuhrs = alerts.where((a) => a.kind == PrayerKind.dhuhr).toList();
        final fri = dhuhrs.singleWhere(onFriday);
        expect(fri.title, "Time for Jumu'ah prayer");
        expect(fri.body, 'Come to prayer, come to success.');
        final fridayDhuhr = calculator
            .schedule(cairo, friday)
            .event(PrayerKind.dhuhr)
            .atUtc;
        expect(fri.atUtc, fridayDhuhr);
        // Cairo's Dhuhr is near 10:00 UTC, so the UTC date is the place's date.
        for (final a in dhuhrs) {
          final isFriday = a.atUtc.weekday == DateTime.friday;
          expect(
            a.title,
            isFriday ? "Time for Jumu'ah prayer" : 'Time for Dhuhr prayer',
          );
        }
      },
    );

    test('the reminder is 20 minutes before Friday Dhuhr, only on Fridays (FR-004)', () {
      final alerts = build(with_(AlertSettings(prayers: {PrayerKind.dhuhr})));
      final reminders = alerts
          .where((a) => a.kind == PrayerKind.jumuah)
          .toList();
      expect(reminders, isNotEmpty);
      for (final r in reminders) {
        final day = calculator.schedule(
          cairo,
          DateTime.utc(r.atUtc.year, r.atUtc.month, r.atUtc.day),
        );
        expect(day.isFriday, isTrue);
        expect(
          r.atUtc,
          day
              .event(PrayerKind.dhuhr)
              .atUtc!
              .subtract(const Duration(minutes: 20)),
        );
        expect(r.title, "Jumu'ah prayer in 20 minutes");
        expect(r.sound, toneSound);
        expect(r.full, isFalse);
      }
    });

    test('the reminder follows an adjusted Dhuhr', () {
      final adjusted = cairo.copyWith(
        calculation: cairo.calculation.copyWith(offsets: {PrayerKind.dhuhr: 5}),
      );
      final r = build(
        with_(AlertSettings(prayers: {PrayerKind.dhuhr}), where: adjusted),
      ).firstWhere((a) => a.kind == PrayerKind.jumuah);
      final dhuhr = calculator
          .schedule(adjusted, friday)
          .event(PrayerKind.dhuhr)
          .atUtc!;
      expect(r.atUtc, dhuhr.subtract(const Duration(minutes: 20)));
    });

    test(
      'never changed: follows the Dhuhr alert; changed: independent (FR-005)',
      () {
        expect(AlertSettings(prayers: {PrayerKind.dhuhr}).jumuahOn, isTrue);
        expect(AlertSettings(prayers: {PrayerKind.fajr}).jumuahOn, isFalse);
        expect(
          AlertSettings(prayers: {PrayerKind.dhuhr}, jumuah: false).jumuahOn,
          isFalse,
        );
        expect(AlertSettings(jumuah: true).jumuahOn, isTrue);
        expect(AlertSettings(jumuah: true).any, isTrue);
        final off = build(
          with_(AlertSettings(prayers: {PrayerKind.dhuhr}, jumuah: false)),
        );
        expect(off.any((a) => a.kind == PrayerKind.jumuah), isFalse);
        final only = build(with_(AlertSettings(jumuah: true)));
        expect(only.map((a) => a.kind).toSet(), {PrayerKind.jumuah});
      },
    );

    test('settings JSON: old saves follow Dhuhr, Duha is off (FR-022)', () {
      final old = AlertSettings.fromJson(
        jsonDecode('{"prayers":["dhuhr"],"qiyam":false}')
            as Map<String, dynamic>,
      );
      expect(old.jumuah, isNull);
      expect(old.jumuahOn, isTrue);
      expect(old.duha, isFalse);
      expect(old.toJson().containsKey('jumuah'), isFalse);
      final chosen = AlertSettings(jumuah: false, duha: true);
      final back = AlertSettings.fromJson(
        jsonDecode(jsonEncode(chosen.toJson())) as Map<String, dynamic>,
      );
      expect(back.jumuah, isFalse);
      expect(back.duha, isTrue);
    });

    test('Duha: one tone reminder a day, halfway between Sunrise and Dhuhr (FR-008)', () {
      final alerts = build(with_(AlertSettings(duha: true)));
      expect(alerts.map((a) => a.kind).toSet(), {PrayerKind.duha});
      final first = alerts.first;
      final day = calculator.schedule(
        cairo,
        DateTime.utc(first.atUtc.year, first.atUtc.month, first.atUtc.day),
      );
      final sunrise = day.event(PrayerKind.sunrise).atUtc!,
          dhuhr = day.event(PrayerKind.dhuhr).atUtc!;
      final mid = sunrise.add(dhuhr.difference(sunrise) ~/ 2);
      expect(
        first.atUtc.difference(mid).inSeconds.abs(),
        lessThanOrEqualTo(30),
      );
      expect(first.atUtc.second, 0);
      expect(first.title, 'Duha prayer');
      expect(first.sound, toneSound);
    });

    test('a full list keeps nearer reminders and gives its last day to prayers (R10)', () {
      final alerts = build(
        with_(AlertSettings(prayers: dailyPrayers, qiyam: true, duha: true)),
      );
      expect(alerts, hasLength(52));
      // Today's reminders are kept even though prayer alerts were cut at the far end.
      expect(alerts.take(8).any((a) => reminderKinds.contains(a.kind)), isTrue);
      final lastDay = alerts.last.atUtc.subtract(const Duration(days: 1));
      final cut = build(with_(AlertSettings(prayers: dailyPrayers)));
      final prayerTimes = alerts
          .where((a) => !reminderKinds.contains(a.kind))
          .map((a) => a.atUtc)
          .toSet();
      // No prayer alert of the last day is missing while a reminder of that day is kept.
      final keptLateReminders = alerts.where(
        (a) => reminderKinds.contains(a.kind) && !a.atUtc.isBefore(lastDay),
      );
      final missingLatePrayers = cut.where(
        (a) =>
            !a.atUtc.isBefore(lastDay) &&
            !a.atUtc.isAfter(alerts.last.atUtc) &&
            !prayerTimes.contains(a.atUtc),
      );
      expect(
        keptLateReminders.isNotEmpty && missingLatePrayers.isNotEmpty,
        isFalse,
      );
      for (var i = 1; i < alerts.length; i++) {
        expect(alerts[i].atUtc.isBefore(alerts[i - 1].atUtc), isFalse);
      }
    });
  });

  test('calculator: Duha is null when Sunrise or Dhuhr is missing', () {
    expect(PrayerCalculator.duhaTime(null, DateTime.utc(2026)), isNull);
    expect(
      PrayerCalculator.duhaTime(
        DateTime.utc(2026, 1, 1, 6, 10),
        DateTime.utc(2026, 1, 1, 11, 50),
      ),
      DateTime.utc(2026, 1, 1, 9),
    );
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
