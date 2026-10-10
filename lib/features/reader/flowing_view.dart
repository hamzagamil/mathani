import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../data/quran_repository.dart';
import '../../shared/numerals.dart';
import '../../shared/quran_text.dart';
import '../../shared/reader_state.dart';
import 'surah_header_painter.dart';

/// The flowing layout (research R5): continuous text at the reader's chosen size, one list item
/// per Mushaf page. The list is centred on the target page (pages before it grow upwards), so a
/// jump to any page is instant; the exact ayah is then revealed from the paragraph layout.
class FlowingView extends StatefulWidget {
  const FlowingView({super.key, this.onAyahLongPress});

  final void Function(AyahRef ref)? onAyahLongPress;

  @override
  State<FlowingView> createState() => _FlowingViewState();
}

class _FlowingViewState extends State<FlowingView> {
  late final ReaderController _reader = ReaderScope.read(context);
  late int _centerPage = _reader.page;
  Key _centerKey = UniqueKey();
  ScrollController _scroll = ScrollController();
  late int _handledJump = _reader.jumpSerial;
  late AyahRef? _reveal = _reader.anchor;
  final _data = <int, List<(Ayah, List<Word>)>>{};
  final _paragraphs = <int, _PageParagraphs>{}; // built pages → their paragraphs
  late double _fontSize = _reader.preferences.flowFontSize.toDouble();

