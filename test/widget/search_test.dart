// US6 search (quickstart scenario 12).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/search/search_index.dart';
import 'package:mathani/shared/mathani_icons.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';

void main() {
  late ReaderController reader;
  final key = GlobalKey();

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('search without diacritics, count, highlight, open; no-results message',
      (tester) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });

    // Search speed on the full corpus (SC-006 budget is 1 s on the reference phone).
    final index = (await tester.runAsync(() => SearchIndex.load(reader.quran)))!;
    final watch = Stopwatch()..start();
    final direct = index.search('الرحمن الرحيم');
    watch.stop();
    expect(direct.hits, isNotEmpty);
    expect(direct.hits.first.ayah.ref, const AyahRef(1, 1));
    expect(watch.elapsedMilliseconds, lessThan(300));

    reader.updatePreferences(reader.preferences.copyWith(language: LanguagePref.ar));
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(key: key, child: MathaniApp(controller: reader)));
    await settle(tester);

    await tester.tap(find.byIcon(MathaniIcons.search));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'الرحمن الرحيم');
    await settle(tester);
    expect(find.text('٦ آيات'), findsOneWidget); // result summary
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/screenshots').createSync(recursive: true);
      File('build/screenshots/search_ar.png').writeAsBytesSync(png!.buffer.asUint8List());
    });

    await tester.tap(find.textContaining('سورة الفاتحة').first);
    await settle(tester);
    expect(reader.anchor, const AyahRef(1, 1));

    await tester.tap(find.byIcon(MathaniIcons.search));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'زززز');
    await settle(tester);
    expect(find.text('لا توجد نتائج.'), findsOneWidget);
  });

  /// Opens the reader on a phone-sized screen and goes to Search.
  Future<void> openSearch(WidgetTester tester, {LanguagePref language = LanguagePref.ar}) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    reader.updatePreferences(reader.preferences.copyWith(language: language));
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MathaniApp(controller: reader));
    await settle(tester);
    await tester.tap(find.byIcon(MathaniIcons.search));
    await settle(tester);
  }

  final rows = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('search-row-'));

  /// Checks that every built result row shows the words of the ayah named in its title, and
  /// returns how many rows had their text loaded.
  Future<int> expectRowsMatchTitles(WidgetTester tester, String query) async {
    final title = RegExp(r'^سورة (.+)، الآية ([٠-٩]+)$');
    var checked = 0;
    for (final row in rows.evaluate().toList()) {
      final texts = find
          .descendant(of: find.byWidget(row.widget), matching: find.byType(RichText))
          .evaluate()
          .map((e) => (e.widget as RichText).text.toPlainText())
          .toList();
      final m = title.firstMatch(texts.first);
      expect(m, isNotNull, reason: 'row title "${texts.first}" for «$query»');
      if (texts.length < 2) continue; // still loading: placeholder only
      final surah = reader.quran.surahList.indexWhere((s) => s.nameAr == m!.group(1)) + 1;
      final ayah = int.parse(String.fromCharCodes(m!.group(2)!.runes.map((c) => c - 0x0660 + 0x30)));
      final words = (await tester.runAsync(() => reader.quran.wordsOf(AyahRef(surah, ayah))))!;
      final expected = [for (final w in words) if (!w.isAyahEnd) '${w.text} '].join();
      expect(texts[1], expected, reason: 'row «${texts.first}» after searching «$query»');
      checked++;
    }
    return checked;
  }

  testWidgets('rows follow the query: each row shows the ayah in its title', (tester) async {
    await openSearch(tester);
    final field = find.byType(TextField);

    Future<void> search(String query) async {
      await tester.enterText(field, query);
      await settle(tester, 4);
      var checked = await expectRowsMatchTitles(tester, query);
      // Under load (the full suite), row text can take a few more rounds to load.
      for (var i = 0; i < 10 && checked == 0 && rows.evaluate().isNotEmpty; i++) {
        await settle(tester, 1);
        checked = await expectRowsMatchTitles(tester, query);
      }
      if (rows.evaluate().isNotEmpty) expect(checked, greaterThan(0), reason: '«$query»');
    }

    Future<void> typeLetters(String text) async {
      for (var i = 1; i <= text.length; i++) {
        await search(text.substring(0, i));
      }
    }

    var changes = 0;
    // The reported case: the only row must be Al-Ikhlas 112:1, not the basmala of 1:1.
    await search('الرحمن الرحيم');
    await search('قل هو الله احد');
    changes += 2;
    expect(rows, findsOneWidget);
    expect(find.text('سورة الإخلاص، الآية ١'), findsOneWidget);
    expect(find.textContaining('قُلْ', findRichText: true), findsWidgets);

    await typeLetters('الرحمن');
    await search('الله');
    await search('الله ال');
    await search('الله الص');
    changes += 6 + 3;
    await tester.tap(find.byIcon(MathaniIcons.clear));
    await settle(tester, 4);
    expect(rows, findsNothing);
    await typeLetters('من');
    await typeLetters('يا ايها الذين امنوا');
    await typeLetters('ذلك الكتاب');
    await typeLetters('الصلاة');
    await typeLetters('قل اعوذ');
    changes += 2 + 19 + 10 + 6 + 7;
    expect(changes, greaterThanOrEqualTo(50));
  });

  testWidgets('summary states ayat and occurrences, in Arabic and English', (tester) async {
    await openSearch(tester);
    final field = find.byType(TextField);
    String summary() => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((s) => RegExp(r'آية|آيات|آيتان|ayah|ayat|No results|لا توجد').hasMatch(s) &&
            !s.startsWith('سورة') && !s.startsWith('Surah'));

    await tester.enterText(field, 'الرحمن الرحيم');
    await settle(tester);
    expect(summary(), '٦ آيات');
    await tester.enterText(field, 'الله');
    await settle(tester);
    expect(summary(), matches(RegExp(r'^[٠-٩]+ (موضعًا|موضع|مواضع) في [٠-٩]+ (آية|آيات)$')));
    await tester.enterText(field, 'زززز');
    await settle(tester);
    expect(summary(), 'لا توجد نتائج.');

    reader.updatePreferences(reader.preferences.copyWith(language: LanguagePref.en));
    await settle(tester);
    await tester.enterText(field, 'الرحمن الرحيم');
    await settle(tester);
    expect(summary(), '6 ayat');
    await tester.enterText(field, 'الله');
    await settle(tester);
    expect(summary(), matches(RegExp(r'^[\d,]+ occurrences in [\d,]+ ayat$')));
    await tester.enterText(field, 'زززز');
    await settle(tester);
    expect(summary(), 'No results.');
  });

  testWidgets('tapping a row opens the ayah it shows; older queries never win', (tester) async {
    await openSearch(tester);
    final field = find.byType(TextField);

    // Typed quickly: the newer query must replace the older one, with no row from «الرحمن».
    await tester.enterText(field, 'الرحمن');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.enterText(field, 'قل هو الله احد');
    await settle(tester);
    expect(rows, findsOneWidget);
    expect(find.text('سورة الإخلاص، الآية ١'), findsOneWidget);

    await tester.enterText(field, 'الرحمن الرحيم');
    await settle(tester);
    await tester.enterText(field, 'قل هو الله احد');
    await settle(tester);
    await tester.tap(rows);
    await settle(tester);
    expect(reader.anchor, const AyahRef(112, 1));
  });
}
