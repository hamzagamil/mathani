import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../shared/quran_text.dart';
import 'mushaf_layout_metrics.dart';
import 'surah_header_painter.dart';

/// Colours the renderer needs, taken from the theme's semantic tokens.
@immutable
class MushafPalette {
  const MushafPalette({
    required this.ink,
    required this.accentInk,
    required this.highlight,
    required this.selection,
  });

  final Color ink;
  final Color accentInk;
  final Color highlight; // jump target: secondary-soft
  final Color selection; // long-press selection: selected

  @override
  bool operator ==(Object other) =>
      other is MushafPalette &&
      other.ink == ink &&
      other.accentInk == accentInk &&
      other.highlight == highlight &&
      other.selection == selection;

  @override
  int get hashCode => Object.hash(ink, accentInk, highlight, selection);
}

/// One page of the page-faithful Mushaf layout (research R4): 15 line slots, words shaped once
/// into cached [TextPainter]s, `ayah` lines justified (or centred), lines wider than the content
/// width shrunk individually, surah headers framed, quarter and sajdah marks in the margin.
/// Always right-to-left, whatever the interface language.
class MushafPageRenderer extends LeafRenderObjectWidget {
  const MushafPageRenderer({
    super.key,
    required this.page,
    required this.surahNames,
    required this.lineWidthEm,
    required this.font,
    required this.palette,
    this.quarterStartWords = const {},
    this.sajdahEndWords = const {},
    this.selected,
    this.highlighted,
  });

  final MushafPage page;
  final Map<int, String> surahNames; // surah number → Arabic name
  final double lineWidthEm; // meta p98_line_width_em
  final String font; // meta font
  final MushafPalette palette;
  final Set<int> quarterStartWords; // word ids that begin a hizb quarter
  final Set<int> sajdahEndWords; // word ids that end a sajdah ayah
  final AyahRef? selected;
  final AyahRef? highlighted;

  @override
  RenderMushafPage createRenderObject(BuildContext context) => RenderMushafPage(this);

  @override
  void updateRenderObject(BuildContext context, RenderMushafPage renderObject) =>
      renderObject.update(this);
}

class RenderMushafPage extends RenderBox {
  RenderMushafPage(this._config);

  MushafPageRenderer _config;
  MushafLayoutMetrics? _metrics;
  final Map<int, TextPainter> _wordPainters = {};
  final List<_LinePlacement> _placements = [];

  /// Ayahs whose text already carries a mark inline (some sources include ۞ or ۩); the margin
  /// copy is then not drawn.
  final Set<(AyahRef, String)> _inlineMarks = {};

  void update(MushafPageRenderer next) {
    final old = _config;
    _config = next;
    if (!identical(old.page, next.page) || old.palette != next.palette || old.font != next.font) {
      _disposePainters();
      markNeedsLayout();
    } else if (old.selected != next.selected || old.highlighted != next.highlighted) {
      markNeedsPaint();
    }
  }

