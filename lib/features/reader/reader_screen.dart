import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../data/quran_repository.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/numerals.dart';
import '../../shared/reader_state.dart';
import '../index/index_screen.dart';
import '../memorization/memorization_bar.dart';
import '../memorization/memorization_controller.dart';
import '../memorization/memorization_score.dart';
import '../memorization/range_sheet.dart';
import '../memorization/result_screen.dart';
import '../onboarding/button_tour.dart';
import '../onboarding/onboarding_controller.dart';
import '../recitation/download_queue.dart';
import '../recitation/recitation_bar.dart';
import '../recitation/recitation_controller.dart';
import '../recitation/reciter_sheet.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import 'ayah_actions.dart';
import 'flowing_view.dart';
import 'mushaf_view.dart';

/// Home screen: the Mushaf (page or flowing layout), a header showing the current surah, juz
/// and page (FR-008), and a bottom toolbar within one-handed reach (constitution II). Toolbar
/// actions appear only for features that exist (FR-028).
///
/// In the Mushaf layout the page fills the screen like a sheet of paper, and the header and
/// toolbar appear over it on a tap (specs/002-print-like-mushaf-page/contracts/
/// reader-page-view.md). The flowing layout keeps them in place.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  static const _slide = Duration(milliseconds: 200);

  bool? _wakelock;
  bool _controlsVisible = true;
  bool _immersive = false;

  /// The controls the onboarding's button hints point at (specs/005).
  final _targets = TourTargets();

  @override
  void initState() {
    super.initState();
    // Right-click opens the ayah actions over the Mushaf instead of the browser's menu
    // (specs/008 research R12).
    if (kIsWeb) BrowserContextMenu.disableContextMenu();
  }

  @override
  void dispose() {
    if (kIsWeb) BrowserContextMenu.enableContextMenu();
    if (_wakelock == true) WakelockPlus.disable();
    if (_immersive) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// Screen-reader users always get the controls (FR-010), and so does the onboarding while its
  /// hints point at them (specs/005, FR-017a).
  bool get _keepControls =>
      MediaQuery.of(context).accessibleNavigation ||
      (OnboardingScope.read(context)?.holdsReader ?? false);

  void _setControls(bool visible) {
    final show = visible || _keepControls;
    if (show == _controlsVisible) return;
    setState(() => _controlsVisible = show);
    _setImmersive(!show);
    // Snack bars sit over the toolbar; clear them when the controls come back.
    if (show) ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// Hides the system bars while reading, and brings them back with the controls.
  void _setImmersive(bool immersive) {
    if (immersive == _immersive) return;
    _immersive = immersive;
    SystemChrome.setEnabledSystemUIMode(
        immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  SessionResult? _shownResult;
  AyahRef? _announced;

  /// Announces reveals to screen readers, and opens the result screen when a session ends
  /// (specs/006 contracts/memorization-ui.md).
  void _followMemorization(MemorizationController m) {
    final revealed = m.lastRevealed;
    if (revealed != null && revealed != _announced && m.active) {
      _announced = revealed;
      final l10n = AppLocalizations.of(context);
      SemanticsService.sendAnnouncement(View.of(context),
          l10n.memorizeRevealed(formatNumber(revealed.ayah, Localizations.localeOf(context))),
          Directionality.of(context));
    }
    final result = m.result, range = m.range;
    if (m.phase != MemorizationPhase.ended || result == null || range == null ||
        identical(result, _shownResult)) {
      return;
    }
    _shownResult = result;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ResultScreen(controller: m, range: range, result: result),
      ));
    });
  }

  /// Keeps the screen on while the reader is shown and the setting is on (FR-018).
  void _syncWakelock(bool on) {
    if (_wakelock == on) return;
    _wakelock = on;
    WakelockPlus.toggle(enable: on).catchError((_) {}); // unavailable in tests
  }

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    final colors = MathaniColors.of(context);
    _syncWakelock(reader.preferences.keepScreenOn);
    // The recitation bar (specs/004) docks at the bottom of both layouts while a session exists.
    final recitation = RecitationScope.maybeOf(context);
    final session = recitation?.session;
    // A memorization session (specs/006) docks its own bar in the same place.
    final memorization = MemorizationScope.maybeOf(context);
    final memorizing = memorization?.active ?? false;
    if (memorization != null) _followMemorization(memorization);
    final docked = session != null || memorizing;
    final bar = memorizing
        ? MemorizationBar(controller: memorization!)
        : RecitationBar(
      key: _targets.player,
      onChooseReciter: () {
        final downloads = recitation?.downloads;
        downloads?.ensureScanned();
        showReciterSheet(context, downloaded: downloads?.isComplete);
      },
      onDownload: recitation == null
          ? null
          : (reciter, surah) => startSurahDownload(context, recitation.downloads, reciter, surah),
    );

    if (reader.layout == ReadingLayout.flowing) {
      if (_immersive || !_controlsVisible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _setImmersive(false);
          setState(() => _controlsVisible = true);
        });
      }
      return _withTour(Scaffold(
        backgroundColor: colors.surface,
        appBar: const _ReaderHeader(),
        bottomNavigationBar: docked
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                _ReaderToolbar(safeBottom: false, targets: _targets),
                bar,
              ])
            : _ReaderToolbar(targets: _targets),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s2),
            child: FlowingView(onAyahLongPress: (ref) => showAyahActions(context, ref)),
          ),
        ),
      ));
    }

    final touring = OnboardingScope.maybeOf(context)?.holdsReader ?? false;
    if (touring && _immersive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setControls(true);
      });
    }
    final show = _controlsVisible || _keepControls || touring;
    // While a recitation is on, the bar is the Scaffold's bottom bar: the page sits above it (so
    // no Quran text is ever covered; PageGeometry refits when it appears or goes), and snack
    // bars float above it instead of covering it.
    return _withTour(Scaffold(
      backgroundColor: colors.surface,
      bottomNavigationBar: docked ? bar : null,
      body: Stack(
        children: [
          // The page sets its own margins (PageGeometry) inside the safe areas.
          Positioned.fill(
            child: SafeArea(
              child: MushafView(
                onAyahLongPress: (ref) => showAyahActions(context, ref),
                onTapPage: () => _setControls(!_controlsVisible),
                onPageTurned: () => _setControls(false),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _Overlay(visible: show, hiddenOffset: const Offset(0, -1), child: const _ReaderHeader()),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _Overlay(
              visible: show,
              hiddenOffset: const Offset(0, 1),
              child: _ReaderToolbar(safeBottom: !docked, targets: _targets),
            ),
          ),
        ],
      ),
    ));
  }

  /// While the onboarding's button hints show, they lie over [scaffold]: the reader underneath
  /// is hidden from screen readers, and back goes to the previous hint (specs/005, research R4).
  /// The tree keeps the same shape either way, so the reader's state survives the hints.
  Widget _withTour(Widget scaffold) {
    final onboarding = OnboardingScope.maybeOf(context);
    final touring = onboarding?.holdsReader ?? false;
    return PopScope(
      canPop: !touring,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && touring) onboarding!.back();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            excluding: touring,
            child: touring ? scaffold : _withKeys(scaffold),
          ),
          if (touring) ButtonTour(targets: _targets),
        ],
      ),
    );
  }

  /// Keyboard use in browsers and on desktops (specs/008 FR-009, research R12): the arrow and
  /// page keys turn pages in the Mushaf's direction (← is the next page, as in a printed Mushaf),
  /// and space plays or pauses the recitation. Escape closes sheets through Flutter's own
  /// dismiss shortcut.
  Widget _withKeys(Widget scaffold) {
    void turn(int delta) {
      final reader = ReaderScope.read(context);
      final page = (reader.page + delta).clamp(1, QuranRepository.pageCount);
      if (page == reader.page) return;
      if (reader.layout == ReadingLayout.flowing) {
        reader.jumpTo(reader.quran.firstAyahOnPage(page).ref, highlight: false);
      } else {
        reader.jumpToPage(page);
      }
    }

    void playOrPause() {
      final recitation = RecitationScope.read(context);
      final status = recitation?.session?.status;
      if (status == RecitationStatus.playing || status == RecitationStatus.loading) {
        recitation!.pause();
      } else if (status == RecitationStatus.paused) {
        recitation!.resume();
      }
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => turn(1),
        const SingleActivator(LogicalKeyboardKey.pageDown): () => turn(1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => turn(-1),
        const SingleActivator(LogicalKeyboardKey.pageUp): () => turn(-1),
        const SingleActivator(LogicalKeyboardKey.space): playOrPause,
      },
      child: Focus(autofocus: true, child: scaffold),
    );
  }
}

