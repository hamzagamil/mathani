import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../data/quran_repository.dart';
import '../../shared/numerals.dart';
import '../../shared/quran_text.dart';
import 'kashida.dart';
import 'page_geometry.dart';
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

/// The page details printed around the text, as in the printed Mushaf: the surah and juz at the
/// top, the page number at the bottom. Always in Arabic, like the rest of the Mushaf area.
@immutable
class MushafPageDetails {
  const MushafPageDetails({required this.surahName, required this.juz});

  /// The details for [page]: the surah and juz of the first ayah on it.
  factory MushafPageDetails.of(QuranRepository quran, int page) {
    final first = quran.firstAyahOnPage(page);
    return MushafPageDetails(surahName: quran.surahList[first.surah - 1].nameAr, juz: first.juz);
  }

  final String surahName; // Arabic name, without «سورة»
  final int juz;

  @override
  bool operator ==(Object other) =>
      other is MushafPageDetails && other.surahName == surahName && other.juz == juz;

  @override
  int get hashCode => Object.hash(surahName, juz);
}

/// One page of the page-faithful Mushaf layout (001 research R4): 15 line slots, words shaped
/// once into cached [TextPainter]s, `ayah` lines filled like print by kashida with normal word
/// gaps (specs/002-print-like-mushaf-page/contracts/page-typesetting.md) or centred, surah
/// headers framed, quarter and sajdah marks in the margin. Always right-to-left, whatever the
/// interface language.
class MushafPageRenderer extends LeafRenderObjectWidget {
  const MushafPageRenderer({
    super.key,
    required this.page,
    required this.surahNames,
    required this.targetEm,
    required this.font,
    required this.palette,
    this.quarterStartWords = const {},
    this.sajdahEndWords = const {},
    this.selected,
    this.highlighted,
    this.details,
  });

  final MushafPage page;
  final Map<int, String> surahNames; // surah number → Arabic name
  final double targetEm; // meta justify_target_em: every justified line is filled to this
  final String font; // meta font
  final MushafPalette palette;
  final Set<int> quarterStartWords; // word ids that begin a hizb quarter
  final Set<int> sajdahEndWords; // word ids that end a sajdah ayah
  final AyahRef? selected;
  final AyahRef? highlighted;

  /// Surah and juz printed at the top of the page, with the page number at the bottom (FR-009).
  final MushafPageDetails? details;

  @override
  RenderMushafPage createRenderObject(BuildContext context) => RenderMushafPage(this);

  @override
  void updateRenderObject(BuildContext context, RenderMushafPage renderObject) =>
      renderObject.update(this);
}

class RenderMushafPage extends RenderBox {
  RenderMushafPage(this._config);

  MushafPageRenderer _config;
  PageGeometry? _geometry;

  /// Where the text block and page-detail bands are, for the typesetting tests.
  @visibleForTesting
  PageGeometry? get geometry => _geometry;

  /// The page details as laid out, for the typesetting tests.
  @visibleForTesting
  ({String surah, String juz, String page, Rect surahRect, Rect juzRect, Rect pageRect})?
      get pageDetails {
    final d = _details;
    if (d == null) return null;
    return (
      surah: d.surah.text,
      juz: d.juz.text,
      page: d.page.text,
      surahRect: d.surah.offset & d.surah.painter.size,
      juzRect: d.juz.offset & d.juz.painter.size,
      pageRect: d.page.offset & d.page.painter.size,
    );
  }

  ({_Detail surah, _Detail juz, _Detail page})? _details;
  final Map<int, TextPainter> _wordPainters = {}; // natural shape, by word id
  final Map<String, TextPainter> _stretchedPainters = {}; // with kashida, by display string
  final List<_LinePlacement> _placements = [];

  /// Join points depend only on the text, so they are shared by every page and size.
  static final Map<int, List<JoinPoint>> _joinPoints = {};

  /// Ayahs whose text already carries a mark inline (some sources include ۞ or ۩); the margin
  /// copy is then not drawn.
  final Set<(AyahRef, String)> _inlineMarks = {};

  void update(MushafPageRenderer next) {
    final old = _config;
    _config = next;
    if (!identical(old.page, next.page) ||
        old.palette != next.palette ||
        old.font != next.font ||
        old.details != next.details) {
      _disposePainters();
      markNeedsLayout();
    } else if (old.selected != next.selected || old.highlighted != next.highlighted) {
      markNeedsPaint();
    }
  }

  /// Smallest per-line shrink factor on this page (1 = no line shrunk). Layout tests use it to
  /// catch lines squeezed beyond legibility (risk R-a).
  @visibleForTesting
  double get minLineScale =>
      _placements.fold(1.0, (m, l) => l.words.isEmpty ? m : math.min(m, l.scale));

