// The surah header spans the text from side to side (specs/013 FR-025, FR-026, SC-010).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/theme/app_theme.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/reader/mushaf_page_renderer.dart';
import 'package:mathani/features/reader/page_geometry.dart';
import 'package:mathani/features/reader/printed_fonts.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';

void main() {
  late ReaderController reader;
  late List<MushafPage> titled; // every page with a surah title
  final colors = MathaniColors.forBrightness(Brightness.light);
  final palette = MushafPalette(
    ink: colors.ink,
    accentInk: colors.accentInk,
    highlight: colors.secondarySoft,
    selection: colors.selected,
  );

  Widget page(MushafPage p, Size size, {String? headerFamily, Key? key}) => Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              width: size.width,
              height: size.height,
              color: colors.surface,
              child: MushafPageRenderer(
                page: p,
                surahNames: {for (final s in reader.quran.surahList) s.number: s.nameAr},
                targetEm: reader.quran.justifyTargetEm,
                font: reader.quran.font,
                palette: palette,
                details: MushafPageDetails.of(reader.quran, p.number),
                surahHeaderFamily: headerFamily,
              ),
            ),
          ),
        ),
      );

  setUpAll(() async {
    await loadAppFonts();
    reader = await openTestReader();
    titled = [
      for (var n = 1; n <= 604; n++)
        if (await reader.quran.page(n) case final p
            when p.lines.any((l) => l.type == LineType.surahName))
          p,
    ];
  });

  // A phone in portrait, and the sideways page of a 780 dp phone (692 dp inside the insets).
  for (final size in [const Size(375, 640), Size(692, PageGeometry.scrollPageHeight(692))]) {
    testWidgets('all 114 headers are as wide as the text at ${size.width.toInt()} dp',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var headers = 0;
      for (final p in titled) {
        await tester.pumpWidget(page(p, size, headerFamily: PrintedFonts.headerFamily));
        final box = tester.renderObject<RenderMushafPage>(find.byType(MushafPageRenderer));
        final block = box.geometry!.textBlock;
        for (final h in box.surahHeaderRects) {
          headers++;
          final why = 'page ${p.number}';
          expect(h.ink.left, closeTo(block.left, block.width * 0.01), reason: why);
          expect(h.ink.right, closeTo(block.right, block.width * 0.01), reason: why);
          expect(h.ink.center.dy, closeTo(h.slot.center.dy, 0.01), reason: why);
          expect(h.slot.top - h.ink.top, lessThanOrEqualTo(h.slot.height * 0.03), reason: why);
          expect(h.ink.bottom - h.slot.bottom, lessThanOrEqualTo(h.slot.height * 0.03),
              reason: why);
        }
      }
      expect(headers, 114);
    });
  }

  testWidgets('without the header font, the plain frame is as wide as the text', (tester) async {
    const size = Size(375, 640);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(page(titled.firstWhere((p) => p.number == 187), size));
    final box = tester.renderObject<RenderMushafPage>(find.byType(MushafPageRenderer));
    final block = box.geometry!.textBlock;
    final frame = box.surahHeaderRects.single.ink;
    expect(frame.left, block.left);
    expect(frame.right, block.right);
  });

  // The rectangles above come from the glyph's measured proportions. This draws, with the real
  // font, every page whose first or last line is a header, and checks the pixels: the glyph
  // fills the rectangle it reports, and clear paper separates it from the page details.
  testWidgets('the drawn header glyph fills its rectangle and touches no page detail',
      (tester) async {
    const size = Size(750, 1280);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final family = (await tester.runAsync(PrintedFonts.loadHeaders))!;
    final atEdge = [
      for (final p in titled)
        if (p.lines.first.type == LineType.surahName || p.lines.last.type == LineType.surahName)
          p,
    ];
    expect(atEdge.length, greaterThan(10));
    for (final p in atEdge) {
      final key = GlobalKey();
      await tester.pumpWidget(page(p, size, headerFamily: family, key: key));
      final box = tester.renderObject<RenderMushafPage>(find.byType(MushafPageRenderer));
      final block = box.geometry!.textBlock;
      final bytes = (await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        return image.toByteData(format: ui.ImageByteFormat.rawRgba);
      }))!;
      final ink = _rowInk(bytes, size, colors.surface);
      // A header row is inked nearly from side to side.
      bool frame(int y) => ink[y].count > block.width * 0.5;
      final first = p.lines.first.type == LineType.surahName;
      final header = first ? box.surahHeaderRects.first : box.surahHeaderRects.last;
      final why = 'page ${p.number}';
      final slack = header.slot.height * 0.03;
      var top = header.slot.top.floor() - 12;
      while (!frame(top)) {
        top++;
      }
      var bottom = header.slot.bottom.ceil() + 12;
      while (!frame(bottom)) {
        bottom--;
      }
      expect(top, closeTo(header.ink.top, slack), reason: why);
      expect(bottom + 1, closeTo(header.ink.bottom, slack), reason: why);
      expect(ink[top + 3].left, closeTo(block.left, block.width * 0.01), reason: why);
      expect(ink[top + 3].right, closeTo(block.right, block.width * 0.01), reason: why);
      // Clear paper between the glyph and the page details beside it (FR-026).
      final air = header.slot.height * 0.04;
      if (first) {
        var y = top - 1;
        while (y > 0 && ink[y].count == 0) {
          y--;
        }
        expect(top - 1 - y, greaterThanOrEqualTo(air), reason: '$why: surah and juz');
      } else {
        var y = bottom + 1;
        while (y < size.height - 1 && ink[y].count == 0) {
          y++;
        }
        expect(y - bottom - 1, greaterThanOrEqualTo(air), reason: '$why: page number');
      }
    }
  });
}

/// For each row of pixels: how many are clearly not [paper], and where they start and end.
List<({int count, int left, int right})> _rowInk(ByteData rgba, Size size, Color paper) {
  final width = size.width.toInt();
  final pr = (paper.r * 255).round(), pg = (paper.g * 255).round(), pb = (paper.b * 255).round();
  return [
    for (var y = 0; y < size.height.toInt(); y++)
      () {
        var count = 0, left = width, right = 0;
        for (var x = 0; x < width; x++) {
          final i = (y * width + x) * 4;
          final d = (rgba.getUint8(i) - pr).abs() +
              (rgba.getUint8(i + 1) - pg).abs() +
              (rgba.getUint8(i + 2) - pb).abs();
          if (d < 120) continue;
          count++;
          if (x < left) left = x;
          right = x + 1;
        }
        return (count: count, left: left, right: right);
      }(),
  ];
}
