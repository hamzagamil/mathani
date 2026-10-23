import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/models.dart';
import '../data/quran_repository.dart';
import '../data/user_repository.dart';

/// Single source of truth for where the reader is (research R6): the anchor ayah, the page on
/// screen, the reading layout and preferences, the selected ayah and a transient highlight.
class ReaderController extends ChangeNotifier with WidgetsBindingObserver {
  ReaderController({
    required this.quran,
    required this.user,
    required AyahRef anchor,
    required this._preferences,
  }) : _anchor = quran.tryAyah(anchor)?.ref ?? const AyahRef(1, 1) {
    _page = quran.pageOf(_anchor);
    WidgetsBinding.instance.addObserver(this);
  }

  static const _saveDelay = Duration(milliseconds: 500);
  static const highlightDuration = Duration(milliseconds: 1500);

  final QuranRepository quran;
  final UserRepository user;

  AyahRef _anchor;
  int _page = 1;
  ReaderPreferences _preferences;
  AyahRef? _selected;
  AyahRef? _highlighted;
  int _jumpSerial = 0;
  Timer? _saveTimer;
  Timer? _highlightTimer;

  AyahRef get anchor => _anchor;
  int get page => _page;
  ReaderPreferences get preferences => _preferences;
  ReadingLayout get layout => _preferences.layout;
  AyahRef? get selected => _selected;
  AyahRef? get highlighted => _highlighted;

  /// Increments on every programmatic navigation; views jump to [page] when it changes.
  int get jumpSerial => _jumpSerial;

  /// Ayah whose surah and juz the header shows: the anchor when it is on the current page (so
  /// opening Al-Kahf mid-page shows Al-Kahf), otherwise the first ayah on the page.
  Ayah get pageHead {
    final a = quran.ayahAt(_anchor);
    return a.page == _page ? a : quran.firstAyahOnPage(_page);
  }

  /// The Mushaf layout settled on [page]. The anchor becomes the first ayah on it, unless the
  /// selected or highlighted ayah is on that page.
  void onMushafPageShown(int page) {
    if (page == _page) return;
    _page = page;
    final keep = _selected ?? _highlighted;
    _anchor = keep != null && quran.pageOf(keep) == page ? keep : quran.firstAyahOnPage(page).ref;
    _scheduleSave();
    notifyListeners();
  }

  /// The flowing layout scrolled; [topAyah] is the first ayah visible at the top.
  void onFlowingTopAyah(AyahRef topAyah) {
    if (topAyah == _anchor) return;
    _anchor = topAyah;
    _page = quran.pageOf(topAyah);
    _scheduleSave();
    notifyListeners();
  }

  /// Navigates both layouts to [ref], highlighting it for 1.5 s unless [highlight] is false.
  void jumpTo(AyahRef ref, {bool highlight = true}) {
    if (quran.tryAyah(ref) == null) return;
    _anchor = ref;
    _page = quran.pageOf(ref);
    _jumpSerial++;
    _highlightTimer?.cancel();
    _highlighted = highlight ? ref : null;
    if (highlight) {
      _highlightTimer = Timer(highlightDuration, () {
        _highlighted = null;
        notifyListeners();
      });
    }
    _scheduleSave();
    notifyListeners();
  }

  /// Shows Mushaf [page] without moving the anchor ayah: for following a recited basmala whose
  /// line sits on the page before its ayah 1 (specs/004 recitation-playback › Following).
  void jumpToPage(int page) {
    if (page < 1 || page > QuranRepository.pageCount) return;
    _page = page;
    _jumpSerial++;
    _highlightTimer?.cancel();
    _highlighted = null;
    notifyListeners();
  }

  void select(AyahRef? ref) {
    if (ref == _selected) return;
    _selected = ref;
    if (ref != null) _anchor = ref;
    notifyListeners();
  }

  void updatePreferences(ReaderPreferences p) {
    final layoutChanged = p.layout != _preferences.layout;
    _preferences = p;
    if (layoutChanged) _jumpSerial++; // the new layout opens at the anchor (SC-010)
    unawaited(user.savePreferences(p));
    notifyListeners();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _save);
  }

  void _save() {
    _saveTimer?.cancel();
    _saveTimer = null;
    unawaited(user.saveAnchor(_anchor));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Save immediately when leaving, so a system kill loses at most the last 500 ms (R6).
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) _save();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _highlightTimer?.cancel();
    super.dispose();
  }
}

/// Provides the [ReaderController] to the widget tree and rebuilds dependents on change.
class ReaderScope extends InheritedNotifier<ReaderController> {
  const ReaderScope({super.key, required ReaderController controller, required super.child})
      : super(notifier: controller);

  static ReaderController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReaderScope>()!.notifier!;

  /// Access without subscribing to changes (event handlers).
  static ReaderController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ReaderScope>()!.notifier!;
}
