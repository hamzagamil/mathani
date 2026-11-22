import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/l10n/app_localizations.dart';
import 'package:mathani/features/widgets/widget_snapshot.dart';

import '../../support/prayer_fakes.dart';

// specs/017 data-model.md › QuranBlock, contracts/widget-surfaces.md › Quran widget, FR-003.
void main() {
  final en = english();
  final ar = lookupAppLocalizations(const Locale('ar'));

  KhatmaInput khatma({
    bool paused = false,
    bool todayRead = false,
    int read = 248,
    String? from = 'Al-Baqarah 142',
    String? to = 'Al-Baqarah 202',
  }) => KhatmaInput(
    paused: paused,
    todayRead: todayRead,
    pagesRead: read,
    pagesTotal: 604,
    wirdFrom: from,
    wirdTo: to,
  );

  test('never read: start, opening page 1', () {
    final b = buildQuranBlock(const QuranInput(page: 1), en);
    expect(b.mode, QuranMode.start);
    expect(b.title, en.widgetStartReading);
    expect(b.link, 'mathani-widget://mushaf/1');
    expect(b.progress, isNull);
  });

  test('no khatma: continue at the last page', () {
    final b = buildQuranBlock(
      const QuranInput(page: 23, surahName: 'Al-Baqarah', juz: 2),
      en,
    );
    expect(b.mode, QuranMode.continueReading);
    expect(b.toJson()['mode'], 'continue');
    expect(b.line1, 'Al-Baqarah');
    expect(b.line2, 'Page 23 · Juz 2');
    expect(b.link, 'mathani-widget://mushaf/23');
  });

  test('a wird waiting: from and to, opening the khatma place', () {
    final b = buildQuranBlock(QuranInput(page: 40, khatma: khatma()), en);
    expect(b.mode, QuranMode.wird);
    expect(b.title, en.khatmaTodaysWird);
    expect(b.line1, 'From Al-Baqarah 142');
    expect(b.line2, 'to Al-Baqarah 202');
    expect(b.link, 'mathani-widget://khatma/read');
    expect(b.progress!.percent, 41);
    expect(b.progress!.text, '41% · 248 of 604 pages');
  });

  test('today\'s wird read: done, opening the Khatma screen', () {
    final b = buildQuranBlock(QuranInput(page: 40, khatma: khatma(todayRead: true)), en);
    expect(b.mode, QuranMode.wirdDone);
    expect(b.title, en.khatmaTodayDone);
    expect(b.link, 'mathani-widget://khatma');
    expect(b.progress!.todayRead, isTrue);
  });

  test('paused: continue reading, with the progress marked paused', () {
    final b = buildQuranBlock(
      QuranInput(page: 40, surahName: 'Al-Imran', juz: 3, khatma: khatma(paused: true)),
      en,
    );
    expect(b.mode, QuranMode.continueReading);
    expect(b.progress!.paused, isTrue);
    expect(b.progress!.text, endsWith(en.widgetPaused));
    expect(b.link, 'mathani-widget://mushaf/40');
  });

  test('percent stays within 0–100', () {
    expect(buildQuranBlock(QuranInput(page: 2, khatma: khatma(read: 0)), en).progress!.percent, 0);
    expect(buildQuranBlock(QuranInput(page: 2, khatma: khatma(read: 900)), en).progress!.percent, 100);
  });

  test('Arabic digits in the place and the progress', () {
    final b = buildQuranBlock(QuranInput(page: 40, khatma: khatma()), ar);
    expect(b.progress!.text, contains('٤١'));
    final c = buildQuranBlock(const QuranInput(page: 23, surahName: 'البقرة', juz: 2), ar);
    expect(c.line2, contains('٢٣'));
  });

  test('the watch copy has khatma progress but not the reading place (FR-003)', () {
    final snapshot = buildWidgetSnapshot(
      l10n: en,
      nowUtc: DateTime.utc(2026, 11, 22),
      prayer: null,
      quran: QuranInput(page: 40, surahName: 'Al-Baqarah', juz: 2, khatma: khatma()),
    );
    final watch = jsonDecode(snapshot.encodeWatch()) as Map<String, dynamic>;
    expect(watch.containsKey('quran'), isFalse);
    expect(watch['prayer'], isNull);
    expect(watch['khatma'], {
      'percent': 41,
      'todayRead': false,
      'paused': false,
      'text': '41% · 248 of 604 pages',
    });
    expect(snapshot.encodeWatch(), isNot(contains('Al-Baqarah')));
    expect((watch['labels'] as Map)['setPlaceWatch'], en.widgetSetPlaceWatch);
  });

  test('labels split the countdown phrase around the timer', () {
    final labels = WidgetLabels.of(en);
    expect(labels.inPrefix, 'in ');
    expect(labels.inSuffix, '');
    expect(labels.a11yNext, 'Next prayer: {name} at {time}');
    expect(WidgetLabels.of(ar).inPrefix, 'بعد ');
  });
}
