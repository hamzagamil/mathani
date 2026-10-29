import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/prayer_times/prayer_calculator.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';

void main() {
  final calendar = jsonDecode(
    File('assets/prayer/ramadan_intervals.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final reference = jsonDecode(
    File('test/fixtures/prayer_times/reference.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  SavedLocation place(Map<String, dynamic> c) => SavedLocation(
    id: 'fixture',
    label: c['city'] as String,
    latitude: (c['latitude'] as num).toDouble(),
    longitude: (c['longitude'] as num).toDouble(),
    timezoneId: c['timezoneId'] as String,
    source: LocationSource.manual,
    confirmedAtUtc: DateTime.utc(2026),
    calculation: CalculationPreferences(
      method: PrayerMethod.values.firstWhere((m) => m.id == c['methodId']),
      madhhab: PrayerMadhhab.values.firstWhere((m) => m.name == c['madhhab']),
      highLatitudeRule: HighLatitudeRule.values.firstWhere(
        (m) => m.name == c['highLatitudeRule'],
      ),
    ),
  );
  final calculator = PrayerCalculator(calendar);
  test('available instants agree with independent solar reference within one minute', () {
    final failures = <String>[];
    for (final raw in reference['cases'] as List) {
      final c = Map<String, dynamic>.from(raw as Map);
      final schedule = calculator.schedule(
        place(c),
        DateTime.parse(c['date'] as String),
      );
      final expected = c['events'] as Map;
      for (final e in schedule.events) {
        final v = expected[e.kind.name];
        if (v == null) continue;
        final delta = e.dueAtUtc
            ?.difference(DateTime.parse(v as String))
            .inSeconds
            .abs();
        if (delta == null || delta > 60) {
          failures.add(
            [
              c['city'],
              c['date'],
              c['methodId'],
              c['madhhab'],
              c['highLatitudeRule'],
              e.kind.name,
              e.dueAtUtc,
              v,
              delta,
            ].join(' '),
          );
        }
      }
    }
    expect(failures, isEmpty, reason: failures.take(12).join('\n'));
  });
  test('polar unavailable events are never fabricated at midnight', () {
    final p = SavedLocation(
      id: 'polar',
      label: 'Tromso',
      latitude: 69.6492,
      longitude: 18.9553,
      timezoneId: 'Europe/Oslo',
      source: LocationSource.manual,
      confirmedAtUtc: DateTime.utc(2026),
    );
    final s = calculator.schedule(p, DateTime.utc(2026, 6, 21));
    for (final e in s.events.where(
      (e) => {
        PrayerKind.fajr,
        PrayerKind.sunrise,
        PrayerKind.maghrib,
        PrayerKind.isha,
      }.contains(e.kind),
    )) {
      expect(e.dueAtUtc, isNull);
      expect(e.availability, PrayerAvailability.unavailable);
    }
  });
  test('after Isha next prayer is following local Fajr, never sunrise', () {
    final c = Map<String, dynamic>.from(
      (reference['cases'] as List).first as Map,
    );
    final p = place(c);
    final s = calculator.schedule(p, DateTime.utc(2026, 3, 15));
    final isha = s.events
        .firstWhere((e) => e.kind == PrayerKind.isha)
        .dueAtUtc!;
    final next = calculator.nextPrayer(
      p,
      isha.add(const Duration(minutes: 1)),
    )!;
    expect(next.kind, PrayerKind.fajr);
    expect(next.dueAtUtc!.isAfter(isha), isTrue);
  });
  test('Umm al Qura outside reviewed calendar range is unavailable', () {
    final p = SavedLocation(
      id: 'm',
      label: 'Makkah',
      latitude: 21.4225,
      longitude: 39.8262,
      timezoneId: 'Asia/Riyadh',
      source: LocationSource.manual,
      confirmedAtUtc: DateTime.utc(2026),
      calculation: const CalculationPreferences(method: PrayerMethod.ummAlQura),
    );
    expect(
      calculator
          .schedule(p, DateTime.utc(2040))
          .events
          .every((e) => e.dueAtUtc == null),
      isTrue,
    );
  });
}
