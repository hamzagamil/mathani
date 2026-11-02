import 'dart:convert';
import 'dart:io';

import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';

import '../../support/prayer_fakes.dart';

void main() {
  final reference = jsonDecode(
    File('test/fixtures/prayer_times/reference.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final calculator = testCalculator();

  Place fixture(Map<String, dynamic> c) => Place(
    id: 'fixture',
    name: c['city'] as String,
    latitude: (c['latitude'] as num).toDouble(),
    longitude: (c['longitude'] as num).toDouble(),
    timezoneId: c['timezoneId'] as String,
    source: PlaceSource.search,
    calculation: CalculationSettings(
      method: switch (c['methodId']) {
        'north_america' => PrayerMethod.isna,
        final id => PrayerMethod.values.firstWhere((m) => m.id == id),
      },
      asr: c['madhhab'] == 'hanafi' ? AsrSetting.hanafi : AsrSetting.standard,
      highLatitudeRule: HighLatitudeRule.values.firstWhere(
        (r) => r.name == c['highLatitudeRule'],
      ),
    ),
  );

  Place at(
    double lat,
    double lon,
    String zone,
    PrayerMethod method, {
    Map<PrayerKind, int> offsets = const {},
  }) => Place(
    id: 'x',
    name: 'x',
    latitude: lat,
    longitude: lon,
    timezoneId: zone,
    source: PlaceSource.search,
    calculation: CalculationSettings(method: method, offsets: offsets),
  );

  test('SC-002: 10 cities, 5 methods, both Asr settings and latitude rules '
      'agree with the independent reference within one minute', () {
    final failures = <String>[];
    for (final raw in reference['cases'] as List) {
      final c = Map<String, dynamic>.from(raw as Map);
      final schedule = calculator.schedule(
        fixture(c),
        DateTime.parse(c['date'] as String),
      );
      final expected = c['events'] as Map;
      for (final e in schedule.events) {
        final v = expected[e.kind.name];
        if (v == null) continue;
        final delta = e.atUtc
            ?.difference(DateTime.parse(v as String))
            .inSeconds
            .abs();
        if (delta == null || delta > 60) {
          failures.add(
            '${c['city']} ${c['date']} ${c['methodId']} '
            '${c['madhhab']} ${e.kind.name} ${e.atUtc} $v $delta',
          );
        }
      }
    }
    expect(failures, isEmpty, reason: failures.take(12).join('\n'));
  });

  test('all 11 methods give six times for an ordinary place and date', () {
    for (final method in PrayerMethod.values) {
      final s = calculator.schedule(
        at(30.04, 31.24, 'Africa/Cairo', method),
        DateTime.utc(2026, 3, 15),
      );
      expect(s.events.every((e) => e.atUtc != null), isTrue, reason: '$method');
    }
  });

  test('Dubai and Turkey keep their built-in Asr minutes after the Asr '
      'correction (research R2)', () {
    for (final (method, preset) in [
      (PrayerMethod.dubai, adhan.CalculationMethodParameters.dubai()),
      (PrayerMethod.turkey, adhan.CalculationMethodParameters.turkiye()),
    ]) {
      final day = DateTime.utc(2026, 3, 15);
      final ours = calculator
          .schedule(at(25.2, 55.27, 'Asia/Dubai', method), day)
          .event(PrayerKind.asr)
          .atUtc!;
      final library = adhan.PrayerTimes(
        date: day,
        coordinates: const adhan.Coordinates(25.2, 55.27),
        calculationParameters: preset,
      ).asr.toUtc();
      // The library already adds the method's minutes; ours must too.
      expect(
        ours.difference(library).inSeconds.abs(),
        lessThanOrEqualTo(60),
        reason: '$method',
      );
    }
  });

  test('offsets move only their prayer and mark it adjusted (FR-015)', () {
    final day = DateTime.utc(2026, 3, 15);
    final base = calculator.schedule(
      at(30.04, 31.24, 'Africa/Cairo', PrayerMethod.egyptian),
      day,
    );
    final moved = calculator.schedule(
      at(
        30.04,
        31.24,
        'Africa/Cairo',
        PrayerMethod.egyptian,
        offsets: {PrayerKind.isha: 5, PrayerKind.fajr: -30},
      ),
      day,
    );
    for (final kind in PrayerKind.values.take(6)) {
      final delta = moved
          .event(kind)
          .atUtc!
          .difference(base.event(kind).atUtc!)
          .inMinutes;
      expect(delta, switch (kind) {
        PrayerKind.isha => 5,
        PrayerKind.fajr => -30,
        _ => 0,
      });
    }
    expect(moved.event(PrayerKind.isha).status, EventStatus.adjusted);
    expect(moved.event(PrayerKind.isha).adjustedBy, {Adjustment.offset});
    expect(moved.event(PrayerKind.dhuhr).status, EventStatus.normal);
  });

  test('offsets outside −30..30 are rejected', () {
    expect(
      () => CalculationSettings(offsets: {PrayerKind.isha: 31}),
      throwsFormatException,
    );
    expect(
      () => CalculationSettings(offsets: {PrayerKind.sunrise: 1}),
      throwsFormatException,
    );
  });

  test('the high-latitude default is one-seventh above 48°', () {
    expect(
      CalculationSettings.suggested('NO', 59.9).highLatitudeRule,
      HighLatitudeRule.seventhOfNight,
    );
    expect(
      CalculationSettings.suggested('EG', 30).highLatitudeRule,
      HighLatitudeRule.middleOfNight,
    );
  });

  test('Oslo in June: Fajr and Isha are adjusted by the latitude rule', () {
    final s = calculator.schedule(
      Place(
        id: 'oslo',
        name: 'Oslo',
        latitude: 59.91,
        longitude: 10.75,
        timezoneId: 'Europe/Oslo',
        source: PlaceSource.search,
        calculation: CalculationSettings.suggested('NO', 59.91),
      ),
      DateTime.utc(2026, 6, 21),
    );
    expect(
      s.event(PrayerKind.isha).adjustedBy,
      contains(Adjustment.highLatitude),
    );
    expect(
      s.event(PrayerKind.fajr).adjustedBy,
      contains(Adjustment.highLatitude),
    );
  });

  test('polar days are unavailable, never invented at midnight', () {
    final s = calculator.schedule(
      at(69.65, 18.96, 'Europe/Oslo', PrayerMethod.muslimWorldLeague),
      DateTime.utc(2026, 6, 21),
    );
    for (final kind in [
      PrayerKind.fajr,
      PrayerKind.sunrise,
      PrayerKind.maghrib,
      PrayerKind.isha,
    ]) {
      expect(s.event(kind).atUtc, isNull);
      expect(s.event(kind).status, EventStatus.unavailable);
    }
    expect(s.qiyamUtc, isNull);
  });

  test('after Isha, the next prayer is the next Fajr, never sunrise', () {
    final cairo = place(cairoResult());
    final isha = calculator
        .schedule(cairo, DateTime.utc(2026, 3, 15))
        .event(PrayerKind.isha)
        .atUtc!;
    final next = calculator.nextPrayer(
      cairo,
      isha.add(const Duration(minutes: 1)),
    )!;
    expect(next.kind, PrayerKind.fajr);
    expect(next.atUtc!.isAfter(isha), isTrue);
  });

  test('Umm al-Qura outside the reviewed calendar is unavailable', () {
    expect(
      calculator
          .schedule(
            at(21.42, 39.83, 'Asia/Riyadh', PrayerMethod.ummAlQura),
            DateTime.utc(2040),
          )
          .events
          .every((e) => e.atUtc == null),
      isTrue,
    );
  });

  test('times follow the place zone across a daylight-saving change', () {
    final london = place(londonResult());
    // 29 March 2026: UK clocks go forward.
    final before = calculator.schedule(london, DateTime.utc(2026, 3, 28));
    final after = calculator.schedule(london, DateTime.utc(2026, 3, 29));
    final gap = after
        .event(PrayerKind.dhuhr)
        .atUtc!
        .difference(before.event(PrayerKind.dhuhr).atUtc!);
    // Same solar noon one day later: about 24 h in UTC, not 23.
    expect(gap.inMinutes, closeTo(24 * 60, 1));
  });

  test('positions are kept to two decimals', () {
    final p = place(cairoResult());
    expect(p.latitude, 30.04);
    expect(p.longitude, 31.24);
  });

  test('country suggestions follow research R2', () {
    expect(CalculationSettings.suggestion('EG'), PrayerMethod.egyptian);
    expect(CalculationSettings.suggestion('AE'), PrayerMethod.dubai);
    expect(CalculationSettings.suggestion('TR'), PrayerMethod.turkey);
    expect(
      CalculationSettings.suggestion('GB'),
      PrayerMethod.moonsightingCommittee,
    );
    expect(CalculationSettings.suggestion('ID'), PrayerMethod.singapore);
    expect(CalculationSettings.suggestion('US'), PrayerMethod.isna);
    expect(
      CalculationSettings.suggestion('FR'),
      PrayerMethod.muslimWorldLeague,
    );
  });
}
