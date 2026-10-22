import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

/// Where a Mushaf page's text goes on a screen (specs/002-print-like-mushaf-page,
/// contracts/page-typesetting.md › Page geometry).
///
/// The 15 lines form a text block with the proportions of the printed page, as large as the
/// screen allows and centred; whatever space is left becomes margins. Line spacing never grows
/// to fill a tall screen. Above and below the block are bands for the page details (surah, juz,
/// page number); the hizb and sajdah marks sit in the margin beside it.
class PageGeometry {
  PageGeometry._(this.size, this.textBlock, this.fontSize, this.lineHeight, this.headerBand,
      this.footerBand);

  /// Height ÷ width of the text block, from the reference print-like page (research P4).
  static const blockRatio = 1.77;

  static const linesPerPage = 15;

  /// Height of the header and footer bands, in line heights.
  static const bandLines = 0.6;

  /// Size of the page-detail text, in line heights.
  static const detailTextLines = 0.32;

  /// Smallest side margin, as a fraction of the width; holds the hizb-quarter and sajdah marks.
  static const markerMarginFraction = 0.045;

  static PageGeometry? _cached;
  static double _cachedTarget = 0;

  final Size size;
  final Rect textBlock;
  final double fontSize;
  final double lineHeight;
  final Rect headerBand;
  final Rect footerBand;

  /// Geometry for a page of [size] whose justified lines are [targetEm] wide.
  static PageGeometry of(Size size, double targetEm) {
    final cached = _cached;
    if (cached != null && cached.size == size && _cachedTarget == targetEm) return cached;

    final byWidth = size.width * (1 - 2 * markerMarginFraction);
    // Block plus both bands: ratio × w × (1 + 2 × bandLines ÷ 15).
    final heightPerWidth = blockRatio * (1 + 2 * bandLines / linesPerPage);
    final width = math.max(0.0, math.min(byWidth, size.height / heightPerWidth));
    final height = width * blockRatio;
    final lineHeight = height / linesPerPage;
    final band = bandLines * lineHeight;
    final top = (size.height - height - 2 * band) / 2 + band;
    final block = Rect.fromLTWH((size.width - width) / 2, top, width, height);
    _cachedTarget = targetEm;
    return _cached = PageGeometry._(
      size,
      block,
      targetEm > 0 ? width / targetEm : 24,
      lineHeight,
      Rect.fromLTRB(block.left, block.top - band, block.right, block.top),
      Rect.fromLTRB(block.left, block.bottom, block.right, block.bottom + band),
    );
  }
}
