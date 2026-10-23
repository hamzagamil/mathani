// The recited-ayah highlight (specs/004 T019): readable and distinct in both themes.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/theme/app_theme.dart';

double _luminance(Color c) {
  double channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Distance between two colours, enough to tell them apart side by side.
double _distance(Color a, Color b) =>
    math.sqrt(math.pow(a.r - b.r, 2) + math.pow(a.g - b.g, 2) + math.pow(a.b - b.b, 2)) * 255;

void main() {
  for (final brightness in Brightness.values) {
    final c = MathaniColors.forBrightness(brightness);

    test('Quran ink keeps AA contrast on the recited highlight ($brightness)', () {
      expect(_contrast(c.ink, c.recited), greaterThanOrEqualTo(4.5));
    });

    test('the recited highlight stands apart from the jump highlight, selection and paper '
        '($brightness)', () {
      expect(_distance(c.recited, c.secondarySoft), greaterThan(15));
      expect(_distance(c.recited, c.selected), greaterThan(30));
      expect(_distance(c.recited, c.surface), greaterThan(20));
    });
  }
}
