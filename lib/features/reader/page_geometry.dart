import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

/// Where a Mushaf page's text goes on a screen (specs/002-print-like-mushaf-page,
/// contracts/page-typesetting.md › Page geometry).
///
/// The 15 lines form a text block with the proportions of the printed page, as large as the
/// screen allows and centred; whatever space is left becomes margins. Line spacing never grows
/// to fill a tall screen. Above and below the block are bands for the page details (surah, juz,
/// page number); the hizb and sajdah marks sit in the margin beside it.
///
/// On a phone turned sideways the page is given the screen's width and [scrollPageHeight], so
/// the block is as wide as the screen allows and the page scrolls (specs/013).
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

  /// Two facing pages need each page's text to be at least this share of one page's on the same
  /// screen (specs/012 research R1)…
  static const spreadMinShare = 0.7;

  /// …and a text block at least this wide, in logical pixels.
  static const spreadMinBlockWidth = 240.0;

  /// Number of two-page spreads: 1–2, 3–4, … 603–604.
  static const spreadCount = 302;

  /// Width of the text block on a page of [width] × [height].
  static double blockWidth(double width, double height) => math.max(
      0.0,
      math.min(width * (1 - 2 * markerMarginFraction),
          height / (blockRatio * (1 + 2 * bandLines / linesPerPage))));

  /// Whether a screen (or browser window) of [area] shows two facing Mushaf pages: each keeps at
  /// least [spreadMinShare] of the one-page text size and a [spreadMinBlockWidth] block (specs/012
  /// FR-001). It takes the whole screen, so system bars and docked bars coming and going never
  /// flip it, and it depends on the size only, never on the device.
  static bool spreadFits(Size area) {
    final two = blockWidth(area.width / 2, area.height);
    return two >= spreadMinBlockWidth &&
        two >= spreadMinShare * blockWidth(area.width, area.height);
  }

  /// The narrowest page on which the text block reaches its full size for [height]: wider pages
  /// only add margin. Two of these side by side make the web's two-page column (specs/012 R7).
  static double fullPageWidth(double height) =>
      blockWidth(double.infinity, height) / (1 - 2 * markerMarginFraction);

  /// Height of the scrolling page on a sideways phone (specs/013 research R5): a page of
  /// [width] whose text block is limited by the width, with both bands and one more line of
  /// paper, so the page details do not touch the screen's edge.
  static double scrollPageHeight(double width) {
    final block = math.max(0.0, width * (1 - 2 * markerMarginFraction));
    final line = block * blockRatio / linesPerPage;
    return block * blockRatio + (2 * bandLines + 1) * line;
  }

  /// The right-hand (odd) page of the spread that holds [page].
  static int spreadRightPage(int page) => page.isOdd ? page : page - 1;

  /// Index of the spread that holds [page], from 0 to [spreadCount] − 1.
  static int spreadIndex(int page) => (page - 1) ~/ 2;

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
