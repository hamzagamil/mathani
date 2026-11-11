import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../data/models.dart';
import '../../data/quran_repository.dart';
import '../../shared/numerals.dart';
import '../../shared/reader_state.dart';
import '../memorization/memorization_controller.dart';
import '../onboarding/onboarding_controller.dart';
import '../recitation/recitation_controller.dart';
import '../recitation/recited_item.dart';
import 'mushaf_page_renderer.dart';
import 'page_geometry.dart';
import 'paper_sheet.dart';
import 'printed_fonts.dart';

/// The size of the whole screen, or of the browser window around the web's phone column
/// (specs/012 research R1, R7). `PhoneColumn` provides it, since it narrows [MediaQuery];
/// elsewhere the [MediaQuery] size is the screen.
class ScreenArea extends InheritedWidget {
  const ScreenArea({super.key, required this.size, required super.child});

  final Size size;

  static Size sizeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScreenArea>()?.size ?? MediaQuery.sizeOf(context);

  @override
  bool updateShouldNotify(ScreenArea oldWidget) => oldWidget.size != size;
}

/// Whether the screen has room for two facing Mushaf pages (specs/012 FR-001), whatever the
/// layout and the setting: Settings offers the switch only then (FR-017).
bool spreadFitsScreen(BuildContext context) => PageGeometry.spreadFits(ScreenArea.sizeOf(context));

/// Whether the Mushaf shows two facing pages: the Mushaf layout, the setting on, and room for
/// them. The one place this is decided, so the view, the header, the bookmark button, the
/// keyboard and the web column always agree (specs/012 contracts/two-page-ui.md › Decision).
bool showsSpread(BuildContext context) {
  final reader = ReaderScope.maybeOf(context);
  return reader != null &&
      reader.layout == ReadingLayout.mushaf &&
      reader.preferences.twoPages &&
      spreadFitsScreen(context);
}

/// Whether the Mushaf page is drawn at the screen's full width and scrolls up and down: a phone
/// turned sideways (specs/013 research R4). Never where two pages fit, whatever the setting, and
/// never in a browser. It reads the whole screen, so bars coming and going never flip it. The
/// one place this is decided.
bool scrollsPage(BuildContext context) {
  if (kIsWeb) return false;
  final reader = ReaderScope.maybeOf(context);
  if (reader == null || reader.layout != ReadingLayout.mushaf) return false;
  final screen = ScreenArea.sizeOf(context);
  return screen.width > screen.height && !PageGeometry.spreadFits(screen);
}

/// The 604-page Mushaf layout. Always right-to-left, so the next page lies to the left and the
/// reader swipes from left to right to move forward (FR-004), in both interface languages.
///
/// It has three forms. When [showsSpread], two facing pages, 1–2 to 603–604, the odd page on the
/// right, and a swipe turns both (specs/012). When [scrollsPage], one page at the screen's full
/// width, which scrolls up and down (specs/013). Otherwise one whole page.
class MushafView extends StatefulWidget {
  const MushafView({super.key, this.onAyahLongPress, this.onTapPage, this.onPageTurned});

  /// Called with the ayah under a long press (FR-020); null disables selection.
  final void Function(AyahRef ref)? onAyahLongPress;

  /// Called on a tap that does not clear a selection: shows or hides the reader controls.
  final VoidCallback? onTapPage;

  /// Called when the reader turns to another page.
  final VoidCallback? onPageTurned;

  @override
  State<MushafView> createState() => _MushafViewState();
}

class _MushafViewState extends State<MushafView> {
  late final ReaderController _reader = ReaderScope.read(context);
  late _PageCache _cache = _PageCache(_reader.quran, printed: _printed(_reader));
  late int _handledJump = _reader.jumpSerial;

  /// The controller of the current mode's [PageView], replaced when the mode changes.
  PageController? _pages;

  /// Whether the current mode is two facing pages (specs/012).
  bool _spread = false;

  /// Set around the page jump that follows the recitation, so it does not hide the reader
  /// controls the way a page turn does (specs/004 recitation-playback › Following).
  bool _followJumpInFlight = false;

