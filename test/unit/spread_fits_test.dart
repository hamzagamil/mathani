import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/reader/page_geometry.dart';

/// When the Mushaf shows two facing pages (specs/012 research R1), and which pages pair up.
void main() {
  group('spreadFits', () {
    // Whole screens (or browser windows) in logical pixels.
    const one = {
      'iPhone SE (2nd gen)': Size(375, 667),
      'iPhone 16': Size(393, 852),
      'iPhone Duo, folded': Size(466, 678),
      'iPhone Duo, open, half in Split View': Size(445, 626),
      'Galaxy Z Fold 7, folded': Size(412, 915),
      'Android tablet, upright': Size(800, 1280),
      'small browser window': Size(600, 400),
    };
    const two = {
      'iPhone Duo, open': Size(890, 626),
      'Galaxy Z Fold 7, open upright': Size(750, 832),
      'Galaxy Z Fold 7, open sideways': Size(832, 750),
      'Galaxy Z Fold 6, open upright': Size(714, 831),
      'Galaxy Z Fold 5, open upright': Size(690, 829),
      'desktop browser': Size(1440, 900),
    };
    for (final e in one.entries) {
      test('one page: ${e.key}', () => expect(PageGeometry.spreadFits(e.value), isFalse));
    }
    for (final e in two.entries) {
      test('two pages: ${e.key}', () => expect(PageGeometry.spreadFits(e.value), isTrue));
    }
    test('an empty area never fits', () => expect(PageGeometry.spreadFits(Size.zero), isFalse));
  });

  test('the 604 pages pair up as 302 spreads, odd on the right', () {
    expect(PageGeometry.spreadCount, 302);
    for (var p = 1; p <= 604; p++) {
      final right = PageGeometry.spreadRightPage(p);
      expect(right.isOdd, isTrue);
      expect(p == right || p == right + 1, isTrue, reason: 'page $p');
      expect(PageGeometry.spreadIndex(p), (right - 1) ~/ 2);
      expect(PageGeometry.spreadIndex(p), inInclusiveRange(0, 301));
    }
    expect(PageGeometry.spreadRightPage(1), 1);
    expect(PageGeometry.spreadRightPage(2), 1);
    expect(PageGeometry.spreadRightPage(604), 603);
    expect(PageGeometry.spreadIndex(604), 301);
  });

  // The page of a phone turned sideways (specs/013 research R5).
  test('the scrolling page is as wide as the screen allows, and one line taller than it needs',
      () {
    for (final width in [692.0, 734.0, 667.0]) {
      final height = PageGeometry.scrollPageHeight(width);
      final g = PageGeometry.of(Size(width, height), 20);
      final block = width * (1 - 2 * PageGeometry.markerMarginFraction);
      expect(g.textBlock.width, closeTo(block, 1e-6), reason: 'limited by the width');
      expect(g.textBlock.left, closeTo((width - block) / 2, 1e-6));
      final line = block * PageGeometry.blockRatio / PageGeometry.linesPerPage;
      expect(height,
          closeTo(block * PageGeometry.blockRatio + 2 * PageGeometry.bandLines * line + line, 1e-6));
      // Half a line of paper above the surah and juz line and below the page number.
      expect(g.headerBand.top, closeTo(line / 2, 1e-6));
      expect(height - g.footerBand.bottom, closeTo(line / 2, 1e-6));
    }
  });
}