  /// How each ayah line was set, for the typesetting tests (contract › Budgets and checks).
  @visibleForTesting
  List<LineReport> get lineReports => [
        for (final l in _placements)
          if (l.words.isNotEmpty) l.report!,
      ];

  /// Whether every ayah line fits inside the content width after shrinking.
  @visibleForTesting
  bool get allLinesFit {
    final block = _geometry?.textBlock;
    if (block == null) return false;
    for (final l in _placements) {
      for (final w in l.words) {
        final r = l.wordRect(w);
        if (r.left < block.left - 0.5 || r.right > block.right + 0.5) return false;
      }
    }
    return true;
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
    final geometry = _geometry = PageGeometry.of(size, _config.targetEm);
    final block = geometry.textBlock;
    // Pages with fewer lines (1 and 2) keep the same spacing, centred in the block.
    final slots = math.max(PageGeometry.linesPerPage, page.lines.length);
    final lineHeight = block.height / slots;
    final firstTop = block.top + (slots - page.lines.length) * lineHeight / 2;
    final style = TextStyle(
      fontFamily: TypeScale.quranFamily,
      fontSize: geometry.fontSize,
      color: _config.palette.ink,
    );
    double widthOf(String text) {
      final p = _painter(text, style);
      final w = p.width;
      p.dispose();
      return w;
    }

    final spaceWidth = widthOf(' ');
    final tatweelWidth = widthOf('ب$tatweelب') - widthOf('بب');
    final target = block.width;
    _layoutDetails(geometry);

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
      final top = firstTop + i * lineHeight;
      if (line.type != LineType.ayah) {
        _placements.add(_LinePlacement(line, top, lineHeight, const [], 1, 0, 0));
        continue;
      }
      final placed = [
        for (final w in line.words)
          _PlacedWord(w, _wordPainters.putIfAbsent(w.id, () => _painter(_display(w), style))),
      ];
      final gaps = math.max(0, placed.length - 1);
      final naturalWidths = [for (final p in placed) p.painter.width];
      final natural = naturalWidths.fold<double>(0, (s, w) => s + w) + gaps * spaceWidth;
      final points = [
        for (final w in line.words)
          w.isAyahEnd ? const <JoinPoint>[] : _joinPoints.putIfAbsent(w.id, () => joinPoints(w.text)),
      ];
      // A tatweel adds less than its own width once the letters around it change form (about
      // 0.8 of it with Amiri Quran), so justify, shape, and correct by what it really added.
      var effectiveTatweel = tatweelWidth * 0.8;
      late LineJustification j;
      late double words;
      for (var attempt = 0; attempt < 3; attempt++) {
        j = justifyLine(
          wordWidths: naturalWidths,
          space: spaceWidth,
          tatweel: effectiveTatweel,
          points: points,
          target: target,
          centered: line.centered,
        );
        // Words with kashida are shaped again; the gap is then taken from their real widths.
        for (var k = 0; k < placed.length; k++) {
          final counts = j.tatweels[k];
          final text = withKashida(placed[k].word.text, counts);
          placed[k].painter = counts.isEmpty
              ? _wordPainters[placed[k].word.id]!
              : _stretchedPainters.putIfAbsent(text, () => _painter(text, style));
        }
        words = placed.fold<double>(0, (s, p) => s + p.painter.width);
        final count = j.tatweelCount;
        if (j.centered || count == 0) break;
        final gap = (target - words) / gaps;
        if (gap >= minGapFactor * spaceWidth && gap <= maxGapFactor * spaceWidth) break;
        final added = words - naturalWidths.fold<double>(0, (s, w) => s + w);
        if (added <= 0) break;
        effectiveTatweel = added / count;
      }
      final gap = !j.centered && j.tatweelCount > 0 ? (target - words) / gaps : j.gap;
      final scale = j.scale;
      final used = (words + gaps * gap) * scale;
      // RTL: words run from the right edge leftwards.
      var x = block.right - (block.width - used) / 2;
      for (final p in placed) {
        x -= p.painter.width * scale;
        p.x = x;
        x -= gap * scale;
      }
      _placements.add(_LinePlacement(line, top, lineHeight, placed, scale, gap, natural)
        ..report = LineReport(
          line: line.line,
          width: used,
          target: target,
          gap: gap,
          space: spaceWidth,
          scale: scale,
          centered: j.centered,
          overGap: !j.centered && gap > maxGapFactor * spaceWidth + 1e-6,
          tatweels: j.tatweelCount,
        ));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final geometry = _geometry!;
    final palette = _config.palette;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    for (final line in _placements) {
      switch (line.line.type) {
        case LineType.surahName:
          _paintSurahHeader(canvas, line, geometry);
        case LineType.basmallah:
          _paintCentered(canvas, line, basmalaText, geometry.fontSize * 0.92, palette.accentInk);
        case LineType.ayah:
          _paintAyahLine(canvas, line, geometry);
      }
    }
    final details = _details;
    if (details != null) {
      for (final d in [details.surah, details.juz, details.page]) {
        d.painter.paint(canvas, d.offset);
      }
    }
    canvas.restore();
  }

