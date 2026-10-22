// Printed lettering: the King Fahd Complex page fonts (specs/002-print-like-mushaf-page,
// User Story 4).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/app/theme/app_theme.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/reader/mushaf_page_renderer.dart';
import 'package:mathani/features/reader/printed_fonts.dart';
import 'package:mathani/shared/mathani_icons.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';

void main() {
  testWidgets('every page in its printed lettering: same words, full lines', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late ReaderController reader;
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    final quran = reader.quran;
    expect(quran.hasPrintedLettering, isTrue);
    final colors = MathaniColors.forBrightness(Brightness.light);
    final palette = MushafPalette(
      ink: colors.ink,
      accentInk: colors.accentInk,
      highlight: colors.secondarySoft,
      selection: colors.selected,
    );

    var centred = 0;
    var maxGap = 0.0;
    for (var n = 1; n <= 604; n++) {
      final (builtin, printed, glyphs, family) = (await tester.runAsync(() async {
        final printed = await quran.page(n, printed: true);
        return (
          await quran.page(n),
          printed,
          await quran.printedGlyphs(printed),
          await PrintedFonts.load(n),
        );
      }))!;
      ids(MushafPage p) => [for (final l in p.lines) for (final w in l.words) w.id];
      expect(ids(printed), ids(builtin), reason: 'page $n has the same words in the same order');
      expect(printed.lines.length, builtin.lines.length, reason: 'page $n line count');
      expect(printed.lines.where((l) => l.type != LineType.ayah).length,
          lessThanOrEqualTo(builtin.lines.where((l) => l.type != LineType.ayah).length + 2),
          reason: 'page $n titles');
      for (final id in ids(printed)) {
        expect(glyphs.containsKey(id), isTrue, reason: 'page $n word $id has a glyph entry');
      }

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SizedBox(
            width: 390,
            height: 763,
            child: MushafPageRenderer(
              page: printed,
              surahNames: {for (final s in quran.surahList) s.number: s.nameAr},
              targetEm: quran.printedTargetEm,
              font: quran.font,
              palette: palette,
              printedGlyphs: glyphs,
              printedFamily: family,
              printedSpaceEm: quran.printedSpaceEm,
            ),
          ),
        ),
      ));
      final box = tester.renderObject<RenderMushafPage>(find.byType(MushafPageRenderer));
      final fontSize = box.geometry!.fontSize;
      for (final r in box.lineReports) {
        final at = 'page $n line ${r.line}';
        expect(r.scale, greaterThanOrEqualTo(0.95 - 1e-9), reason: at);
        if (r.centered) {
          centred++;
          continue;
        }
        expect(r.width, closeTo(r.target, r.target * 0.01), reason: at);
        expect(r.gap, greaterThanOrEqualTo(0), reason: at);
        if (r.gap / fontSize > maxGap) maxGap = r.gap / fontSize;
      }
    }
    // ignore: avoid_print
    print('printed lettering: $centred centred lines, widest gap ${maxGap.toStringAsFixed(2)} em');
    expect(maxGap, lessThan(1.0), reason: 'printed lines are lettered to width, not spread');
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('the setting switches lettering and keeps the page', (tester) async {
    late ReaderController reader;
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    reader.updatePreferences(reader.preferences.copyWith(language: LanguagePref.en));
    tester.view.physicalSize = const Size(780, 1690);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    Future<void> settle([int rounds = 6]) async {
      for (var i = 0; i < rounds; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    await tester.pumpWidget(MathaniApp(controller: reader));
    await settle();
    reader.jumpTo(const AyahRef(2, 255), highlight: false);
    await settle();
    final page = reader.page;
    expect(reader.preferences.lettering, Lettering.printed, reason: 'printed by default');

    await tapToolbar(tester, MathaniIcons.settings);
    await settle();
    await tester.tap(find.text('Printed Mushaf lettering'));
    await settle();
    expect(reader.preferences.lettering, Lettering.builtin);
    await tester.pageBack();
    await settle();
    expect(reader.page, page);
    final box = tester.renderObject<RenderMushafPage>(find.byType(MushafPageRenderer).first);
    expect(box.lineReports.any((r) => r.tatweels > 0), isTrue, reason: 'built-in lettering, kashida');
  });
}
