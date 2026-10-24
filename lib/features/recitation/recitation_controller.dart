// The recitation in progress: what is being recited, playing or paused, and whether the reader
// follows it (specs/004-ayah-recitations/contracts/recitation-playback.md).
import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../data/models.dart';
import '../../data/quran_repository.dart';
import '../../shared/reader_state.dart';
import 'audio_engine.dart';
import 'ayah_fetcher.dart';
import 'download_queue.dart';
import 'recited_item.dart';

/// Waiting longer than this for the current ayah's file is an error (FR-020).
const loadingTimeout = Duration(seconds: 15);

/// Next/previous taps closer together than this are merged: only the last one loads.
const skipMergeWindow = Duration(milliseconds: 300);

/// How long "Recitation finished" shows after An-Nas before the bar closes.
const endedBannerDuration = Duration(seconds: 3);

enum RecitationStatus { loading, playing, paused, error, ended }

/// A one-off message for the bar (US2: switching to a reciter that isn't downloaded, offline).
class RecitationNotice {
  const RecitationNotice.reciterNotDownloaded(this.reciter);
  final Reciter reciter;
}

/// A reciter sample that doesn't start within this time is unavailable (specs/005 research R5).
const sampleStartTimeout = Duration(seconds: 5);

enum PreviewStatus { loading, playing, unavailable }

/// A few seconds of a reciter on the onboarding's reciter step (specs/005 data-model ›
/// ReciterPreview). Never persisted; never a session.
class ReciterPreview {
  ReciterPreview(this.reciterId);
  final String reciterId;
  PreviewStatus status = PreviewStatus.loading;
}

/// The recitation in progress. Never persisted (spec assumption).
class RecitationSession {
  RecitationSession({required this.reciter, required this.item});

  Reciter reciter;
  RecitedItem item;
  RecitationStatus status = RecitationStatus.loading;
  FetchError? error;
  bool following = true;
}