  /// The ayah under [localPosition], for long-press selection (FR-020).
  AyahRef? ayahAt(Offset localPosition) {
    for (final line in _placements) {
      if (localPosition.dy < line.top || localPosition.dy > line.top + line.height) continue;
      for (final w in line.words) {
        final r = line.wordRect(w);
        if (localPosition.dx >= r.left - line.gap / 2 && localPosition.dx <= r.right + line.gap / 2) {
          return w.word.ref;
        }
      }
    }
    return null;
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void performLayout() {
    size = constraints.biggest;
    final page = _config.page;
    final metrics = _metrics = MushafLayoutMetrics.of(size, _config.lineWidthEm, lines: page.lines.length);
    final style = TextStyle(
      fontFamily: TypeScale.quranFamily,
      fontSize: metrics.fontSize,
      color: _config.palette.ink,
    );
    final space = _painter(' ', style);
    final spaceWidth = space.width;
    space.dispose();

    _placements.clear();
    _inlineMarks.clear();
    for (final line in page.lines) {
      for (final w in line.words) {
        for (final mark in const [rubAlHizbMark, sajdahMark]) {
          if (w.text.contains(mark)) _inlineMarks.add((w.ref, mark));
        }
      }
    }
    for (var i = 0; i < page.lines.length; i++) {
      final line = page.lines[i];
      final top = i * metrics.lineHeight;
      if (line.type != LineType.ayah) {
        _placements.add(_LinePlacement(line, top, metrics.lineHeight, const [], 1, 0, 0));
        continue;
      }
      final placed = [
        for (final w in line.words)
          _PlacedWord(w, _wordPainters.putIfAbsent(w.id, () => _painter(_display(w), style))),
      ];
      final gaps = math.max(0, placed.length - 1);
      final natural = placed.fold<double>(0, (s, p) => s + p.painter.width) + gaps * spaceWidth;
      final available = metrics.contentWidth;
      final scale = natural > available ? available / natural : 1.0;
      final justify = !line.centered && gaps > 0;
      final gap = justify && scale == 1 ? spaceWidth + (available - natural) / gaps : spaceWidth;
      final used = natural * scale + (justify && scale == 1 ? available - natural : 0);
      // RTL: words run from the right edge leftwards.
      var x = size.width - metrics.sideMargin - (available - used) / 2;
      for (final p in placed) {
        x -= p.painter.width * scale;
        p.x = x;
        x -= gap * scale;
      }
      _placements.add(_LinePlacement(line, top, metrics.lineHeight, placed, scale, gap, natural));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final metrics = _metrics!;
    final palette = _config.palette;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    for (final line in _placements) {
      switch (line.line.type) {
        case LineType.surahName:
          _paintSurahHeader(canvas, line, metrics);
        case LineType.basmallah:
          _paintCentered(canvas, line, basmalaText, metrics.fontSize * 0.92, palette.accentInk);
        case LineType.ayah:
          _paintAyahLine(canvas, line, metrics);
      }
    }
    canvas.restore();
  }

  void _paintAyahLine(Canvas canvas, _LinePlacement line, MushafLayoutMetrics metrics) {
    final palette = _config.palette;
    // Selection and jump highlight behind the words of that ayah.
    for (final (ref, color) in [
      (_config.highlighted, palette.highlight),
      (_config.selected, palette.selection),
    ]) {
      if (ref == null) continue;
      final rects = [for (final w in line.words) if (w.word.ref == ref) line.wordRect(w)];
      if (rects.isEmpty) continue;
      final r = rects.reduce((a, b) => a.expandToInclude(b)).inflate(metrics.fontSize * 0.12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(metrics.fontSize * 0.3)),
        Paint()..color = color,
      );
    }
    for (final w in line.words) {
      final y = line.top + (line.height - w.painter.height * line.scale) / 2;
      if (line.scale == 1) {
        w.painter.paint(canvas, Offset(w.x, y));
      } else {
        canvas.save();
        canvas.translate(w.x, y);
        canvas.scale(line.scale);
        w.painter.paint(canvas, Offset.zero);
        canvas.restore();
      }
      // Margin marks (FR-007): rub' al-hizb at a quarter start, sajdah at a sajdah ayah.
      final mark = _config.quarterStartWords.contains(w.word.id)
          ? rubAlHizbMark
          : _config.sajdahEndWords.contains(w.word.id)
              ? sajdahMark
              : null;
      if (mark != null && !_inlineMarks.contains((w.word.ref, mark))) {
        final p = _painter(mark, TextStyle(
          fontFamily: TypeScale.quranFamily,
          fontSize: metrics.fontSize * 0.7,
          color: palette.accentInk,
        ));
        // Start-side (right) margin of the right-to-left page.
        p.paint(canvas, Offset(
          size.width - metrics.sideMargin + (metrics.sideMargin - p.width) / 2,
          line.top + (line.height - p.height) / 2,
        ));
        p.dispose();
      }
    }
  }

  void _paintSurahHeader(Canvas canvas, _LinePlacement line, MushafLayoutMetrics metrics) {
    final rect = Rect.fromLTWH(
      metrics.sideMargin,
      line.top + line.height * 0.12,
      metrics.contentWidth,
      line.height * 0.76,
    );
    paintSurahFrame(canvas, rect, _config.palette.accentInk);
    final name = _config.surahNames[line.line.surah] ?? '';
    _paintCentered(canvas, line, 'سُورَةُ $name', metrics.fontSize * 0.8, _config.palette.accentInk);
  }

  void _paintCentered(Canvas canvas, _LinePlacement line, String text, double fontSize, Color color) {
    final p = _painter(text, TextStyle(fontFamily: TypeScale.quranFamily, fontSize: fontSize, color: color));
    p.paint(canvas, Offset((size.width - p.width) / 2, line.top + (line.height - p.height) / 2));
    p.dispose();
  }

  String _display(Word w) => w.isAyahEnd ? ayahEndGlyphs(w.text, _config.font) : w.text;

  TextPainter _painter(String text, TextStyle style) => TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.rtl,
        textScaler: TextScaler.noScaling, // Quran size follows screen fit, not system scaling
      )..layout();

  void _disposePainters() {
    for (final p in _wordPainters.values) {
      p.dispose();
    }
    _wordPainters.clear();
  }

  @override
  void dispose() {
    _disposePainters();
    super.dispose();
  }
}

class _PlacedWord {
  _PlacedWord(this.word, this.painter);
  final Word word;
  final TextPainter painter;
  double x = 0;
}

class _LinePlacement {
  _LinePlacement(this.line, this.top, this.height, this.words, this.scale, this.gap, this.natural);
  final MushafLine line;
  final double top;
  final double height;
  final List<_PlacedWord> words;
  final double scale;
  final double gap;
  final double natural;

  Rect wordRect(_PlacedWord w) => Rect.fromLTWH(
        w.x,
        top + (height - w.painter.height * scale) / 2,
        w.painter.width * scale,
        w.painter.height * scale,
      );
}