/// Slides [child] in and out of view; while hidden it takes no taps and is not announced.
class _Overlay extends StatelessWidget {
  const _Overlay({required this.visible, required this.hiddenOffset, required this.child});

  final bool visible;
  final Offset hiddenOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSlide(
        offset: visible ? Offset.zero : hiddenOffset,
        duration: _ReaderScreenState._slide,
        curve: Curves.easeOut,
        child: IgnorePointer(
          ignoring: !visible,
          child: ExcludeSemantics(excluding: !visible, child: child),
        ),
      );
}

class _ReaderHeader extends StatelessWidget implements PreferredSizeWidget {
  const _ReaderHeader();

  @override
  Size get preferredSize => const Size.fromHeight(Sizes.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final head = reader.pageHead;
    final surah = reader.quran.surahList[head.surah - 1];
    final locale = Localizations.localeOf(context);
    final english = locale.languageCode == 'en';
    final theme = Theme.of(context);

    return AppBar(
      automaticallyImplyLeading: false,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            english ? '${surah.nameTranslit} · ${surah.nameAr}' : 'سورة ${surah.nameAr}',
            style: theme.appBarTheme.titleTextStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Interface numbers follow the language (contracts/ui-screens.md › Direction rules).
          Text(
            '${l10n.juzLabel(formatNumber(head.juz, locale))} · '
            '${l10n.pageLabel(formatNumber(reader.page, locale))}',
            style: TypeScale.caption.copyWith(
              fontFamily: TypeScale.uiFamily,
              color: colors.inkOnBar.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bookmarks the current page, or removes the bookmarks on it. Filled when the page has one
/// (the page indicator, FR-014). A page bookmark is stored against the first ayah on the page.
class _BookmarkToggle extends StatelessWidget {
  const _BookmarkToggle();

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    return ListenableBuilder(
      listenable: reader.user,
      builder: (context, _) {
        final onPage = reader.user.bookmarksOnPage(reader.page);
        final marked = onPage.isNotEmpty;
        return IconButton(
          icon: Icon(marked ? MathaniIcons.bookmarked : MathaniIcons.bookmark),
          color: marked ? colors.accentInk : colors.ink,
          tooltip: marked ? l10n.removeBookmark : l10n.addBookmark,
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            if (marked) {
              for (final b in onPage) {
                await reader.user.removeBookmark(b.id);
              }
            } else {
              await reader.user.addBookmark(reader.quran.firstAyahOnPage(reader.page).ref, reader.page);
            }
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(marked ? l10n.bookmarkRemoved : l10n.bookmarkAdded),
                duration: const Duration(seconds: 2),
              ));
          },
        );
      },
    );
  }
}

/// Reader actions: index, search, layout toggle, bookmark, settings.
class _ReaderToolbar extends StatelessWidget {
  const _ReaderToolbar({this.safeBottom = true, required this.targets});

