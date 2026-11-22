import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/l10n/app_localizations.dart';
import 'package:mathani/features/widgets/widget_snapshot.dart';
import 'package:mathani/features/widgets/widget_sync.dart';

import '../../support/prayer_fakes.dart';

// specs/017 research R9: debounce, only real changes are sent, flush on pause and resume.
void main() {
  testWidgets('debounces changes and sends only what the widgets show', (tester) async {
    final changes = ValueNotifier(0);
    var page = 10;
    var language = const Locale('en');
    final sent = <Map<String, dynamic>>[];
    var clock = DateTime.utc(2026, 11, 22, 8);
    final sync = WidgetSync(
      listenables: [changes],
      l10n: () => lookupAppLocalizations(language),
      prayerBlock: (_, _) async => null,
      quranInput: (_) => QuranInput(page: page, surahName: 'Al-Baqarah', juz: 2),
      send: (snapshot, watch) async => sent.add(jsonDecode(snapshot) as Map<String, dynamic>),
      clock: () => clock,
    );
    addTearDown(sync.dispose);

    await tester.runAsync(() async {
      sync.start();
      await sync.flush();
    });
    expect(sent, hasLength(1));
    expect((sent.single['quran'] as Map)['link'], 'mathani-widget://mushaf/10');

    // Several quick changes: one send after the debounce.
    page = 11;
    changes.value++;
    page = 12;
    changes.value++;
    await tester.pump(const Duration(seconds: 1));
    expect(sent, hasLength(1));
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    expect(sent, hasLength(2));
    expect((sent.last['quran'] as Map)['link'], 'mathani-widget://mushaf/12');

    // A change that shows nothing new (only the time moved): nothing sent.
    clock = clock.add(const Duration(minutes: 5));
    await tester.runAsync(sync.flush);
    expect(sent, hasLength(2));

    // A language change is sent within the debounce (FR-005).
    language = const Locale('ar');
    changes.value++;
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    expect(sent, hasLength(3));
    expect(sent.last['lang'], 'ar');
  });

  testWidgets('pausing the app sends a pending change at once', (tester) async {
    final changes = ValueNotifier(0);
    var page = 3;
    final sent = <String>[];
    final sync = WidgetSync(
      listenables: [changes],
      l10n: english,
      prayerBlock: (_, _) async => null,
      quranInput: (_) => QuranInput(page: page),
      send: (snapshot, _) async => sent.add(snapshot),
    );
    addTearDown(sync.dispose);
    await tester.runAsync(() async {
      sync.start();
      await sync.flush();
    });
    page = 4;
    changes.value++;
    sync.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    expect(sent, hasLength(2));
    expect(sent.last, contains('mathani-widget://mushaf/4'));
  });

  testWidgets('a failing build never reaches the reader', (tester) async {
    final sync = WidgetSync(
      listenables: const [],
      l10n: english,
      prayerBlock: (_, _) async => throw StateError('no calculator'),
      quranInput: (_) => const QuranInput(page: 1),
      send: (_, _) async => fail('nothing to send'),
    );
    addTearDown(sync.dispose);
    await tester.runAsync(sync.flush);
  });

  test('widgets are reported at most once a day (SC-007)', () async {
    String? stored;
    final reports = <List<String>>[];
    var clock = DateTime(2026, 11, 22, 9);
    Future<void> run() => reportWidgetsOncePerDay(
      placed: () async => ['prayer'],
      report: reports.add,
      readDay: () async => stored,
      writeDay: (day) async => stored = day,
      clock: () => clock,
    );
    await run();
    await run();
    expect(reports, [['prayer']]);
    expect(stored, '2026-11-22');
    clock = DateTime(2026, 11, 23, 0, 5);
    await run();
    expect(reports, hasLength(2));
  });
}
