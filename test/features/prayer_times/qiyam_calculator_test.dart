import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/prayer_times/prayer_calculator.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';

void main() {
  test('last third uses elapsed UTC time, rounds once, and rejects invalid boundaries', () {
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
  test(
    'Cairo DST night retains actual following Fajr and local delivery date',
    () {
      final calculator = PrayerCalculator(
        jsonDecode(
          File('assets/prayer/ramadan_intervals.json').readAsStringSync(),
        ) as Map<String, dynamic>,
      );
      final place = SavedLocation(
        id: 'cairo',
        label: 'Cairo',
        latitude: 30.0444,
        longitude: 31.2357,
        timezoneId: 'Africa/Cairo',
        source: LocationSource.manual,
        confirmedAtUtc: DateTime.utc(2026),
      );
      final schedule = calculator.schedule(place, DateTime.utc(2026, 10, 29));
      final maghrib = schedule.events
          .firstWhere((event) => event.kind == PrayerKind.maghrib)
          .dueAtUtc!;
      expect(
        schedule.qiyamUtc,
        PrayerCalculator.qiyamStart(maghrib, schedule.followingFajrUtc),
      );
      expect(schedule.qiyamUtc!.isAfter(maghrib), true);
      expect(schedule.qiyamUtc!.isBefore(schedule.followingFajrUtc!), true);
    },
  );
}