  /// False when the recitation bar sits below and takes the bottom safe area.
  final bool safeBottom;

  /// Keys for the onboarding's button hints (specs/005).
  final TourTargets targets;

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    void push(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    final mushaf = reader.layout == ReadingLayout.mushaf;
    final recitation = RecitationScope.maybeOf(context);
    final memorization = MemorizationScope.maybeOf(context);
    final memorizing = memorization?.active ?? false;

    return Material(
      color: colors.surfaceRaised,
      child: SafeArea(
        top: false,
        bottom: safeBottom,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.line))),
          child: IconTheme(
            data: IconThemeData(color: colors.ink),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  key: targets.index,
                  icon: const Icon(MathaniIcons.index),
                  tooltip: l10n.openIndex,
                  onPressed: () => push(const IndexScreen()),
                ),
                IconButton(
                  key: targets.search,
                  icon: const Icon(MathaniIcons.search),
                  tooltip: l10n.openSearch,
                  onPressed: () => push(const SearchScreen()),
                ),
                IconButton(
                  icon: Icon(mushaf ? MathaniIcons.flowing : MathaniIcons.mushaf),
                  tooltip: mushaf ? l10n.switchToFlowing : l10n.switchToMushaf,
                  // One tap; the new layout opens at the same ayah (FR-003, SC-010).
                  onPressed: () => reader.updatePreferences(reader.preferences.copyWith(
                    layout: mushaf ? ReadingLayout.flowing : ReadingLayout.mushaf,
                  )),
                ),
                // Listen (specs/004): from this page, or from the top ayah in the flowing layout. The
                // recitation bar takes its place while a recitation is on.
                if (recitation != null && recitation.session == null && !memorizing)
                  IconButton(
                    key: targets.listen,
                    icon: const Icon(MathaniIcons.play),
                    tooltip: l10n.listen,
                    onPressed: () => mushaf
                        ? recitation.playFromPage(reader.page)
                        : recitation.playFrom(reader.anchor),
                  ),
                // Memorize (specs/006): from this page; the memorization bar takes its place during
                // a session.
                if (memorization != null && !memorizing)
                  IconButton(
                    key: targets.memorize,
                    icon: const Icon(MathaniIcons.memorize),
                    tooltip: l10n.memorize,
                    onPressed: () => showMemorizeSheet(context),
                  ),
                const _BookmarkToggle(),
                IconButton(
                  key: targets.settings,
                  icon: const Icon(MathaniIcons.settings),
                  tooltip: l10n.openSettings,
                  onPressed: () => push(const SettingsScreen()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
