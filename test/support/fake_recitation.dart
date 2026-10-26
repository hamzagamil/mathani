import 'dart:async';

import 'package:mathani/data/models.dart';
import 'package:mathani/features/recitation/audio_engine.dart';
import 'package:mathani/features/recitation/ayah_fetcher.dart';
import 'package:mathani/features/recitation/recitation_controller.dart';
import 'package:mathani/features/recitation/recited_item.dart';
import 'package:mathani/platform/file_store.dart';
import 'package:mathani/shared/reader_state.dart';

import 'memory_file_store.dart';

/// A player that only records what it is told and lets tests end items (specs/004 tests).
class FakeAudioEngine implements AudioEngine {
  final _events = StreamController<EngineEvent>.broadcast();
  final window = <RecitedItem>[];
  int current = 0;
  bool playing = false;
  int stops = 0;

  /// Loading a window takes this long, like just_audio preparing a file. While it loads, a change
  /// to the playlist aborts the load (just_audio throws PlayerInterruptedException).
  Duration loadTime = Duration.zero;
  bool _loading = false;
  bool _aborted = false;

  /// Set when the playlist was changed during a load.
  bool interrupted = false;

  void _change() {
    if (_loading) {
      interrupted = true;
      _aborted = true;
    }
  }

  RecitedItem? get currentItem => window.isEmpty ? null : window[current];

  @override
  Stream<EngineEvent> get events => _events.stream;

  @override
  Future<void> setWindow(List<(RecitedItem, StoreFile)> items, {int currentIndex = 0}) async {
    _change();
    window
      ..clear()
      ..addAll([for (final (i, _) in items) i]);
    current = currentIndex;
    _events.add(ItemStarted(window[current]));
    if (loadTime == Duration.zero) return;
    _loading = true;
    _aborted = false;
    await Future<void>.delayed(loadTime);
    _loading = false;
    if (_aborted) throw StateError('Loading interrupted');
  }

  @override
  Future<void> append(RecitedItem item, StoreFile file) async {
    _change();
    window.add(item);
  }

  @override
  Future<void> removeFirst() async {
    _change();
    if (window.isEmpty) return;
    window.removeAt(0);
    current = current > 0 ? current - 1 : 0;
  }

  @override
  Future<void> play() async => playing = true;

  @override
  Future<void> pause() async => playing = false;

  @override
  Future<void> stop() async {
    playing = false;
    window.clear();
    stops++;
  }

  @override
  Future<void> dispose() => _events.close();

  /// The current item finishes: the next one in the window starts, or the window completes.
  void finishCurrent() {
    if (current + 1 < window.length) {
      current++;
      _events.add(ItemStarted(window[current]));
    } else {
      _events.add(WindowCompleted(window[current]));
    }
  }

  /// Sends any event, as a late or stray one from the real player would arrive.
  void emit(EngineEvent event) => _events.add(event);

  /// The system paused playback (a call, unplugged headphones).
  void pausedBySystem() {
    playing = false;
    _events.add(const EnginePausedBySystem());
  }
}

/// A fetcher whose resolves can be held, failed or answered at once.
class FakeFetcher extends AyahFetcher {
  FakeFetcher()
      : super(
          recordingSize: (_, _, _) async => 1,
          store: MemoryFileStore(),
        );

  /// Every resolve, in call order: (reciter id, item).
  final resolved = <(String, RecitedItem)>[];
  final failing = <RecitedItem, FetchError>{};
  final holding = <RecitedItem>{};
  bool holdAll = false;
  final _held = <RecitedItem, Completer<StoreFile>>{};

  /// Reciters whose files are "not downloaded" while offline.
  final offlineReciters = <String>{};

  List<RecitedItem> get resolvedItems => [for (final (_, i) in resolved) i];

  @override
  Future<StoreFile> resolve(Reciter r, RecitedItem item, {bool priority = true}) {
    resolved.add((r.id, item));
    if (offlineReciters.contains(r.id)) {
      return Future.error(const FetchException(FetchError.offline));
    }
    final error = failing[item];
    if (error != null) return Future.error(FetchException(error));
    if (holdAll || holding.contains(item)) {
      return (_held[item] ??= Completer<StoreFile>()).future;
    }
    return Future.value(StoreFile(StoreRoot.cache, '${r.id}-$item.mp3'));
  }

  /// Answers a held resolve.
  void release(RecitedItem item) {
    holding.remove(item);
    _held.remove(item)?.complete(StoreFile(StoreRoot.cache, '$item.mp3'));
  }

  /// Fails a held resolve.
  void failHeld(RecitedItem item, FetchError error) {
    holding.remove(item);
    _held.remove(item)?.completeError(FetchException(error));
  }

  @override
  void cancelPrefetch() {}

  @override
  void protect(Iterable<StoreFile> files) {}

  @override
  Future<StoreFile> cacheFile(String reciter, int surah, int ayah) async =>
      StoreFile(StoreRoot.cache, '$reciter-$surah-$ayah');
}

/// A recitation controller over [reader] with a fake engine and fetcher.
(RecitationController, FakeAudioEngine, FakeFetcher) openTestRecitation(ReaderController reader) {
  final engine = FakeAudioEngine();
  final fetcher = FakeFetcher();
  final controller = RecitationController(reader: reader, fetcher: fetcher, engine: () => engine);
  return (controller, engine, fetcher);
}
