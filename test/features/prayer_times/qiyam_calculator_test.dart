import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/prayer_times/prayer_calculator.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';

import '../../support/prayer_fakes.dart';

void main() {
  final calculator = testCalculator();

  test('last third uses elapsed UTC time, rounds once, and rejects invalid '
      'boundaries', () {
    final maghrib = DateTime.utc(2026, 10, 29, 15, 17);
    final fajr = DateTime.utc(2026, 10, 30, 2, 43);
    expect(
      PrayerCalculator.qiyamStart(maghrib, fajr),
      DateTime.utc(2026, 10, 29, 22, 54),
    );
    expect(PrayerCalculator.qiyamStart(null, fajr), isNull);
    expect(PrayerCalculator.qiyamStart(fajr, maghrib), isNull);
    expect(PrayerCalculator.qiyamStart(fajr, fajr), isNull);
  });

  test('SC-006: five places and dates match Maghrib + ⅔ × (next Fajr − '
      'Maghrib) within one minute, after offsets', () {
    final cases = [
      (cairoResult(), DateTime.utc(2026, 10, 29), const <PrayerKind, int>{}),
      (londonResult(), DateTime.utc(2026, 3, 28), const <PrayerKind, int>{}),
      (cairoResult(), DateTime.utc(2026, 3, 15), {PrayerKind.maghrib: 3}),
      (londonResult(), DateTime.utc(2026, 12, 21), {PrayerKind.fajr: -10}),
      (cairoResult(), DateTime.utc(2026, 6, 21), const <PrayerKind, int>{}),
    ];
    for (final (result, day, offsets) in cases) {
      final p = place(
        result,
        calculation: CalculationSettings(offsets: offsets),
      );
      final today = calculator.schedule(p, day);
      final tomorrow = calculator.schedule(p, day.add(const Duration(days: 1)));
      final maghrib = today.event(PrayerKind.maghrib).atUtc!;
      final fajr = tomorrow.event(PrayerKind.fajr).atUtc!;
      final expected = maghrib.add(fajr.difference(maghrib) * 2 ~/ 3);
      expect(
        today.qiyamUtc!.difference(expected).inSeconds.abs(),
        lessThanOrEqualTo(60),
        reason: '${result['city']} $day',
      );
    }
  });

  test('no Qiyam when a boundary is unavailable, with a reason', () {
    final polar = Place(
      id: 'tromso',
      name: 'Tromsø',
      latitude: 69.65,
      longitude: 18.96,
      timezoneId: 'Europe/Oslo',
      source: PlaceSource.search,
      calculation: CalculationSettings(),
    );
    final s = calculator.schedule(polar, DateTime.utc(2026, 6, 21));
    expect(s.qiyamUtc, isNull);
    expect(s.qiyamUnavailableReason, isNotNull);
  });
}