class RecitationController extends ChangeNotifier with WidgetsBindingObserver {
  RecitationController({
    required this.reader,
    required this.fetcher,
    AudioEngine Function()? engine,
  }) : _engineFactory = engine ?? JustAudioEngine.new {
    _order = RecitedOrder(ayahCount: (s) => quran.surahList[s - 1].ayahCount);
    _lastSeenSerial = reader.jumpSerial;
    _lastLayout = reader.layout;
    reader.addListener(_onReaderChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  final ReaderController reader;
  final AyahFetcher fetcher;
  final AudioEngine Function() _engineFactory;
  late final RecitedOrder _order;

  AudioEngine? _engine;
  StreamSubscription<EngineEvent>? _engineEvents;
  RecitationSession? _session;
  RecitationNotice? _notice;
  ReciterPreview? _preview;
  int _previewGeneration = 0;
  Timer? _previewTimer;

  /// Increments whenever the current item is replaced; stale async work checks it and stops.
  int _generation = 0;

  /// Items in the engine's window, in order, mirroring it.
  final _window = <RecitedItem>[];
  /// The window generation whose lookahead is being filled (-1: none). A fill for an older window
  /// never blocks the current one.
  int _fillingGeneration = -1;

  /// The generation whose window has finished loading in the player. The lookahead is appended only
  /// then: changing the playlist while it loads aborts the load (just_audio), which left the
  /// session stuck in loading until a second press.
  int _readyGeneration = -1;
  bool _windowEnded = false;

  int _followSerial = -1;
  int _lastSeenSerial = 0;
  ReadingLayout _lastLayout = ReadingLayout.mushaf;
  int? _recitedPage;
  Timer? _skipTimer;
  Timer? _endedTimer;
  final _loadTimers = <Timer>{};

  /// Called on the first `play*` (US3 sets up the system media controls here).
  Future<void> Function()? onFirstPlay;
  bool _firstPlayDone = false;

  QuranRepository get quran => reader.quran;

  /// Per-surah downloads (User Story 4). Created the first time a screen needs it.
  late final DownloadQueue downloads = _downloads = DownloadQueue(quran: quran, fetcher: fetcher);
  DownloadQueue? _downloads;
  RecitationSession? get session => _session;

  /// The jump serial of the last follow jump (flowing view and Mushaf view compare against it).
  int get followSerial => _followSerial;

  /// The item to highlight: null with no session or once the recitation has ended.
  RecitedItem? get recited {
    final s = _session;
    return s == null || s.status == RecitationStatus.ended ? null : s.item;
  }

  /// A one-off notice for the bar; read once with [takeNotice].
  RecitationNotice? get notice => _notice;
  RecitationNotice? takeNotice() {
    final n = _notice;
    _notice = null;
    return n;
  }

  AudioEngine get _player {
    final e = _engine;
    if (e != null) return e;
    final created = _engineFactory();
    _engineEvents = created.events.listen(_onEngineEvent);
    return _engine = created;
  }

  Reciter? get _preferredReciter => quran.reciterOrDefault(reader.preferences.reciter);

  // --- Starting ------------------------------------------------------------------------------

  /// Starts at the first ayah that begins on [page], or the ayah continuing onto it when none
  /// begins there (FR-006).
  Future<void> playFromPage(int page) {
    final starting = quran.ayahsStartingOnPage(page);
    final ref = starting.isNotEmpty ? starting.first.ref : quran.firstAyahOnPage(page).ref;
    return playFrom(ref);
  }

  /// Starts at [ref], or at its basmala when [ref] is ayah 1 of a surah that has one (FR-008).
  Future<void> playFrom(AyahRef ref) async {
    final reciter = _session?.reciter ?? _preferredReciter;
    if (reciter == null) return; // no catalogue
    _clearPreview(); // the recitation's window replaces the sample's
    _endedTimer?.cancel();
    _skipTimer?.cancel();
    final item = _order.startItem(ref);
    final s = _session;
    if (s == null) {
      _session = RecitationSession(reciter: reciter, item: item);
    } else {
      s
        ..item = item
        ..status = RecitationStatus.loading
        ..error = null;
    }
    _session!.following = true;
    notifyListeners();
    if (!_firstPlayDone) {
      _firstPlayDone = true;
      await onFirstPlay?.call();
    }
    unawaited(_followJump(item));
    await _load(item, play: true);
  }

  /// Resolves [item] and makes it the start of a fresh window. Never skips: on failure the
  /// session stays on [item] in `error`.
  Future<void> _load(RecitedItem item, {required bool play}) async {
    final generation = ++_generation;
    final s = _session!;
    fetcher.cancelPrefetch();
    _window.clear();
    _windowEnded = false;
    final File file;
    try {
      file = await _timed(fetcher.resolve(s.reciter, item));
    } on Object catch (e) {
      if (generation != _generation) return;
      s
        ..status = RecitationStatus.error
        ..error = e is FetchException ? e.error : FetchError.fetchFailed;
      notifyListeners();
      return;
    }
    if (generation != _generation) return;
    _window.add(item);
    try {
      await _player.setWindow([(item, file)]);
      if (generation != _generation) return;
      _readyGeneration = generation;
      if (play) {
        s.status = RecitationStatus.playing;
        await _player.play();
      } else {
        s.status = RecitationStatus.paused;
      }
    } on Object {
      // The player could not load or start the file. Never stay in loading: show the error, with
      // Retry on the same ayah (FR-020).
      if (generation != _generation) return;
      s
        ..status = RecitationStatus.error
        ..error = FetchError.fetchFailed;
      notifyListeners();
      return;
    }
    s.error = null;
    notifyListeners();
    unawaited(_fillAhead(generation));
  }

  /// Appends up to [prefetchAhead] resolved items after the current one.
  Future<void> _fillAhead(int generation) async {
    if (generation != _readyGeneration || _fillingGeneration == generation) return;
    _fillingGeneration = generation;
    try {
      while (generation == _generation) {
        final s = _session;
        if (s == null || _window.isEmpty) return;
        final current = _window.indexOf(s.item);
        if (current < 0 || _window.length - 1 - current >= prefetchAhead) return;
        final next = _order.next(_window.last);
        if (next == null) return; // the end of the Quran
        final File file;
        try {
          file = await fetcher.resolve(s.reciter, next, priority: true);
        } on Object {
          // Tried again when the window runs out; never skipped. If it already has, load it now so
          // the session shows the error instead of waiting forever.
          if (_windowEnded && _session?.item == next) {
            _windowEnded = false;
            unawaited(_load(next, play: true));
          }
          return;
        }
        if (generation != _generation) return;
        _window.add(next);
        await _player.append(next, file);
        _protectWindow();
        if (_windowEnded && s.item == next) {
          // The player ran out while this was loading: carry on from it.
          _windowEnded = false;
          await _load(next, play: true);
          return;
        }
      }
    } finally {
      if (_fillingGeneration == generation) _fillingGeneration = -1;
    }
  }

  /// [future], or a timeout error after [loadingTimeout]. The timer is cancelled on stop and
  /// dispose, so nothing outlives the session.
  Future<T> _timed<T>(Future<T> future) {
    final result = Completer<T>();
    late final Timer timer;
    timer = Timer(loadingTimeout, () {
      _loadTimers.remove(timer);
      if (!result.isCompleted) result.completeError(TimeoutException(null, loadingTimeout));
    });
    _loadTimers.add(timer);
    future.then((v) {
      timer.cancel();
      _loadTimers.remove(timer);
      if (!result.isCompleted) result.complete(v);
    }, onError: (Object e, StackTrace st) {
      timer.cancel();
      _loadTimers.remove(timer);
      if (!result.isCompleted) result.completeError(e, st);
    });
    return result.future;
  }

  void _cancelLoadTimers() {
    for (final t in _loadTimers) {
      t.cancel();
    }
    _loadTimers.clear();
  }

  void _protectWindow() {
    final s = _session;
    if (s == null) return;
    unawaited(() async {
      final paths = <String>[];
      for (final item in List.of(_window)) {
        final (su, a) = item.isBasmala ? (1, 1) : (item.surah, item.ayah);
        paths.add((await fetcher.cacheFile(s.reciter.id, su, a)).path);
      }
      fetcher.protect(paths);
    }());
  }

  void _onEngineEvent(EngineEvent event) {
    final s = _session;
    if (s == null) {
      _onPreviewEvent(event);
      return;
    }
    switch (event) {
      case ItemStarted(:final item):
        // Only an ayah of the current window: a late event from a replaced window is not news.
        if (!_window.contains(item)) return;
        if (item != s.item && s.status != RecitationStatus.paused) {
          s.item = item;
          notifyListeners();
          unawaited(_followJump(item));
        }
        // Keep one played item before the current one.
        final index = _window.indexOf(item);
        for (var i = 0; i < index - 1; i++) {
          _window.removeAt(0);
          unawaited(_player.removeFirst());
        }
        unawaited(_fillAhead(_generation));
      case WindowCompleted(:final item):
        final next = _order.next(item);
        if (next == null) {
          _end();
          return;
        }
        // The next ayah isn't ready: wait on it, never skip (FR-007).
        s
          ..item = next
          ..status = RecitationStatus.loading;
        _windowEnded = true;
        notifyListeners();
        unawaited(_followJump(next));
        if (_fillingGeneration != _generation) unawaited(_load(next, play: true));
      case EngineFailed():
        s
          ..status = RecitationStatus.error
          ..error = FetchError.fetchFailed;
        notifyListeners();
      case EnginePausedBySystem():
        if (s.status == RecitationStatus.playing) {
          s.status = RecitationStatus.paused;
          notifyListeners();
        }
    }
  }

  void _end() {
    final s = _session;
    if (s == null) return;
    ++_generation;
    s.status = RecitationStatus.ended;
    notifyListeners();
    _endedTimer?.cancel();
    _endedTimer = Timer(endedBannerDuration, () {
      if (_session?.status == RecitationStatus.ended) unawaited(stop());
    });
  }

  // --- Controls (state first, then the platform: FR-011) -------------------------------------

  void pause() {
    final s = _session;
    if (s == null) return;
    if (s.status == RecitationStatus.playing || s.status == RecitationStatus.loading) {
      s.status = RecitationStatus.paused;
      notifyListeners();
      ++_generation; // a load in flight must not start playing
      unawaited(_player.pause());
    }
  }

  void resume() {
    final s = _session;
    if (s == null) return;
    if (s.status == RecitationStatus.paused) {
      if (_window.contains(s.item)) {
        s.status = RecitationStatus.playing;
        notifyListeners();
        unawaited(_player.play());
        unawaited(_fillAhead(_generation));
      } else {
        s.status = RecitationStatus.loading;
        notifyListeners();
        unawaited(_load(s.item, play: true));
      }
    } else if (s.status == RecitationStatus.error) {
      retry();
    }
  }

  void next() => _skip(forward: true);
  void previous() => _skip(forward: false);

  /// Moves at once on screen; loads only once taps stop for [skipMergeWindow].
  void _skip({required bool forward}) {
    final s = _session;
    if (s == null || s.status == RecitationStatus.ended) return;
    final target = forward ? _order.next(s.item) : _order.previous(s.item);
    if (target == null) {
      _end();
      unawaited(_player.stop());
      return;
    }
    final wasPlaying = s.status != RecitationStatus.paused;
    ++_generation;
    unawaited(_player.pause());
    s
      ..item = target
      ..status = wasPlaying ? RecitationStatus.loading : RecitationStatus.paused
      ..error = null;
    _window.clear();
    notifyListeners();
    unawaited(_followJump(target));
    _skipTimer?.cancel();
    _skipTimer = Timer(skipMergeWindow, () {
      final current = _session;
      if (current == null || current.item != target) return;
      unawaited(_load(target, play: wasPlaying));
    });
  }

  void retry() {
    final s = _session;
    if (s == null) return;
    s
      ..status = RecitationStatus.loading
      ..error = null;
    notifyListeners();
    unawaited(_load(s.item, play: true));
  }

  /// Ends the session: clears the highlight, hides the bar, stops audio and prefetch (FR-015).
  Future<void> stop() async {
    ++_generation;
    _skipTimer?.cancel();
    _endedTimer?.cancel();
    _cancelLoadTimers();
    fetcher.cancelPrefetch();
    _window.clear();
    _windowEnded = false;
    _recitedPage = null;
    final had = _session != null;
    _session = null;
    if (had) notifyListeners();
    await _engine?.stop();
    await onStop?.call();
  }

  // --- Reciter samples (specs/005 contracts/onboarding-flow.md › RecitationController) ---------

  /// A sample loading, playing or unavailable; null when none.
  ReciterPreview? get preview => _preview;

  /// Plays Al-Fatiha 1:1 by [r] through the same fetcher and player as recitations, without a
  /// session: no bar, highlight, follow jump or system media controls. Does nothing while a
  /// recitation is on.
  Future<void> previewReciter(Reciter r) async {
    if (_session != null) return;
    if (_preview != null) {
      _clearPreview();
      await _engine?.stop();
    }
    final generation = ++_previewGeneration;
    final p = _preview = ReciterPreview(r.id);
    notifyListeners();
    _previewTimer = Timer(sampleStartTimeout, () {
      if (generation == _previewGeneration && p.status == PreviewStatus.loading) {
        _previewUnavailable();
      }
    });
    const item = RecitedItem.ayah(1, 1);
    // Replaced, stopped, or timed out: a late file must not start playing.
    bool stale() => generation != _previewGeneration || p.status == PreviewStatus.unavailable;
    try {
      final file = await fetcher.resolve(r, item);
      if (stale()) return;
      await _player.setWindow([(item, file)]);
      if (stale()) return;
      await _player.play();
    } on Object {
      if (generation == _previewGeneration) _previewUnavailable();
    }
  }

  /// Stops the sample, if any (FR-011).
  Future<void> stopPreview() async {
    if (_preview == null) return;
    _clearPreview();
    notifyListeners();
    if (_session == null) await _engine?.stop();
  }

  void _clearPreview() {
    ++_previewGeneration;
    _previewTimer?.cancel();
    _preview = null;
  }

  void _previewUnavailable() {
    _previewTimer?.cancel();
    _preview?.status = PreviewStatus.unavailable;
    notifyListeners();
    unawaited(_engine?.stop());
  }

  void _onPreviewEvent(EngineEvent event) {
    final p = _preview;
    if (p == null) return;
    switch (event) {
      case ItemStarted():
        if (p.status != PreviewStatus.loading) return;
        _previewTimer?.cancel();
        p.status = PreviewStatus.playing;
        notifyListeners();
      case WindowCompleted():
        _clearPreview();
        notifyListeners();
      case EngineFailed():
        _previewUnavailable();
      case EnginePausedBySystem():
        unawaited(stopPreview());
    }
  }

  /// Called when the session ends (US3 stops the system media session here).
  Future<void> Function()? onStop;

  /// Switches the reciter (US2): see contracts/recitation-playback.md › setReciter.
  Future<void> setReciter(String id) async {
    final next = quran.reciter(id);
    if (next == null) return;
    final previousPrefs = reader.preferences;
    reader.updatePreferences(previousPrefs.copyWith(reciter: id));
    final s = _session;
    if (s == null || s.reciter == next) return;
    final previousReciter = s.reciter;
    final item = s.item;
    final wasPlaying = s.status == RecitationStatus.playing || s.status == RecitationStatus.loading;
    s
      ..reciter = next
      ..status = RecitationStatus.loading
      ..error = null;
    final generation = ++_generation;
    notifyListeners();
    unawaited(_player.pause());
    try {
      await _timed(fetcher.resolve(next, item));
    } on FetchException catch (e) {
      if (generation != _generation || e.error != FetchError.offline) {
        if (generation == _generation) {
          s
            ..status = RecitationStatus.error
            ..error = e.error;
          notifyListeners();
        }
        return;
      }
      // Offline and not downloaded for the new reciter: keep the previous one (edge case).
      s.reciter = previousReciter;
      reader.updatePreferences(reader.preferences.copyWith(reciter: previousReciter.id));
      _notice = RecitationNotice.reciterNotDownloaded(next);
      notifyListeners();
      await _load(item, play: wasPlaying);
      return;
    } on Object {
      if (generation != _generation) return;
      s
        ..status = RecitationStatus.error
        ..error = FetchError.fetchFailed;
      notifyListeners();
      return;
    }
    if (generation != _generation) return;
    await _load(item, play: wasPlaying);
  }

  // --- Following (FR-012 to FR-014) ----------------------------------------------------------

  /// The page that shows [item]: for a basmala, the page holding its basmala line in the active
  /// lettering (in the printed edition it can be the page before ayah 1).
  Future<int> recitedPage(RecitedItem item) async {
    if (!item.isBasmala) return quran.pageOf(item.ref);
    final printed = reader.preferences.lettering == Lettering.printed && quran.hasPrintedLettering;
    return quran.basmalaPageOf(item.surah, printed: printed);
  }

  /// The one way the reader is moved to follow the recitation.
  Future<void> _followJump(RecitedItem item) async {
    final s = _session;
    if (s == null || !s.following) return;
    final mushaf = reader.layout == ReadingLayout.mushaf;
    // Until the jump lands, a page that differs is not a swipe (see _onReaderChanged).
    _recitedPage = null;
    final page = await recitedPage(item);
    if (_session != s || !s.following || s.item != item) return;
    _recitedPage = page;
    if (mushaf && item.isBasmala && page != quran.pageOf(item.ref)) {
      if (reader.page == page) return;
      _followSerial = reader.jumpSerial + 1;
      reader.jumpToPage(page);
    } else {
      // The Mushaf already shows it; the flowing view still gets the jump, to keep it in view.
      if (mushaf && reader.page == page && reader.anchor == item.ref) return;
      _followSerial = reader.jumpSerial + 1;
      reader.jumpTo(item.ref, highlight: false);
    }
  }

  /// Back to the recited ayah, and follow it again.
  void returnToRecitation() {
    final s = _session;
    if (s == null) return;
    s.following = true;
    notifyListeners();
    unawaited(_followJump(s.item));
  }

  /// The reader dragged the flowing layout (a scroll they started).
  void onReaderScroll() => _unfollow();

  void _unfollow() {
    final s = _session;
    if (s == null || !s.following) return;
    s.following = false;
    notifyListeners();
  }

  void _onReaderChanged() {
    final layout = reader.layout;
    final serial = reader.jumpSerial;
    final layoutChanged = layout != _lastLayout;
    _lastLayout = layout;
    final s = _session;
    if (serial != _lastSeenSerial) {
      _lastSeenSerial = serial;
      if (s == null || serial == _followSerial) return;
      if (layoutChanged) {
        // A layout switch opens the new layout at the anchor: show the recited item instead.
        if (s.following) unawaited(_followJump(s.item));
        return;
      }
      _unfollow(); // index, search, go-to, bookmarks
      return;
    }
    if (s == null || !s.following || layout != ReadingLayout.mushaf) return;
    final expected = _recitedPage;
    if (expected != null && reader.page != expected) _unfollow(); // a swipe
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A sample never plays on in the background (specs/005, FR-011).
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      unawaited(stopPreview());
    }
    // Back from the background: show the recited page (US3 AS3).
    final s = _session;
    if (state == AppLifecycleState.resumed && s != null && s.following) {
      unawaited(_followJump(s.item));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    reader.removeListener(_onReaderChanged);
    _skipTimer?.cancel();
    _endedTimer?.cancel();
    _previewTimer?.cancel();
    _cancelLoadTimers();
    unawaited(_engineEvents?.cancel());
    unawaited(_engine?.dispose());
    _downloads?.dispose();
    super.dispose();
  }
}

/// Provides the [RecitationController] and rebuilds dependents on change.
class RecitationScope extends InheritedNotifier<RecitationController> {
  const RecitationScope({super.key, required RecitationController controller, required super.child})
      : super(notifier: controller);

  static RecitationController of(BuildContext context) => maybeOf(context)!;

  /// Null where no recitation is provided (some reader tests).
  static RecitationController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RecitationScope>()?.notifier;

  /// Access without subscribing to changes (event handlers).
  static RecitationController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<RecitationScope>()?.notifier;
}