  /// Whether pages use the printed lettering (the setting, when the page fonts are bundled).
  static bool _printed(ReaderController r) =>
      r.preferences.lettering == Lettering.printed && r.quran.hasPrintedLettering;

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  /// The [PageView] index that shows [page] in the current mode.
  int _indexOf(int page) => _spread ? PageGeometry.spreadIndex(page) : page - 1;

  /// Loads the pages on screen and their neighbours, so a turn never shows an empty frame.
  void _prefetch(int page) => _spread
      ? _cache.prefetchSpread(PageGeometry.spreadRightPage(page))
      : _cache.prefetchAround(page);

  /// The controller for one or two pages, made at the reader's page when the mode changes. The
  /// keyed [PageView] is replaced, which cancels a swipe in progress, and a new controller reports
  /// no page change, so the reader's place is kept (specs/012 FR-011).
  PageController _controllerFor(bool spread, ReaderController reader) {
    final current = _pages;
    if (current != null && _spread == spread) return current;
    _spread = spread;
    var page = reader.page;
    if (current != null) {
      // The old view still holds it until this frame is built.
      WidgetsBinding.instance.addPostFrameCallback((_) => current.dispose());
      // From two pages to one: the page of the selected or highlighted ayah when it is on the
      // spread, else the reader's page (FR-010, FR-011).
      final keep = reader.selected ?? reader.highlighted;
      final keepPage = keep == null ? null : reader.quran.pageOf(keep);
      if (!spread &&
          keepPage != null &&
          keepPage != page &&
          PageGeometry.spreadRightPage(keepPage) == PageGeometry.spreadRightPage(page)) {
        page = keepPage;
        WidgetsBinding.instance.addPostFrameCallback((_) => reader.onMushafPageShown(keepPage));
      }
    }
    _prefetch(page);
    return _pages = PageController(initialPage: _indexOf(page));
  }

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    if (_printed(reader) != _cache.printed) {
      _cache = _PageCache(reader.quran, printed: _printed(reader));
      if (_pages != null) _prefetch(reader.page);
    }
    final pages = _controllerFor(showsSpread(context), reader);
    // No page turns under the onboarding's button hints; the latest jump applies when they end
    // (specs/005, FR-017a).
    if (reader.jumpSerial != _handledJump && !OnboardingScope.holdsReaderOf(context)) {
      _handledJump = reader.jumpSerial;
      // With two pages, a jump to the other page of the spread on screen does not turn
      // (specs/012 FR-009).
      final target = _indexOf(reader.page);
      final follow = RecitationScope.read(context)?.followSerial == reader.jumpSerial;
      _prefetch(reader.page);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!identical(pages, _pages)) return; // the mode changed: the new view opens at the page
        if (pages.hasClients && pages.page?.round() != target) {
          _followJumpInFlight = follow;
          pages.jumpToPage(target); // onPageChanged runs inside this call
          _followJumpInFlight = false;
        }
      });
    }
    Widget page(int number, {required bool bindingOnRight}) => _MushafPageItem(
          key: ValueKey((_cache.printed, number - 1)),
          page: number,
          bindingOnRight: bindingOnRight,
          cache: _cache,
          onAyahLongPress: widget.onAyahLongPress,
          onTapPage: widget.onTapPage,
          onScrolledByReader: widget.onPageTurned,
        );
    return Directionality(
      textDirection: TextDirection.rtl,
      child: _spread
          ? PageView.builder(
              key: const ValueKey(true),
              controller: pages,
              itemCount: PageGeometry.spreadCount,
              allowImplicitScrolling: true, // keeps the neighbouring spreads laid out (SC-004)
              onPageChanged: (i) {
                final right = 2 * i + 1;
                _cache.prefetchSpread(right);
                reader.onMushafSpreadShown(right);
                if (!_followJumpInFlight) widget.onPageTurned?.call();
              },
              // Right to left: the odd page on the right, the binding shades meeting in the middle.
              itemBuilder: (context, i) => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: page(2 * i + 1, bindingOnRight: false)),
                  Expanded(child: page(2 * i + 2, bindingOnRight: true)),
                ],
              ),
            )
          : PageView.builder(
              key: const ValueKey(false),
              controller: pages,
              itemCount: QuranRepository.pageCount,
              allowImplicitScrolling: true, // keeps n±1 laid out (SC-002)
              onPageChanged: (i) {
                _cache.prefetchAround(i + 1);
                reader.onMushafPageShown(i + 1);
                if (!_followJumpInFlight) widget.onPageTurned?.call();
              },
              itemBuilder: (context, i) => page(i + 1, bindingOnRight: (i + 1).isOdd),
            ),
    );
  }
}

