// specs/010 US1 and US4: the «عرض المتشابه» overlay (contracts/mutashabihat-ui.md › Overlay), with
// the quickstart groups (test/fixtures/mutashabihat/quickstart.md).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/mutashabihat/similar_sheet.dart';
import 'package:mathani/features/reader/mushaf_page_renderer.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';

void main() {
  late ReaderController reader;

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader(similar: quickstartMutashabihat());
    });
    reader.updatePreferences(reader.preferences.copyWith(language: LanguagePref.ar));
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MathaniApp(controller: reader));
    await settle(tester);
  }

  Future<void> open(WidgetTester tester, AyahRef ref) async {
    final context = tester.element(find.byType(MushafPageRenderer).first);
    showSimilarSheet(context, ref);
    await settle(tester);
  }

  Finder scrollableOf(String part) => find.descendant(
      of: find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key! as ValueKey).value}'.contains(part)),
      matching: find.byType(Scrollable)).first;

  testWidgets('the pressed ayah first, then the others; the explanation below', (tester) async {
    await pumpApp(tester);
    await open(tester, const AyahRef(7, 19));

    expect(find.text('المتشابه'), findsOneWidget);
    expect(find.text('هذه الآية'), findsOneWidget);
    final pressed = tester.getTopLeft(find.text('سورة الأعراف، الآية ١٩'));
    final other = tester.getTopLeft(find.text('سورة البقرة، الآية ٣٥'));
    expect(pressed.dy, lessThan(other.dy));
    expect(find.text('نص تجريبي: الفقرة الأولى من شرح المجموعة الأولى.'), findsOneWidget);
    expect(find.text('نص تجريبي: الفقرة الثانية من شرح المجموعة الأولى.'), findsOneWidget);
    expect(reader.selected, const AyahRef(7, 19));

    // Two thirds for the ayat, one third for the explanation.
    final ayat = tester.getSize(scrollableOf('ayat')).height;
    final explanation = tester.getSize(scrollableOf('explanation')).height;
    expect(ayat / explanation, closeTo(2, 0.05));
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('tapping the pressed ayah does nothing; ✕ closes and clears the selection',
      (tester) async {
    await pumpApp(tester);
    await open(tester, const AyahRef(7, 19));
    await tester.tap(find.text('هذه الآية'));
    await settle(tester);
    expect(find.text('هذه الآية'), findsOneWidget);

    await tester.tap(find.byTooltip('إغلاق'));
    await settle(tester);
    expect(find.text('المتشابه'), findsNothing);
    expect(reader.selected, isNull);
  });

  testWidgets('tapping another ayah opens it in the Mushaf, highlighted', (tester) async {
    await pumpApp(tester);
    await open(tester, const AyahRef(7, 19));
    await tester.tap(find.text('سورة البقرة، الآية ٣٥'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(reader.highlighted, const AyahRef(2, 35));
    expect(reader.page, reader.quran.pageOf(const AyahRef(2, 35)));
    await settle(tester);
    expect(find.text('هذه الآية'), findsNothing);
    await tester.pump(const Duration(seconds: 2)); // the highlight ends
    expect(reader.highlighted, isNull);
  });

  testWidgets('a large group scrolls on its own; the explanation stays put', (tester) async {
    await pumpApp(tester);
    await open(tester, const AyahRef(55, 13));
    final last = find.text('سورة الرحمن، الآية ٧٧');
    expect(last, findsNothing);
    await tester.scrollUntilVisible(last, 400, scrollable: scrollableOf('ayat'));
    await settle(tester, 2);
    expect(last, findsOneWidget);
    final explanation = tester.state<ScrollableState>(scrollableOf('explanation'));
    expect(explanation.position.pixels, 0);
  });

  testWidgets('a very long ayah is reachable in full, also at double text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    await open(tester, const AyahRef(2, 282));
    expect(tester.takeException(), isNull);
    final next = find.text('سورة البقرة، الآية ٢٨٣');
    await tester.scrollUntilVisible(next, 400, scrollable: scrollableOf('ayat'));
    await settle(tester, 2);
    expect(next, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an ayah in two groups switches between them (US4)', (tester) async {
    await pumpApp(tester);
    await open(tester, const AyahRef(2, 35));
    expect(find.byType(ChoiceChip), findsNWidgets(2));
    expect(find.text('سورة الأعراف، الآية ١٩'), findsOneWidget);
    expect(find.text('نص تجريبي: الفقرة الأولى من شرح المجموعة الأولى.'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '٢'));
    await settle(tester);
    expect(find.text('سورة الأعراف، الآية ١٩'), findsNothing);
    expect(find.text('سورة طه، الآية ١١٧'), findsOneWidget);
    expect(find.text('سورة طه، الآية ١٢٠'), findsOneWidget);
    expect(find.text('نص تجريبي: شرح المجموعة الثانية لآية البقرة ٣٥.'), findsOneWidget);
    expect(tester.state<ScrollableState>(scrollableOf('ayat')).position.pixels, 0);
    expect(tester.state<ScrollableState>(scrollableOf('explanation')).position.pixels, 0);

    await tester.tap(find.byTooltip('إغلاق'));
    await settle(tester);
    await open(tester, const AyahRef(20, 117));
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('سورة البقرة، الآية ٣٥'), findsOneWidget);
  });
}
