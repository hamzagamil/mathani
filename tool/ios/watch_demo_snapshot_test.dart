// Writes demo watch copies for the Apple Watch store screenshots (specs/017 T064), with real
// prayer times from now on, in Arabic and English. The city is the first in the list where it is
// day now (between Fajr and Isha), so the screenshot shows a prayer of the day as the next one.
// Run by .github/workflows/watch-screenshots.yml:
//   WATCH_DEMO_OUT=<dir> flutter test tool/ios/watch_demo_snapshot_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mathani/app/l10n/app_localizations.dart';
import 'package:mathani/features/prayer_times/prayer_calculator.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/widgets/widget_snapshot.dart';

/// (English, Arabic, latitude, longitude, zone, country)
const _cities = [
  ('Makkah', 'مكة المكرمة', 21.4225, 39.8262, 'Asia/Riyadh', 'SA'),
  ('Cairo', 'القاهرة', 30.0444, 31.2357, 'Africa/Cairo', 'EG'),
  ('Kuala Lumpur', 'كوالالمبور', 3.139, 101.6869, 'Asia/Kuala_Lumpur', 'MY'),
  ('London', 'لندن', 51.5074, -0.1278, 'Europe/London', 'GB'),
  ('New York', 'نيويورك', 40.7128, -74.006, 'America/New_York', 'US'),
  ('Los Angeles', 'لوس أنجلوس', 34.0522, -118.2437, 'America/Los_Angeles', 'US'),
];

void main() {
  test('demo watch copies', () async {
    final out = Platform.environment['WATCH_DEMO_OUT'] ?? 'build/watch_demo';
    Directory(out).createSync(recursive: true);
    final calculator = PrayerCalculator(
      jsonDecode(File('assets/prayer/ramadan_intervals.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final now = DateTime.now().toUtc();

    Place place((String, String, double, double, String, String) c, String lang) => Place.fromResult({
      'city': lang == 'ar' ? c.$2 : c.$1,
      'region': '',
      'countryCode': c.$6,
      'latitude': c.$3,
      'longitude': c.$4,
      'timezoneId': c.$5,
      'source': 'search',
    }, id: 'demo');

    // The first city where the next prayer is Dhuhr, Asr, Maghrib or Isha of today.
    final english = lookupAppLocalizations(const Locale('en'));
    await initializeDateFormatting('en');
    var city = _cities.first;
    for (final c in _cities) {
      final block = buildPrayerBlock(place: place(c, 'en'), calculator: calculator, l10n: english, nowUtc: now);
      final next = block?.nextAfter(now);
      if (next != null && next.kind != PrayerKind.fajr && block!.entries.indexOf(next) < 5) {
        city = c;
        break;
      }
    }

    for (final lang in ['ar', 'en']) {
      await initializeDateFormatting(lang);
      final l10n = lookupAppLocalizations(Locale(lang));
      final where = place(city, lang);
      final snapshot = buildWidgetSnapshot(
        l10n: l10n,
        nowUtc: now,
        prayer: buildPrayerBlock(place: where, calculator: calculator, l10n: l10n, nowUtc: now),
        quran: const QuranInput(
          page: 40,
          khatma: KhatmaInput(paused: false, todayRead: true, pagesRead: 248, pagesTotal: 604),
        ),
      );
      File('$out/watch_$lang.json').writeAsStringSync(snapshot.encodeWatch());
    }
    stdout.writeln('Demo city: ${city.$1}');
  });
}
