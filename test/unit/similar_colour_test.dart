// The mutashabih text colour (specs/010 research R4): readable on the page and apart from the
// other text colours, in both themes.
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

/// Hue distance in degrees, 0..180.
double _hueGap(Color a, Color b) {
  final d = (HSLColor.fromColor(a).hue - HSLColor.fromColor(b).hue).abs();
  return math.min(d, 360 - d);
}

double _saturationGap(Color a, Color b) =>
    (HSLColor.fromColor(a).saturation - HSLColor.fromColor(b).saturation).abs();

void main() {
  for (final brightness in Brightness.values) {
    final c = MathaniColors.forBrightness(brightness);

    test('linked ayat keep AA contrast on the page ($brightness)', () {
      expect(_contrast(c.similar, c.surface), greaterThanOrEqualTo(4.5));
      // Also under the selection and the recitation highlight, which are drawn behind it.
      expect(_contrast(c.similar, c.selected), greaterThanOrEqualTo(3));
      expect(_contrast(c.similar, c.recited), greaterThanOrEqualTo(3));
    });

    test('the colour stands apart from the Quran text ($brightness)', () {
      // The ink is close to neutral in the night theme, so its hue says little: saturation or hue.
      expect(
        _hueGap(c.similar, c.ink) >= 25 || _saturationGap(c.similar, c.ink) >= 0.25,
        isTrue,
        reason: 'similar ${c.similar} vs ink ${c.ink}',
      );
    });

    test('the colour stands apart from the other marks ($brightness)', () {
      // The hint and mistake colours show only while memorizing, when no ayah is in the
      // mutashabih colour (research R4), so a smaller gap is enough.
      expect(_hueGap(c.similar, c.hint), greaterThanOrEqualTo(20));
      expect(_hueGap(c.similar, c.mistake), greaterThanOrEqualTo(15));
      // Surah names and margin marks are in accentInk: apart in saturation or lightness.
      final a = HSLColor.fromColor(c.accentInk), s = HSLColor.fromColor(c.similar);
      expect(
        _hueGap(c.similar, c.accentInk) >= 25 ||
            (a.saturation - s.saturation).abs() >= 0.1 ||
            (a.lightness - s.lightness).abs() >= 0.05,
        isTrue,
      );
    });
  }
}