  /// Set while we scroll programmatically; the resulting scroll-end must not move the anchor.
  bool _programmatic = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealPending());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<List<(Ayah, List<Word>)>> _load(int page) async =>
      _data[page] ??= await _reader.quran.flowingPage(page);

  /// Scrolls so the pending ayah sits at the top of the viewport.
  void _revealPending({int attempts = 20}) {
    final ref = _reveal;
    if (ref == null || !mounted) return;
    final target = _locate(ref);
    if (target == null) {
      // The page's data or layout is not ready yet; try again next frame.
      if (attempts > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _revealPending(attempts: attempts - 1));
      }
      return;
    }
    final (paragraph, caret) = target;
    final viewport = RenderAbstractViewport.of(paragraph);
    final offset = viewport.getOffsetToReveal(paragraph, 0, rect: caret).offset;
    final to = offset.clamp(_scroll.position.minScrollExtent, _scroll.position.maxScrollExtent);
    if (to != _scroll.position.pixels) {
      _programmatic = true; // a jump that moves fires one scroll-end
      _scroll.jumpTo(to);
    }
    _reveal = null;
  }

  /// The paragraph containing [ref] and the caret rect of the ayah's first character.
  (RenderParagraph, Rect)? _locate(AyahRef ref) {
    final page = _reader.quran.pageOf(ref);
    final entry = _paragraphs[page]?.ayahStarts[ref];
    if (entry == null) return null;
    final render = entry.key.currentContext?.findRenderObject();
    if (render is! RenderParagraph || !render.hasSize) return null;
    final caret = render.getOffsetForCaret(TextPosition(offset: entry.offset), Rect.zero);
    return (render, Rect.fromLTWH(0, caret.dy, render.size.width, 1));
  }

  /// After scrolling settles, the anchor becomes the first ayah visible at the top (R6).
  void _updateTopAyah() {
    final top = (context.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero).dy;
    if (top == null) return;
    final probeY = top + 8;
    for (final page in _paragraphs.values) {
      for (final p in page.paragraphs) {
        final render = p.key.currentContext?.findRenderObject();
        if (render is! RenderParagraph || !render.attached || !render.hasSize) continue;
        final origin = render.localToGlobal(Offset.zero);
        if (probeY < origin.dy || probeY > origin.dy + render.size.height) continue;
        // The first ayah that starts on or after the top line; if none starts there, the ayah
        // that line continues. Matches how a reveal places an ayah, so toggling never drifts.
        // Right-to-left: the right edge of the top line is its logical start.
        final lineStart = render
            .getPositionForOffset(Offset(render.size.width - 1, probeY - origin.dy))
            .offset;
        AyahRef? found;
        for (final (ref, start) in p.starts) {
          if (start < lineStart) {
            found = ref;
          } else {
            found = ref;
            break;
          }
        }
        if (found != null) _reader.onFlowingTopAyah(found);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    if (reader.jumpSerial != _handledJump) {
      _handledJump = reader.jumpSerial;
      // Re-centre the list on the target page and reveal the ayah after layout.
      _centerPage = reader.page;
      _centerKey = UniqueKey();
      _reveal = reader.anchor;
      _scroll.dispose();
      _scroll = ScrollController();
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealPending());
    }
    final fontSize = reader.preferences.flowFontSize.toDouble();
    if (fontSize != _fontSize) {
      // Text reflows at the new size: keep the reader on the same ayah.
      _fontSize = fontSize;
      _reveal = reader.anchor;
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealPending());
    }

    Widget item(int page) => _FlowingPage(
          key: ValueKey(page),
          page: page,
          load: _load,
          fontSize: fontSize,
          onAyahLongPress: widget.onAyahLongPress,
          register: (paragraphs) => _paragraphs[page] = paragraphs,
          unregister: () => _paragraphs.remove(page),
        );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (_) {
          if (_programmatic) {
            _programmatic = false;
          } else {
            // Read positions after the scroll has been laid out.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _updateTopAyah();
            });
          }
          return false;
        },
        child: CustomScrollView(
          controller: _scroll,
          center: _centerKey,
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => item(_centerPage - 1 - i),
                childCount: _centerPage - 1,
              ),
            ),
            SliverList(
              key: _centerKey,
              delegate: SliverChildBuilderDelegate(
                (context, i) => item(_centerPage + i),
                childCount: QuranRepository.pageCount - _centerPage + 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paragraph keys of one page and, per ayah, where it starts in its paragraph's text.
class _PageParagraphs {
  _PageParagraphs(this.paragraphs)
      : ayahStarts = {
          for (final p in paragraphs)
            for (final (ref, start) in p.starts) ref: (key: p.key, offset: start),
        };

  final List<_Paragraph> paragraphs;
  final Map<AyahRef, ({GlobalKey key, int offset})> ayahStarts;
}

class _Paragraph {
  _Paragraph(this.key, this.starts);
  final GlobalKey key;
  final List<(AyahRef, int)> starts; // ayah → character offset of its first word
}

class _FlowingPage extends StatefulWidget {
  const _FlowingPage({
    super.key,
    required this.page,
    required this.load,
    required this.fontSize,
    required this.register,
    required this.unregister,
    this.onAyahLongPress,
  });

  final int page;
  final Future<List<(Ayah, List<Word>)>> Function(int page) load;
  final double fontSize;
  final void Function(_PageParagraphs) register;
  final VoidCallback unregister;
  final void Function(AyahRef ref)? onAyahLongPress;

  @override
  State<_FlowingPage> createState() => _FlowingPageState();
}

class _FlowingPageState extends State<_FlowingPage> {
  List<(Ayah, List<Word>)>? _ayahs;
  final _recognizers = <LongPressGestureRecognizer>[];

  @override
  void initState() {
    super.initState();
    widget.load(widget.page).then((a) {
      if (mounted) setState(() => _ayahs = a);
    });
  }

  @override
  void dispose() {
    widget.unregister();
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ayahs = _ayahs;
    if (ayahs == null) return SizedBox(height: widget.fontSize * 2 * 15);
    final reader = ReaderScope.of(context);
    final colors = MathaniColors.of(context);
    final quran = reader.quran;
    final style = TextStyle(
      fontFamily: TypeScale.quranFamily,
      fontSize: widget.fontSize,
      height: TypeScale.quranLineHeight,
      color: colors.ink,
    );
    _disposeRecognizers();

    // Split into runs at surah starts; each run is one paragraph after its surah header.
    final children = <Widget>[];
    final paragraphs = <_Paragraph>[];
    var run = <(Ayah, List<Word>)>[];

    void flush() {
      if (run.isEmpty) return;
      final key = GlobalKey();
      final spans = <InlineSpan>[];
      final starts = <(AyahRef, int)>[];
      var length = 0;
      for (final (ayah, words) in run) {
        starts.add((ayah.ref, length));
        final text = StringBuffer();
        for (final w in words) {
          text
            ..write(w.isAyahEnd ? ayahEndGlyphs(w.text, quran.font) : w.text)
            ..write(' ');
        }
        final background = ayah.ref == reader.selected
            ? colors.selected
            : ayah.ref == reader.highlighted
                ? colors.secondarySoft
                : null;
        LongPressGestureRecognizer? recognizer;
        if (widget.onAyahLongPress != null) {
          recognizer = LongPressGestureRecognizer()
            ..onLongPress = () => widget.onAyahLongPress!(ayah.ref);
          _recognizers.add(recognizer);
        }
        final s = text.toString();
        spans.add(TextSpan(
          text: s,
          recognizer: recognizer,
          style: background == null ? null : TextStyle(backgroundColor: background),
        ));
        length += s.length;
      }
      paragraphs.add(_Paragraph(key, starts));
      children.add(RichText(
        key: key,
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
        textScaler: TextScaler.noScaling, // size comes from the in-app setting (FR-017)
        text: TextSpan(style: style, children: spans),
      ));
      run = [];
    }

    for (final entry in ayahs) {
      final ayah = entry.$1;
      if (ayah.ayah == 1) {
        flush();
        children.add(_SurahHeader(
          name: quran.surahList[ayah.surah - 1].nameAr,
          fontSize: widget.fontSize,
          color: colors.accentInk,
        ));
        if (ayah.surah != 1 && ayah.surah != 9) {
          children.add(Center(
            child: Text(
              basmalaText,
              textScaler: TextScaler.noScaling,
              style: style.copyWith(color: colors.accentInk, fontSize: widget.fontSize * 0.92),
            ),
          ));
        }
      }
      run.add(entry);
    }
    flush();
    widget.register(_PageParagraphs(paragraphs));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...children,
          // Page boundary with the printed Mushaf page number (R5).
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.s2),
            child: Row(
              children: [
                Expanded(child: Divider(color: colors.line)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.s3),
                  child: Text(
                    toEasternArabic(widget.page),
                    style: TypeScale.caption.copyWith(color: colors.inkMuted),
                  ),
                ),
                Expanded(child: Divider(color: colors.line)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SurahHeader extends StatelessWidget {
  const _SurahHeader({required this.name, required this.fontSize, required this.color});
  final String name;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final height = fontSize * 2.2;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s2),
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: _FramePainter(color),
          child: Center(
            child: Text(
              'سُورَةُ $name',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: TypeScale.quranFamily,
                fontSize: fontSize * 0.8,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      paintSurahFrame(canvas, (Offset.zero & size).deflate(size.height * 0.1), color);

  @override
  bool shouldRepaint(_FramePainter old) => old.color != color;
}
