// Mushaf layout at three phone widths (task T062, risk R-a).
//
// 1. Every one of the 604 pages lays out with all lines inside the content width and no line
//    shrunk below 95 % (specs/002 FR-004). Platform independent; runs in CI.
// 2. Pixel goldens for pages 1, 2, 3, 50, 187, 300 and 604, tagged `golden` because font rasterisation
//    differs by platform. CI excludes them; regenerate locally with
//    `flutter test --tags golden --update-goldens test/widget/mushaf_page_renderer_golden_test.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/theme/app_theme.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/reader/mushaf_page_renderer.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';

const _widths = [320.0, 375.0, 412.0];
const _pageHeight = 640.0; // reader body between header and toolbar on a ~780 dp phone

void main() {
  late ReaderController reader;
  final colors = MathaniColors.forBrightness(Brightness.light);
  final palette = MushafPalette(
    ink: colors.ink,
    accentInk: colors.accentInk,
    highlight: colors.secondarySoft,
    selection: colors.selected,
  );

  Widget page(MushafPage p, double width) => Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Container(
            width: width,
            height: _pageHeight,
            color: colors.surface,
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

  setUpAll(() async {
    await loadAppFonts();
    reader = await openTestReader();
  });

  testWidgets('all 604 pages fit at 320, 375 and 412 dp', (tester) async {
    final pages = (await tester.runAsync(() async => [
          for (var p = 1; p <= 604; p++) await reader.quran.page(p),
        ]))!;
    for (final width in _widths) {
      var minScale = 1.0;
      var minAt = 0;
      for (final p in pages) {
        await tester.pumpWidget(page(p, width));
        final box = tester.renderObject<RenderMushafPage>(find.byType(MushafPageRenderer));
        expect(box.allLinesFit, isTrue, reason: 'page ${p.number} at $width dp');
        if (box.minLineScale < minScale) {
          minScale = box.minLineScale;
          minAt = p.number;
        }
      }
      expect(minScale, greaterThanOrEqualTo(0.95 - 1e-9),
          reason: 'page $minAt at $width dp shrinks a line to ${minScale.toStringAsFixed(2)}');
    }
  });

  for (final width in _widths) {
    for (final number in [1, 2, 3, 50, 187, 300, 604]) {
      testWidgets('golden page $number at ${width.toInt()} dp', (tester) async {
        final p = (await tester.runAsync(() => reader.quran.page(number)))!;
        tester.view.physicalSize = Size(width * 2, _pageHeight * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(page(p, width));
        await expectLater(
          find.byType(MushafPageRenderer),
          matchesGoldenFile('goldens/page_${number}_${width.toInt()}.png'),
        );
      }, tags: ['golden']);
    }
  }
}
