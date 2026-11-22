import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:mathani/app/l10n/app_localizations.dart';
import 'package:mathani/features/prayer_times/prayer_calculator.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_time_zones.dart';
import 'package:mathani/features/widgets/widget_snapshot.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../support/prayer_fakes.dart';

// specs/017 data-model.md › PrayerBlock, FR-008, FR-011, SC-001.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('ar');
  });
  final calculator = testCalculator();
  final arabic = lookupAppLocalizations(const Locale('ar'));
  final now = DateTime.utc(2026, 11, 22, 10); // a Sunday

  PrayerBlock build(Place where, {AppLocalizations? l10n, DateTime? at}) => buildPrayerBlock(
    place: where,
    calculator: calculator,
    l10n: l10n ?? english(),
    nowUtc: at ?? now,
  )!;

  test('Cairo: 40 entries over 8 days, ascending and unique, never sunrise', () {
    final block = build(place(cairoResult()));
    expect(block.entries, hasLength(40));
    expect(block.days, hasLength(PrayerBlock.dayCount));
    expect(block.entries.any((e) => e.kind == PrayerKind.sunrise), isFalse);
    for (var i = 1; i < block.entries.length; i++) {
      expect(block.entries[i].atUtc.isAfter(block.entries[i - 1].atUtc), isTrue);
    }
    expect(
      block.validUntilUtc,
      block.entries.last.atUtc.add(const Duration(minutes: 1)),
    );
    // Today's earlier prayers stay, for the medium widget's full day.
    expect(block.entries.first.kind, PrayerKind.fajr);
    expect(block.days.first.label, english().prayerToday);
    // 7 more days after today (FR-011).
    expect(
      block.validUntilUtc.difference(now),
      greaterThan(const Duration(days: 7)),
    );
  });

  test('names and times are those of the Prayer Times screen', () {
    final cairo = place(cairoResult());
    final block = build(cairo);
    final zone = prayerTimeZone(cairo.timezoneId);
    final today = calculator.schedule(cairo, PrayerCalculator.localDay(cairo, now));
    for (final (i, kind) in widgetPrayers.indexed) {
      final at = today.event(kind).atUtc!;
      expect(block.entries[i].atUtc, at);
      expect(
        block.entries[i].time,
        DateFormat.jm('en').format(tz.TZDateTime.from(at, zone)),
      );
    }
    expect(block.entries[2].name, english().prayerAsr);
    // The next prayer is the screen's next prayer.
    expect(block.nextAfter(now)!.atUtc, calculator.nextPrayer(cairo, now)!.atUtc);
  });

  test('Friday Dhuhr is Jumu\'ah (specs/015)', () {
    final block = build(place(cairoResult()));
    final friday = block.entries.where(
      (e) =>
          e.kind == PrayerKind.dhuhr &&
          tz.TZDateTime.from(e.atUtc, prayerTimeZone('Africa/Cairo')).weekday ==
              DateTime.friday,
    );
    expect(friday, isNotEmpty);
    expect(friday.every((e) => e.name == english().prayerJumuah), isTrue);
  });

  test('Arabic uses the app\'s language and digits', () {
    final block = build(place(cairoResult()), l10n: arabic);
    expect(block.entries.first.name, arabic.prayerFajr);
    expect(block.days.first.label, arabic.prayerToday);
    expect(
      block.entries.first.time,
      DateFormat.jm('ar').format(
        tz.TZDateTime.from(block.entries.first.atUtc, prayerTimeZone('Africa/Cairo')),
      ),
    );
  });

  test('London across the clock change keeps one entry per prayer, in order', () {
    final block = build(place(londonResult()), at: DateTime.utc(2026, 3, 26, 12));
    expect(block.entries, hasLength(40));
    for (var i = 1; i < block.entries.length; i++) {
      expect(block.entries[i].atUtc.isAfter(block.entries[i - 1].atUtc), isTrue);
    }
    // The day starts move from midnight GMT to midnight BST.
    final starts = block.days.map((d) => d.startUtc.hour).toSet();
    expect(starts, containsAll([0, 23]));
  });

  test('no place: no block', () {
    expect(
      buildPrayerBlock(place: null, calculator: calculator, l10n: english(), nowUtc: now),
      isNull,
    );
  });

  test('the snapshot JSON is within 16 KB and follows the contract', () {
    final snapshot = buildWidgetSnapshot(
      l10n: arabic,
      nowUtc: now,
      prayer: build(place(cairoResult()), l10n: arabic),
      quran: const QuranInput(page: 23, surahName: 'البقرة', juz: 2),
    );
    final text = snapshot.encode();
    expect(utf8.encode(text).length, lessThanOrEqualTo(WidgetSnapshot.maxBytes));
    final json = jsonDecode(text) as Map<String, dynamic>;
    expect(json['v'], 1);
    expect(json['lang'], 'ar');
    expect(json['rtl'], isTrue);
    final prayer = json['prayer'] as Map<String, dynamic>;
    expect(prayer['place'], 'Cairo');
    expect((prayer['entries'] as List).first, containsPair('kind', 'fajr'));
    expect(utf8.encode(snapshot.encodeWatch()).length, lessThanOrEqualTo(WidgetSnapshot.maxBytes));
  });
}
