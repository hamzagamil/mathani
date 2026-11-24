// Writes demo watch copies for the Apple Watch store screenshots (specs/017 T064), with real
// prayer times for Makkah from now on, in Arabic and English. Run by
// .github/workflows/watch-screenshots.yml:
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

void main() {
  test('demo watch copies', () async {
    final out = Platform.environment['WATCH_DEMO_OUT'] ?? 'build/watch_demo';
    Directory(out).createSync(recursive: true);
    final calculator = PrayerCalculator(
      jsonDecode(File('assets/prayer/ramadan_intervals.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final now = DateTime.now().toUtc();
    for (final lang in ['ar', 'en']) {
      await initializeDateFormatting(lang);
      final l10n = lookupAppLocalizations(Locale(lang));
      final makkah = Place.fromResult({
        'city': lang == 'ar' ? 'مكة المكرمة' : 'Makkah',
        'region': '',
        'countryCode': 'SA',
        'latitude': 21.4225,
        'longitude': 39.8262,
        'timezoneId': 'Asia/Riyadh',
        'source': 'search',
      }, id: 'demo');
      final snapshot = buildWidgetSnapshot(
        l10n: l10n,
        nowUtc: now,
        prayer: buildPrayerBlock(place: makkah, calculator: calculator, l10n: l10n, nowUtc: now),
        quran: const QuranInput(
          page: 40,
          khatma: KhatmaInput(paused: false, todayRead: true, pagesRead: 248, pagesTotal: 604),
        ),
      );
      File('$out/watch_$lang.json').writeAsStringSync(snapshot.encodeWatch());
    }
  });
}