class _MushafPageItem extends StatefulWidget {
  const _MushafPageItem({
    super.key,
    required this.page,
    required this.bindingOnRight,
    required this.cache,
    this.onAyahLongPress,
    this.onTapPage,
    this.onScrolledByReader,
  });

  final int page;

  /// Side of the binding shade: the right for an odd page shown alone, the inner edge in a
  /// spread (specs/012 FR-006).
  final bool bindingOnRight;
  final _PageCache cache;
  final void Function(AyahRef ref)? onAyahLongPress;
  final VoidCallback? onTapPage;

  /// Called when the reader starts scrolling the sideways page: hides the controls, like a
  /// page turn.
  final VoidCallback? onScrolledByReader;

  @override
  State<_MushafPageItem> createState() => _MushafPageItemState();
}

class _MushafPageItemState extends State<_MushafPageItem> {
  final _rendererKey = GlobalKey();
  _CachedPage? _page;

  /// The page could not load: in a browser, its font has not been fetched yet and there is no
  /// connection (specs/008 US4 scenario 2).
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _page = widget.cache.peek(widget.page);
    if (_page == null) _load();
  }

  void _load() {
    widget.cache.load(widget.page).then((p) {
      if (mounted) setState(() => _page = p);
    }, onError: (Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  /// The sideways page's scroll position (specs/013). Unused while the whole page shows.
  final _scroll = ScrollController();

  /// The follow target last brought on screen, so each is handled once.
  Object? _followed;

  /// Whether the sideways page has been on screen with its text: later follows animate.
  bool _shown = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    final page = _buildPage(context, reader);
    if (!scrollsPage(context)) {
      _followed = null;
      _shown = false;
      return page;
    }
    _syncScroll(context, reader);
    return LayoutBuilder(
      builder: (context, constraints) => NotificationListener<ScrollStartNotification>(
        onNotification: (n) {
          if (n.dragDetails != null) widget.onScrolledByReader?.call();
          return false;
        },
        child: SingleChildScrollView(
          controller: _scroll,
          // Stops at the page's top and bottom (FR-008); a bounce would fight the page swipe.
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            height: PageGeometry.scrollPageHeight(constraints.maxWidth),
            // A scroll replays the page's picture instead of painting it again.
            child: RepaintBoundary(child: page),
          ),
        ),
      ),
    );
  }

  /// Keeps the sideways page where the reader expects it: at its top when it is not the page
  /// being read (FR-009), and with the recited, jumped-to or expected ayah on screen when it is
  /// (FR-011, contracts/reader-ui.md › Following).
  void _syncScroll(BuildContext context, ReaderController reader) {
    if (reader.page != widget.page) {
      _followed = null;
      _shown = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients && _scroll.offset != 0) _scroll.jumpTo(0);
      });
      return;
    }
    if (_page == null) return; // nothing to scroll to until the page has loaded
    final recited = RecitationScope.maybeOf(context)?.recited;
    final memorization = MemorizationScope.maybeOf(context);
    final Object? target = recited ??
        reader.highlighted ??
        (memorization != null && memorization.active ? memorization.expected : null);
    final animate = _shown;
    WidgetsBinding.instance.addPostFrameCallback((_) => _shown = mounted);
    if (target == _followed) return;
    _followed = target;
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _rendererKey.currentContext?.findRenderObject();
      if (!mounted || box is! RenderMushafPage || !_scroll.hasClients) return;
      final rect = switch (target) {
        RecitedItem(isBasmala: true, :final surah) => box.basmalaRect(surah),
        RecitedItem(:final ref) => box.ayahRect(ref),
        AyahRef() => box.ayahRect(target),
        _ => null,
      };
      if (rect == null) return;
      final position = _scroll.position;
      final top = position.pixels, bottom = top + position.viewportDimension;
      if (rect.top >= top && rect.bottom <= bottom) return;
      // One line of the page above the ayah.
      final line = (position.maxScrollExtent + position.viewportDimension) /
          (PageGeometry.linesPerPage + 2 * PageGeometry.bandLines + 1);
      final to = (rect.top - line).clamp(0.0, position.maxScrollExtent);
      if (animate) {
        _scroll.animateTo(to, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      } else {
        _scroll.jumpTo(to);
      }
    });
  }

  Widget _buildPage(BuildContext context, ReaderController reader) {
    final cached = _page;
    if (cached == null) {
      // Blank paper while the page (and its printed font) loads; taps still work.
      final l10n = AppLocalizations.of(context);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: reader.selected != null ? () => reader.select(null) : widget.onTapPage,
        child: PaperSheet(
          bindingOnRight: widget.bindingOnRight,
          child: !_failed
              ? const SizedBox.expand()
              : Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(l10n.pageNeedsConnection, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: () {
                        setState(() => _failed = false);
                        _load();
                      },
                      child: Text(l10n.retry),
                    ),
                  ]),
                ),
        ),
      );
    }
    final page = cached.page;
    final quran = reader.quran;
    final colors = MathaniColors.of(context);
    final l10n = AppLocalizations.of(context);
    final head = quran.firstAyahOnPage(page.number);
    final recited = RecitationScope.maybeOf(context)?.recited;
    final memorization = MemorizationScope.maybeOf(context);
    // No mutashabih colour while memorizing: the session has its own marks (specs/010 R4).
    final similar = memorization != null && memorization.active ? null : reader.similar;
    final linked = similar?.linkedOnPage([
      for (final line in page.lines)
        for (final w in line.words) w.ref,
    ]) ?? const <AyahRef>[];
    final locale = Localizations.localeOf(context);

    final onTapPage = widget.onTapPage;
    void pick(Offset globalPosition) {
      final box = _rendererKey.currentContext?.findRenderObject();
      if (box is! RenderMushafPage) return;
      final ref = box.ayahAt(box.globalToLocal(globalPosition));
      // During memorization the range's ayat have no actions (specs/006).
      final inSession = memorization != null &&
          memorization.active &&
          ref != null &&
          (memorization.range?.contains(ref) ?? false);
      if (ref != null && !inSession) widget.onAyahLongPress!(ref);
    }

    final pageLabel = l10n.pageSemantics(
      toEasternArabic(page.number),
      quran.surahList[head.surah - 1].nameAr,
    );
    return Semantics(
      // Screen readers hear which ayat on the page have similar ayat (specs/010 FR-004).
      label: linked.isEmpty
          ? pageLabel
          : '$pageLabel. ${l10n.similarOnPage(linked.map((r) => formatNumber(r.ayah, locale))
              .join(locale.languageCode == 'ar' ? '، ' : ', '))}',
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.showControls): ?onTapPage,
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // A tap clears a selection; otherwise it shows or hides the reader controls.
        onTap: reader.selected != null ? () => reader.select(null) : onTapPage,
        onLongPressStart:
            widget.onAyahLongPress == null ? null : (d) => pick(d.globalPosition),
        // A right-click does what a long press does (specs/008 FR-009).
        onSecondaryTapUp:
            widget.onAyahLongPress == null ? null : (d) => pick(d.globalPosition),
        child: PaperSheet(
          bindingOnRight: widget.bindingOnRight,
          child: MushafPageRenderer(
            key: _rendererKey,
            page: page,
            surahNames: {for (final s in quran.surahList) s.number: s.nameAr},
            targetEm: cached.glyphs != null ? quran.printedTargetEm : quran.justifyTargetEm,
            font: quran.font,
            palette: MushafPalette(
              ink: colors.ink,
              accentInk: colors.accentInk,
              highlight: colors.secondarySoft,
              selection: colors.selected,
              recited: colors.recited,
              hint: colors.hint,
              mistake: colors.mistake,
              similar: colors.similar,
            ),
            quarterStartWords: widget.cache.quarterStartWords(page.number),
            sajdahEndWords: widget.cache.sajdahEndWords(page.number),
            selected: reader.selected,
            highlighted: reader.highlighted,
            recited: recited == null || recited.isBasmala ? null : recited.ref,
            recitedBasmala: recited != null && recited.isBasmala ? recited.surah : null,
            marks: memorization == null || !memorization.active
                ? null
                : WordMarks(
                    hidden: memorization.isHidden,
                    hinted: memorization.isHinted,
                    mistake: memorization.hasMistake,
                    expected: memorization.expected,
                    revision: memorization.revision,
                  ),
            similar: similar,
            details: MushafPageDetails.of(quran, page.number),
            printedGlyphs: cached.glyphs,
            printedFamily: cached.family,
            surahHeaderFamily: cached.headerFamily,
            printedSpaceEm: quran.printedSpaceEm,
          ),
        ),
      ),
    );
  }
}

