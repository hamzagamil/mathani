
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
import 'mushaf_page_renderer.dart';
import 'paper_sheet.dart';
import 'printed_fonts.dart';

/// The 604-page Mushaf layout. Always right-to-left, so the next page lies to the left and the
/// reader swipes from left to right to move forward (FR-004), in both interface languages.
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
  late final PageController _pages = PageController(initialPage: _reader.page - 1);
  late _PageCache _cache = _PageCache(_reader.quran, printed: _printed(_reader));
  late int _handledJump = _reader.jumpSerial;

  /// Set around the page jump that follows the recitation, so it does not hide the reader
  /// controls the way a page turn does (specs/004 recitation-playback › Following).
  bool _followJumpInFlight = false;

  @override
  void initState() {
    super.initState();
    _cache.prefetchAround(_reader.page);
  }

  /// Whether pages use the printed lettering (the setting, when the page fonts are bundled).
  static bool _printed(ReaderController r) =>
      r.preferences.lettering == Lettering.printed && r.quran.hasPrintedLettering;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    if (_printed(reader) != _cache.printed) {
      _cache = _PageCache(reader.quran, printed: _printed(reader))..prefetchAround(reader.page);
    }
    // No page turns under the onboarding's button hints; the latest jump applies when they end
    // (specs/005, FR-017a).
    if (reader.jumpSerial != _handledJump && !OnboardingScope.holdsReaderOf(context)) {
      _handledJump = reader.jumpSerial;
      final target = reader.page - 1;
      final follow = RecitationScope.read(context)?.followSerial == reader.jumpSerial;
      _cache.prefetchAround(reader.page);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pages.hasClients && _pages.page?.round() != target) {
          _followJumpInFlight = follow;
          _pages.jumpToPage(target); // onPageChanged runs inside this call
          _followJumpInFlight = false;
        }
      });
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PageView.builder(
        controller: _pages,
        itemCount: QuranRepository.pageCount,
        allowImplicitScrolling: true, // keeps n±1 laid out (SC-002)
        onPageChanged: (i) {
          _cache.prefetchAround(i + 1);
          reader.onMushafPageShown(i + 1);
          if (!_followJumpInFlight) widget.onPageTurned?.call();
        },
        itemBuilder: (context, i) => _MushafPageItem(
          key: ValueKey((_cache.printed, i)),
          page: i + 1,
          cache: _cache,
          onAyahLongPress: widget.onAyahLongPress,
          onTapPage: widget.onTapPage,
        ),
      ),
    );
  }
}

class _MushafPageItem extends StatefulWidget {
  const _MushafPageItem({
    super.key,
    required this.page,
    required this.cache,
    this.onAyahLongPress,
    this.onTapPage,
  });

  final int page;
  final _PageCache cache;
  final void Function(AyahRef ref)? onAyahLongPress;
  final VoidCallback? onTapPage;

  @override
  State<_MushafPageItem> createState() => _MushafPageItemState();
}

class _MushafPageItemState extends State<_MushafPageItem> {
  final _rendererKey = GlobalKey();
  _CachedPage? _page;

  @override
  void initState() {
    super.initState();
    _page = widget.cache.peek(widget.page);
    if (_page == null) {
      widget.cache.load(widget.page).then((p) {
        if (mounted) setState(() => _page = p);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    final cached = _page;
    if (cached == null) {
      // Blank paper while the page (and its printed font) loads; taps still work.
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: reader.selected != null ? () => reader.select(null) : widget.onTapPage,
        child: PaperSheet(bindingOnRight: widget.page.isOdd, child: const SizedBox.expand()),
      );
    }
    final page = cached.page;
    final quran = reader.quran;
    final colors = MathaniColors.of(context);
    final l10n = AppLocalizations.of(context);
    final head = quran.firstAyahOnPage(page.number);
    final recited = RecitationScope.maybeOf(context)?.recited;
    final memorization = MemorizationScope.maybeOf(context);

    final onTapPage = widget.onTapPage;
    return Semantics(
      label: l10n.pageSemantics(
        toEasternArabic(page.number),
        quran.surahList[head.surah - 1].nameAr,
      ),
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.showControls): ?onTapPage,
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // A tap clears a selection; otherwise it shows or hides the reader controls.
        onTap: reader.selected != null ? () => reader.select(null) : onTapPage,
        onLongPressStart: widget.onAyahLongPress == null
            ? null
            : (d) {
                final box = _rendererKey.currentContext?.findRenderObject();
                if (box is! RenderMushafPage) return;
                final ref = box.ayahAt(box.globalToLocal(d.globalPosition));
                // During memorization the range's ayat have no actions (specs/006).
                final inSession = memorization != null &&
                    memorization.active &&
                    ref != null &&
                    (memorization.range?.contains(ref) ?? false);
                if (ref != null && !inSession) widget.onAyahLongPress!(ref);
              },
        child: PaperSheet(
          bindingOnRight: page.number.isOdd,
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
            details: MushafPageDetails.of(quran, page.number),
            printedGlyphs: cached.glyphs,
            printedFamily: cached.family,
            printedSpaceEm: quran.printedSpaceEm,
          ),
        ),
      ),
    );
  }
}

/// A page ready to draw: its lines, and for the printed lettering its glyphs and loaded font.
class _CachedPage {
  const _CachedPage(this.page, [this.glyphs, this.family]);
  final MushafPage page;
  final Map<int, String>? glyphs;
  final String? family;
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
    });
  }

  Future<_CachedPage> _fetch(int page) async {
    if (!printed) return _CachedPage(await _quran.page(page));
    final (lines, family) = await (_quran.page(page, printed: true), PrintedFonts.load(page)).wait;
    return _CachedPage(lines, await _quran.printedGlyphs(lines), family);
  }

  void prefetchAround(int page) {
    for (final p in [page, page + 1, page - 1, page + 2, page - 2]) {
      if (p >= 1 && p <= QuranRepository.pageCount) load(p);
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
