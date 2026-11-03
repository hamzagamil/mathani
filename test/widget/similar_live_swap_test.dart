// specs/011 FR-015: a downloaded version takes effect at once. The page on screen recolours,
// in both layouts, without a restart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/app/theme/app_theme.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/mutashabihat/mutashabihat_content.dart';
import 'package:mathani/features/reader/flowing_view.dart';
import 'package:mathani/features/reader/mushaf_page_renderer.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';

void main() {
  late ReaderController reader;
  final colors = MathaniColors.forBrightness(Brightness.light);
  const ayah = AyahRef(2, 35);

  Future<void> settle(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> pumpApp(WidgetTester tester, ReadingLayout layout) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    reader.updatePreferences(reader.preferences.copyWith(language: LanguagePref.ar, layout: layout));
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MathaniApp(controller: reader));
    await settle(tester);
    reader.jumpTo(ayah, highlight: false);
    await settle(tester);
  }

  final linked = parseMutashabihat('<!-- version: 3 -->\n## 2:35 7:19\nشرح').$1;

  testWidgets('Mushaf: the page recolours when the content is replaced', (tester) async {
    await pumpApp(tester, ReadingLayout.mushaf);
    final words = [
      for (final line in (await tester.runAsync(() => reader.quran.page(reader.page)))!.lines)
        for (final w in line.words)
          if (w.ref == ayah) w,
    ];
    Color? colour() => tester
        .renderObject<RenderMushafPage>(find.byType(MushafPageRenderer).first)
        .colorOfWord(words.first.id);

    expect(colour(), isNot(colors.similar));
    reader.replaceSimilar(linked);
    await settle(tester, 2);
    expect(colour(), colors.similar);
    expect(reader.similar.version, 3);
    reader.replaceSimilar(Mutashabihat.empty);
    await settle(tester, 2);
    expect(colour(), isNot(colors.similar));
  });

  testWidgets('Flowing: the text recolours when the content is replaced', (tester) async {
    await pumpApp(tester, ReadingLayout.flowing);
    final text = flowingAyahText((await tester.runAsync(() => reader.quran.wordsOf(ayah)))!, reader.quran.font);
    Color? colour() {
      for (final r in tester.widgetList<RichText>(
          find.byWidgetPredicate((w) => w is RichText && w.textAlign == TextAlign.justify))) {
        for (final s in (r.text as TextSpan).children!.cast<TextSpan>()) {
          if (s.toPlainText(includeSemanticsLabels: false) == text) return s.style?.color;
        }
      }
      return null;
    }

    expect(colour(), isNot(colors.similar));
    reader.replaceSimilar(linked);
    await settle(tester, 2);
    expect(colour(), colors.similar);
  });
}