/// A page ready to draw: its lines, and for the printed lettering its glyphs and loaded font.
class _CachedPage {
  const _CachedPage(this.page, {this.glyphs, this.family, this.headerFamily});
  final MushafPage page;
  final Map<int, String>? glyphs;
  final String? family;

  /// The surah header font, when the page has a surah title and the font loaded.
  final String? headerFamily;
}

/// Small LRU cache of page data, with prefetching of the neighbouring pages so a page turn
/// never shows an empty frame (SC-002). With [printed], pages come with the printed edition's
/// lines, glyphs and page font (specs/002, User Story 4).
class _PageCache {
  _PageCache(this._quran, {required this.printed})
      : _quarterStarts = {
          for (final d in _quran.divisionList)
            if (d.kind == DivisionKind.hizbQuarter) d.start,
        };

  static const _capacity = 7;

  final QuranRepository _quran;
  final bool printed;
  final Set<AyahRef> _quarterStarts;
  final _pages = <int, _CachedPage>{}; // insertion-ordered: LRU
  final _loading = <int, Future<_CachedPage>>{};

  _CachedPage? peek(int page) {
    final p = _pages.remove(page);
    if (p != null) _pages[page] = p; // mark as recently used
    return p;
  }

  Future<_CachedPage> load(int page) {
    final cached = peek(page);
    if (cached != null) return Future.value(cached);
    return _loading[page] ??= _fetch(page).then((p) {
      _loading.remove(page);
      _pages[page] = p;
      while (_pages.length > _capacity) {
        _pages.remove(_pages.keys.first);
      }
      return p;
    }, onError: (Object e, StackTrace s) {
      _loading.remove(page); // the next load tries again
      return Future<_CachedPage>.error(e, s);
    });
  }

