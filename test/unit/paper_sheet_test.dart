// Paper sheet texture (specs/002-print-like-mushaf-page/contracts/reader-page-view.md › Sheet).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/theme/app_theme.dart';
import 'package:mathani/features/reader/paper_sheet.dart';

double _luminance(Color c) {
  double channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('the noise tile is 128 × 128 and the same every time', () {
    final a = PaperSheet.noisePixels();
    expect(a.length, PaperSheet.tileSize * PaperSheet.tileSize * 4);
    expect(PaperSheet.tileSize, 128);
    expect(PaperSheet.noisePixels(), a);
    expect(a.toSet().length, greaterThan(16), reason: 'it is noise, not a flat colour');
  });

  for (final brightness in Brightness.values) {
    test('Quran ink keeps AA contrast on the darkest paper ($brightness)', () {
      final c = MathaniColors.forBrightness(brightness);
      // Darkest (day) or lightest (night) point: full texture plus the page edge.
      final worst = Color.lerp(
          c.surface, c.ink, PaperSheet.textureOpacity + PaperSheet.edgeOpacity)!;
      expect(_contrast(c.ink, worst), greaterThanOrEqualTo(4.5));
      // Under the text there is only grain (the binding shade sits in the margin).
      final grain = Color.lerp(c.surface, c.ink, PaperSheet.textureOpacity)!;
      expect(_contrast(c.ink, grain) / _contrast(c.ink, c.surface), greaterThan(0.9),
          reason: 'the grain is subtle');
    });
  }
}
