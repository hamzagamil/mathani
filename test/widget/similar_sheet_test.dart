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

  Future<void> pumpApp(WidgetTester tester, {LanguagePref language = LanguagePref.ar}) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader(similar: quickstartMutashabihat());
    });
    reader.updatePreferences(reader.preferences.copyWith(language: language));
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

    await tester.tap(find.byType(ChoiceChip).at(1));
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

  group('tabs named by the shared wording (specs/013 US3)', () {
    const pressed = AyahRef(2, 35);

    Future<List<String>> labelsOf(WidgetTester tester, String Function(int) number) async =>
        (await tester.runAsync(() => similarTabLabels(
            reader.quran, pressed, reader.similar.groupsOf(pressed), number)))!;

    Text textOf(WidgetTester tester, int chip) => tester.widget<Text>(find
        .descendant(of: find.byType(ChoiceChip).at(chip), matching: find.byType(Text))
        .first);

    testWidgets('each tab shows its wording on one line, the first selected', (tester) async {
      await pumpApp(tester);
      final labels = await labelsOf(tester, (n) => '#$n');
      expect(labels, hasLength(2));
      expect(labels.any((l) => l.startsWith('#')), isFalse, reason: 'wording, not numbers');
      expect(labels.toSet(), hasLength(2));

      await open(tester, pressed);
      final sheet = tester.getRect(find.byType(SimilarSheet));
      for (var i = 0; i < 2; i++) {
        final text = textOf(tester, i);
        expect(text.data, labels[i]);
        expect(text.maxLines, 1);
        expect(text.textDirection, TextDirection.rtl);
        final chip = tester.getRect(find.byType(ChoiceChip).at(i));
        expect(chip.left, greaterThanOrEqualTo(sheet.left));
        expect(chip.right, lessThanOrEqualTo(sheet.right));
        expect(chip.height, greaterThanOrEqualTo(48));
        expect(tester.widget<ChoiceChip>(find.byType(ChoiceChip).at(i)).selected, i == 0);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('screen readers hear the wording and the selected tab', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);
      final labels = await labelsOf(tester, (n) => '#$n');
      await open(tester, pressed);
      for (var i = 0; i < 2; i++) {
        final node = tester.getSemantics(find.byType(ChoiceChip).at(i));
        expect(node.label, labels[i]);
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.flagsCollection.isSelected.toBoolOrNull(), i == 0);
      }
      handle.dispose();
    });

    testWidgets('the wording stays right-to-left in the English interface', (tester) async {
      await pumpApp(tester, language: LanguagePref.en);
      await open(tester, pressed);
      expect(textOf(tester, 0).textDirection, TextDirection.rtl);
      expect(textOf(tester, 1).textDirection, TextDirection.rtl);
    });

    testWidgets('many long tabs wrap; every one can be tapped; a number tab is «Group n»',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);
      final groups = reader.similar.groupsOf(pressed);
      final six = [for (var i = 0; i < 6; i++) groups[i % 2]];
      const long = 'وَقُلْنَا يَـٰٓـَٔادَمُ ٱسْكُنْ أَنتَ وَزَوْجُكَ ٱلْجَنَّةَ…';
      final labels = [for (var i = 0; i < 5; i++) '$long (${i + 1})', '٦'];
      showModalBottomSheet<void>(
        context: tester.element(find.byType(MushafPageRenderer).first),
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.92,
          child: SimilarSheet(ayah: pressed, groups: six, labels: labels),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(ChoiceChip), findsNWidgets(6));
      final tops = {
        for (var i = 0; i < 6; i++) tester.getRect(find.byType(ChoiceChip).at(i)).top,
      };
      expect(tops.length, greaterThan(1), reason: 'more than one row');
      for (var i = 5; i >= 0; i--) {
        await tester.tap(find.byType(ChoiceChip).at(i));
        await settle(tester, 1);
        expect(tester.widget<ChoiceChip>(find.byType(ChoiceChip).at(i)).selected, isTrue);
      }
      expect(tester.getSemantics(find.byType(ChoiceChip).at(5)).label, 'المجموعة ٦');
      handle.dispose();
      await tester.tap(find.byTooltip('إغلاق'));
      await settle(tester);
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
