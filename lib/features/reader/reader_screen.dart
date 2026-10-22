import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/numerals.dart';
import '../../shared/reader_state.dart';
import '../index/index_screen.dart';
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

  @override
  void dispose() {
    if (_wakelock == true) WakelockPlus.disable();
    if (_immersive) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// Screen-reader users always get the controls (FR-010).
  bool get _keepControls => MediaQuery.of(context).accessibleNavigation;

  void _setControls(bool visible) {
    final show = visible || _keepControls;
    if (show == _controlsVisible) return;
    setState(() => _controlsVisible = show);
    _setImmersive(!show);
    // The hint sits over the toolbar; once the reader has tapped, it has done its job.
    if (show) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final reader = ReaderScope.read(context);
    if (!show && !reader.preferences.controlsHintShown) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).controlsHint),
        duration: const Duration(seconds: 4),
      ));
      reader.updatePreferences(reader.preferences.copyWith(controlsHintShown: true));
    }
  }

  /// Hides the system bars while reading, and brings them back with the controls.
  void _setImmersive(bool immersive) {
    if (immersive == _immersive) return;
    _immersive = immersive;
    SystemChrome.setEnabledSystemUIMode(
        immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
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

    if (reader.layout == ReadingLayout.flowing) {
      if (_immersive || !_controlsVisible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _setImmersive(false);
          setState(() => _controlsVisible = true);
        });
      }
      return Scaffold(
        backgroundColor: colors.surface,
        appBar: const _ReaderHeader(),
        bottomNavigationBar: const _ReaderToolbar(),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s2),
            child: FlowingView(onAyahLongPress: (ref) => showAyahActions(context, ref)),
          ),
        ),
      );
    }

    final show = _controlsVisible || _keepControls;
    return Scaffold(
      backgroundColor: colors.surface,
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
            child: _Overlay(visible: show, hiddenOffset: const Offset(0, 1), child: const _ReaderToolbar()),
          ),
        ],
      ),
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
  const _ReaderToolbar();

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    void push(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    final mushaf = reader.layout == ReadingLayout.mushaf;

    return Material(
      color: colors.surfaceRaised,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.line))),
          child: IconTheme(
            data: IconThemeData(color: colors.ink),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(MathaniIcons.index),
                  tooltip: l10n.openIndex,
                  onPressed: () => push(const IndexScreen()),
                ),
                IconButton(
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
                const _BookmarkToggle(),
                IconButton(
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
