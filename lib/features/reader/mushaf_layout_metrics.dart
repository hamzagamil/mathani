import 'dart:math' as math;
import 'dart:ui' show Size;

/// Quran font size for the Mushaf layout on a given screen area (research R4).
///
/// One size per screen geometry, so every page looks the same: the largest size at which the
/// 98th-percentile line fits the content width and 15 lines (line height 2.0) fit the height.
/// The few wider lines are shrunk individually by the renderer.
class MushafLayoutMetrics {
  MushafLayoutMetrics._(this.size, this.fontSize, this.sideMargin, this.lineSlots);

  static const linesPerPage = 15;
  static const lineHeightFactor = 2.0;

  /// Side margin as a fraction of the width; holds the hizb-quarter and sajdah markers.
  static const sideMarginFraction = 0.045;

  static MushafLayoutMetrics? _cached;

  final Size size;
  final double fontSize;
  final double sideMargin;
  final int lineSlots;

  double get lineHeight => size.height / lineSlots;
  double get contentWidth => size.width - 2 * sideMargin;

  static MushafLayoutMetrics of(Size size, double lineWidthEm, {int lines = linesPerPage}) {
    final slots = math.max(linesPerPage, lines);
    final cached = _cached;
    if (cached != null && cached.size == size && cached.lineSlots == slots) return cached;
    final margin = size.width * sideMarginFraction;
    final byWidth = lineWidthEm > 0 ? (size.width - 2 * margin) / lineWidthEm : 24.0;
    final byHeight = size.height / (slots * lineHeightFactor);
    return _cached = MushafLayoutMetrics._(size, math.min(byWidth, byHeight), margin, slots);
  }
}
