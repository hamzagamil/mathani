
import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../data/models.dart';
import '../../data/quran_repository.dart';
import '../../shared/numerals.dart';
import '../../shared/reader_state.dart';
import 'mushaf_page_renderer.dart';

/// The 604-page Mushaf layout. Always right-to-left, so the next page lies to the left and the
/// reader swipes from left to right to move forward (FR-004), in both interface languages.
class MushafView extends StatefulWidget {
  const MushafView({super.key, this.onAyahLongPress});

  /// Called with the ayah under a long press (FR-020); null disables selection.
  final void Function(AyahRef ref)? onAyahLongPress;

  @override
  State<MushafView> createState() => _MushafViewState();
}

class _MushafViewState extends State<MushafView> {
  late final ReaderController _reader = ReaderScope.read(context);
  late final PageController _pages = PageController(initialPage: _reader.page - 1);
  late final _PageCache _cache = _PageCache(_reader.quran);
  late int _handledJump = _reader.jumpSerial;

  @override
  void initState() {
    super.initState();
    _cache.prefetchAround(_reader.page);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    if (reader.jumpSerial != _handledJump) {
      _handledJump = reader.jumpSerial;
      final target = reader.page - 1;
      _cache.prefetchAround(reader.page);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pages.hasClients && _pages.page?.round() != target) _pages.jumpToPage(target);
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
        },
        itemBuilder: (context, i) => _MushafPageItem(
          page: i + 1,
          cache: _cache,
          onAyahLongPress: widget.onAyahLongPress,
        ),
      ),
    );
  }
}

class _MushafPageItem extends StatefulWidget {
  const _MushafPageItem({required this.page, required this.cache, this.onAyahLongPress});

  final int page;
  final _PageCache cache;
  final void Function(AyahRef ref)? onAyahLongPress;

  @override
  State<_MushafPageItem> createState() => _MushafPageItemState();
}

class _MushafPageItemState extends State<_MushafPageItem> {
  final _rendererKey = GlobalKey();
  MushafPage? _page;

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
    final page = _page;
    if (page == null) return const SizedBox.expand(); // only before the very first load
    final reader = ReaderScope.of(context);
    final quran = reader.quran;
    final colors = MathaniColors.of(context);
    final l10n = AppLocalizations.of(context);
    final head = quran.firstAyahOnPage(page.number);

    return Semantics(
      label: l10n.pageSemantics(
        toEasternArabic(page.number),
        quran.surahList[head.surah - 1].nameAr,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: reader.selected == null ? null : () => reader.select(null),
        onLongPressStart: widget.onAyahLongPress == null
            ? null
            : (d) {
                final box = _rendererKey.currentContext?.findRenderObject();
                if (box is! RenderMushafPage) return;
                final ref = box.ayahAt(box.globalToLocal(d.globalPosition));
                if (ref != null) widget.onAyahLongPress!(ref);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: MushafPageRenderer(
            key: _rendererKey,
            page: page,
            surahNames: {for (final s in quran.surahList) s.number: s.nameAr},
            lineWidthEm: quran.p98LineWidthEm,
            font: quran.font,
            palette: MushafPalette(
              ink: colors.ink,
              accentInk: colors.accentInk,
              highlight: colors.secondarySoft,
              selection: colors.selected,
            ),
            quarterStartWords: widget.cache.quarterStartWords(page.number),
            sajdahEndWords: widget.cache.sajdahEndWords(page.number),
            selected: reader.selected,
            highlighted: reader.highlighted,
          ),
        ),
      ),
    );
  }
}

/// Small LRU cache of page data, with prefetching of the neighbouring pages so a page turn
/// never shows an empty frame (SC-002).
class _PageCache {
  _PageCache(this._quran)
      : _quarterStarts = {
          for (final d in _quran.divisionList)
            if (d.kind == DivisionKind.hizbQuarter) d.start,
        };

  static const _capacity = 7;

  final QuranRepository _quran;
  final Set<AyahRef> _quarterStarts;
  final _pages = <int, MushafPage>{}; // insertion-ordered: LRU
  final _loading = <int, Future<MushafPage>>{};

  MushafPage? peek(int page) {
    final p = _pages.remove(page);
    if (p != null) _pages[page] = p; // mark as recently used
    return p;
  }

  Future<MushafPage> load(int page) {
    final cached = peek(page);
    if (cached != null) return Future.value(cached);
    return _loading[page] ??= _quran.page(page).then((p) {
      _loading.remove(page);
      _pages[page] = p;
      while (_pages.length > _capacity) {
        _pages.remove(_pages.keys.first);
      }
      return p;
    });
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
