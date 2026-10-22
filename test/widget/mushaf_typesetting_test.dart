// Print-like typesetting of all 604 pages (specs/002-print-like-mushaf-page,
// contracts/page-typesetting.md). Platform independent: checks geometry, not pixels.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/theme/app_theme.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/reader/ayah_actions.dart';
import 'package:mathani/features/reader/mushaf_page_renderer.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';

/// Quran font size before this feature, at each reader width (task T001): content width
/// `(width − 16) × 0.91` divided by `p98_line_width_em` 21.547. FR-012: never smaller.
final baselineFontSize = {320.0: 12.839, 375.0: 15.162, 390.0: 15.795, 430.0: 17.485};

const _height = 700.0;

/// Lines that run out of join points before reaching normal spacing (research P2, risk R-2).
/// Recorded on the first passing run (2026-10-22: 86 of 8,791 lines, the same at every width,
/// with up to 4 tatweels per join point); it must not grow.
const maxOverGapLines = 86;

void main() {
  late ReaderController reader;
  late List<MushafPage> pages;
  final colors = MathaniColors.forBrightness(Brightness.light);
  final palette = MushafPalette(
    ink: colors.ink,
    accentInk: colors.accentInk,
    highlight: colors.secondarySoft,
    selection: colors.selected,
  );

  Widget page(MushafPage p, double width, double height) => Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: MushafPageRenderer(
              page: p,
              surahNames: {for (final s in reader.quran.surahList) s.number: s.nameAr},
              targetEm: reader.quran.justifyTargetEm,
              font: reader.quran.font,
              palette: palette,
              details: MushafPageDetails.of(reader.quran, p.number),
            ),
          ),
        ),
      );

  /// The default 800 × 600 test window would clip taller pages.
  void useLargeWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  setUpAll(() async {
    await loadAppFonts();
    reader = await openTestReader();
    pages = [for (var p = 1; p <= 604; p++) await reader.quran.page(p)];
  });

  testWidgets('every justified line is full width, gaps normal, no line below 95%', (tester) async {
    useLargeWindow(tester);
    for (final width in baselineFontSize.keys) {
      var overGap = 0;
      final overGapAt = <String>[];
      for (final p in pages) {
        await tester.pumpWidget(page(p, width, _height));
        final box = tester.renderObject<RenderMushafPage>(find.byType(MushafPageRenderer));
        for (final r in box.lineReports) {
          final at = 'page ${p.number} line ${r.line} at $width';
          expect(r.scale, greaterThanOrEqualTo(0.95 - 1e-9), reason: at);
          if (r.centered) continue;
          expect(r.width, closeTo(r.target, r.target * 0.01), reason: at);
          if (r.overGap) {
            overGap++;
            overGapAt.add(at);
          } else {
            expect(r.gap, lessThanOrEqualTo(1.5 * r.space + 1e-6), reason: at);
          }
          expect(r.gap, greaterThanOrEqualTo(0.5 * r.space - 1e-6), reason: at);
        }
      }
      // ignore: avoid_print
      print('$width pt: $overGap lines over 1.5 × space ${overGapAt.take(5)}');
      expect(overGap, lessThanOrEqualTo(maxOverGapLines), reason: '$width pt: $overGapAt');
    }
  });

  testWidgets('print proportions on every screen; spare space becomes margins', (tester) async {
    useLargeWindow(tester);
    for (final width in baselineFontSize.keys) {
      for (final height in [560.0, 700.0, 900.0]) {
        await tester.pumpWidget(page(pages[2], width, height));
        final g = tester.renderObject<RenderMushafPage>(find.byType(MushafPageRenderer)).geometry!;
        final at = '$width × $height';
        final block = g.textBlock;
        expect(block.height / block.width, closeTo(1.77, 1.77 * 0.02), reason: at);
        expect(block.left, closeTo(width - block.right, 2), reason: at);
        expect(g.headerBand.top, closeTo(height - g.footerBand.bottom, 2), reason: at);
        expect(g.lineHeight, closeTo(block.height / 15, 1e-6), reason: at);
        expect(g.lineHeight, lessThanOrEqualTo(1.77 * width / 15 + 1e-6), reason: at);
        expect(g.headerBand.bottom, lessThanOrEqualTo(block.top + 1e-6), reason: at);
        expect(g.footerBand.top, greaterThanOrEqualTo(block.bottom - 1e-6), reason: at);
      }
    }
  });

  testWidgets('Quran text is never smaller than before (FR-012)', (tester) async {
    useLargeWindow(tester);
    // The full-screen reader body on each reference size, within safe areas.
    final screens = {
      320.0: const Size(320, 548), // 4" iPhone SE (1st gen) class
      375.0: const Size(375, 647), // iPhone SE (2nd gen)
      390.0: const Size(390, 763), // 6.1" class
      430.0: const Size(430, 839), // 6.7" class
    };
    for (final MapEntry(key: width, value: size) in screens.entries) {
      await tester.pumpWidget(page(pages[2], size.width, size.height));
      final g = tester.renderObject<RenderMushafPage>(find.byType(MushafPageRenderer)).geometry!;
      // ignore: avoid_print
      print('$size: font ${g.fontSize.toStringAsFixed(2)} vs before ${baselineFontSize[width]}');
      expect(g.fontSize, greaterThanOrEqualTo(baselineFontSize[width]!), reason: '$size');
    }
  });

  testWidgets('surah, juz and page number are printed on the page (FR-009)', (tester) async {
    useLargeWindow(tester);
    for (final (n, surah, juz, number) in [
      (1, 'سورة الفاتحة', 'الجزء ١', '١'),
      (3, 'سورة البقرة', 'الجزء ١', '٣'),
      (604, 'سورة الإخلاص', 'الجزء ٣٠', '٦٠٤'),
    ]) {
      await tester.pumpWidget(page(pages[n - 1], 390, 763));
      final box = tester.renderObject<RenderMushafPage>(find.byType(MushafPageRenderer));
      final d = box.pageDetails!;
      final g = box.geometry!;
      expect((d.surah, d.juz, d.page), (surah, juz, number), reason: 'page $n');
      // Centres, since Amiri's text box is taller than its glyphs.
      expect(g.headerBand.inflate(1).contains(d.surahRect.center), isTrue, reason: 'page $n surah');
      expect(g.headerBand.inflate(1).contains(d.juzRect.center), isTrue, reason: 'page $n juz');
      expect(g.footerBand.inflate(1).contains(d.pageRect.center), isTrue, reason: 'page $n number');
      expect(d.surahRect.right, closeTo(g.textBlock.right, 1), reason: 'surah at the right');
      expect(d.juzRect.left, closeTo(g.textBlock.left, 1), reason: 'juz at the left');
      expect(d.pageRect.center.dx, closeTo(g.textBlock.center.dx, 1), reason: 'page centred');
    }
  });

  testWidgets('copied text stays the source text (FR-005)', (tester) async {
    for (final n in [3, 50, 300]) {
      await tester.pumpWidget(page(pages[n - 1], 390, _height));
      final box = tester.renderObject<RenderMushafPage>(find.byType(MushafPageRenderer));
      expect(box.lineReports.where((r) => r.tatweels > 0), isNotEmpty,
          reason: 'page $n is justified with kashida');
      final refs = {for (final line in pages[n - 1].lines) for (final w in line.words) w.ref};
      for (final ref in refs) {
        final words = (await tester.runAsync(() => reader.quran.wordsOf(ref)))!;
        final text = formatAyahForShare(words, reader.quran.surahList[ref.surah - 1], ref.ayah,
            arabic: true);
        final source = [for (final x in words) if (!x.isAyahEnd) x.text].join(' ');
        expect(text, startsWith('﴿$source﴾'), reason: 'copy of $ref is the source text');
      }
    }
  });
}