  /// Lays out the page details in the header and footer bands (contract › Page geometry, 5).
  void _layoutDetails(PageGeometry geometry) {
    _disposeDetails();
    final details = _config.details;
    if (details == null) return;
    final style = TextStyle(
      fontFamily: TypeScale.quranFamily,
      fontSize: geometry.lineHeight * PageGeometry.detailTextLines,
      color: _config.palette.accentInk,
    );
    final header = geometry.headerBand, footer = geometry.footerBand;
    _Detail detail(String text, double Function(double width) left, Rect band) {
      final p = _painter(text, style);
      return _Detail(text, p, Offset(left(p.width), band.center.dy - p.height / 2));
    }

    _details = (
      surah: detail('سورة ${details.surahName}', (w) => header.right - w, header),
      juz: detail('الجزء ${toEasternArabic(details.juz)}', (_) => header.left, header),
      page: detail(toEasternArabic(_config.page.number), (w) => footer.center.dx - w / 2, footer),
    );
  }

  void _disposeDetails() {
    final d = _details;
    if (d == null) return;
    for (final x in [d.surah, d.juz, d.page]) {
      x.painter.dispose();
    }
    _details = null;
  }

  void _paintAyahLine(Canvas canvas, _LinePlacement line, PageGeometry geometry) {
    final palette = _config.palette;
    // Selection and jump highlight behind the words of that ayah.
    for (final (ref, color) in [
      (_config.highlighted, palette.highlight),
      (_config.selected, palette.selection),
    ]) {
      if (ref == null) continue;
      final rects = [for (final w in line.words) if (w.word.ref == ref) line.wordRect(w)];
      if (rects.isEmpty) continue;
      final r = rects.reduce((a, b) => a.expandToInclude(b)).inflate(geometry.fontSize * 0.12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(geometry.fontSize * 0.3)),
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
          fontSize: geometry.fontSize * 0.7,
          color: palette.accentInk,
        ));
        // Start-side (right) margin of the right-to-left page.
        p.paint(canvas, Offset(
          geometry.textBlock.right + (size.width - geometry.textBlock.right - p.width) / 2,
          line.top + (line.height - p.height) / 2,
        ));
        p.dispose();
      }
    }
  }

  void _paintSurahHeader(Canvas canvas, _LinePlacement line, PageGeometry geometry) {
    final rect = Rect.fromLTWH(
      geometry.textBlock.left,
      line.top + line.height * 0.12,
      geometry.textBlock.width,
      line.height * 0.76,
    );
    paintSurahFrame(canvas, rect, _config.palette.accentInk);
    final name = _config.surahNames[line.line.surah] ?? '';
    _paintCentered(canvas, line, 'سُورَةُ $name', geometry.fontSize * 0.8, _config.palette.accentInk);
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
    for (final p in [..._wordPainters.values, ..._stretchedPainters.values]) {
      p.dispose();
    }
    _wordPainters.clear();
    _stretchedPainters.clear();
  }

  @override
  void dispose() {
    _disposePainters();
    _disposeDetails();
    super.dispose();
  }
}

class _Detail {
  _Detail(this.text, this.painter, this.offset);
  final String text;
  final TextPainter painter;
  final Offset offset;
}

class _PlacedWord {
  _PlacedWord(this.word, this.painter);
  final Word word;
  TextPainter painter; // natural, or with kashida
  double x = 0;
}

/// How one ayah line was set (for tests).
@immutable
class LineReport {
  const LineReport({
    required this.line,
    required this.width,
    required this.target,
    required this.gap,
    required this.space,
    required this.scale,
    required this.centered,
    required this.overGap,
    required this.tatweels,
  });

  final int line; // 1..15
  final double width; // as drawn
  final double target; // the width justified lines are filled to
  final double gap; // between words, before scale
  final double space; // a normal space
  final double scale;
  final bool centered;
  final bool overGap; // ran out of join points; gap wider than 1.5 × space
  final int tatweels;
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
  LineReport? report;

  Rect wordRect(_PlacedWord w) => Rect.fromLTWH(
        w.x,
        top + (height - w.painter.height * scale) / 2,
        w.painter.width * scale,
        w.painter.height * scale,
      );
}