  Future<_CachedPage> _fetch(int page) async {
    if (!printed) {
      final lines = await _quran.page(page);
      return _CachedPage(lines, headerFamily: await _headers(lines));
    }
    final (lines, family) = await (_quran.page(page, printed: true), PrintedFonts.load(page)).wait;
    return _CachedPage(
      lines,
      glyphs: await _quran.printedGlyphs(lines),
      family: family,
      headerFamily: await _headers(lines),
    );
  }

  /// The printed surah header font for a page with a surah title, in either lettering. Without
  /// it the header is drawn as a plain frame, so a failed load never blocks the page.
  static Future<String?> _headers(MushafPage page) async {
    if (!page.lines.any((l) => l.type == LineType.surahName)) return null;
    try {
      return await PrintedFonts.loadHeaders();
    } catch (_) {
      return null;
    }
  }

  void prefetchAround(int page) => _prefetch([page, page + 1, page - 1, page + 2, page - 2]);

  /// The spread from the odd page [right] and the spreads either side: six pages, within
  /// [_capacity] (specs/012 research R2).
  void prefetchSpread(int right) =>
      _prefetch([right, right + 1, right + 2, right + 3, right - 1, right - 2]);

  void _prefetch(List<int> pages) {
    for (final p in pages) {
      if (p >= 1 && p <= QuranRepository.pageCount) load(p).ignore(); // the page shows errors
    }
  }

  Set<int> quarterStartWords(int page) => {
        for (final a in _quran.ayahsStartingOnPage(page))
          if (_quarterStarts.contains(a.ref)) a.firstWordId,
      };

  Set<int> sajdahEndWords(int page) => {
        for (final a in _quran.ayahsStartingOnPage(page))
          if (a.sajdah) a.lastWordId,
      };
}
