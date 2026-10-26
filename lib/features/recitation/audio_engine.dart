// The audio player behind the recitation, as a small interface so the controller can be tested
// with a fake (specs/004-ayah-recitations/contracts/recitation-playback.md, research R3).
import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../../platform/file_store.dart';
import 'recited_item.dart';

sealed class EngineEvent {
  const EngineEvent();
}

/// The player moved to [item] (also when the window is first set).
class ItemStarted extends EngineEvent {
  const ItemStarted(this.item);
  final RecitedItem item;
}

/// The last item of the window finished; nothing is queued after it.
class WindowCompleted extends EngineEvent {
  const WindowCompleted(this.item);
  final RecitedItem item;
}

/// The player could not play a file.
class EngineFailed extends EngineEvent {
  const EngineFailed(this.error);
  final Object error;
}

/// The system paused playback: a call, another app's audio, or headphones unplugged (FR-017).
class EnginePausedBySystem extends EngineEvent {
  const EnginePausedBySystem();
}

/// Plays a short window of local files gaplessly: `[previous?, current, next…]`.
abstract interface class AudioEngine {
  Stream<EngineEvent> get events;

  /// Replaces the window and positions the player at the start of [currentIndex].
  Future<void> setWindow(List<(RecitedItem, StoreFile)> items, {int currentIndex = 0});

  /// Adds an item after the last one; it plays without a gap.
  Future<void> append(RecitedItem item, StoreFile file);

  /// Removes the first item of the window (it has already played).
  Future<void> removeFirst();

  /// Called synchronously inside the tap that starts playback, before anything is fetched: lets
  /// a browser that only plays audio started by a tap (iOS Safari) play this player later.
  void prime();

  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
}

/// [AudioEngine] on just_audio: ExoPlayer/Media3 on Android, AVQueuePlayer on iOS. Calls, other
/// apps' audio and unplugged headphones pause it (handleInterruptions), and it never changes the
/// system volume.
class JustAudioEngine implements AudioEngine {
  JustAudioEngine({FileStore? store}) : _store = store ?? fileStore() {
    _subscriptions
      // The playing ayah is the tag of the source the player is on, not an index into a copy of
      // the playlist: just_audio reports the index on every playback event, and a copy runs ahead
      // of the player while an item is being removed, which named the wrong ayah.
      ..add(_player.sequenceStateStream.listen(_onSequence))
      ..add(_player.processingStateStream.listen(_onState))
      ..add(_player.errorStream.listen((e) => _events.add(EngineFailed(e))))
      ..add(_player.playingStream.listen((playing) {
        if (!playing && _wantPlaying && _player.processingState != ProcessingState.completed) {
          // Paused by the system, not by us.
          _wantPlaying = false;
          _events.add(const EnginePausedBySystem());
        }
      }));
  }

  final FileStore _store;
  final _player = AudioPlayer(handleInterruptions: true);

  /// The URIs of the window, in order: `blob:` URLs in browsers are released when their item
  /// leaves (specs/008 research R8).
  final _uris = <Uri>[];
  final _events = StreamController<EngineEvent>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  RecitedItem? _started;
  bool _sessionConfigured = false;
  bool _wantPlaying = false;

  /// Playlist changes run one at a time: just_audio aborts a load when the playlist changes under it.
  Future<void> _tail = Future<void>.value();

  Future<void> _serial(Future<void> Function() op) {
    final result = _tail.then((_) => op());
    _tail = result.catchError((Object _) {});
    return result;
  }

  @override
  Stream<EngineEvent> get events => _events.stream;

  void _onSequence(SequenceState state) {
    final tag = state.currentSource?.tag;
    if (tag is RecitedItem && tag != _started) {
      _started = tag;
      _events.add(ItemStarted(tag));
    }
  }

  void _onState(ProcessingState state) {
    final last = _player.sequence.isEmpty ? null : _player.sequence.last.tag;
    if (state == ProcessingState.completed && last is RecitedItem) {
      _wantPlaying = false;
      _events.add(WindowCompleted(last));
    }
  }

  @override
  Future<void> setWindow(List<(RecitedItem, StoreFile)> items, {int currentIndex = 0}) =>
      _serial(() async {
        _started = null; // the new window's first item is reported even if it is the same ayah
        final uris = [for (final (_, file) in items) await _store.playableUri(file)];
        await _player.setAudioSources(
          [for (var i = 0; i < items.length; i++) AudioSource.uri(uris[i], tag: items[i].$1)],
          initialIndex: currentIndex,
          preload: true,
        );
        _releaseAll();
        _uris.addAll(uris);
      });

  @override
  Future<void> append(RecitedItem item, StoreFile file) => _serial(() async {
        final uri = await _store.playableUri(file);
        await _player.addAudioSource(AudioSource.uri(uri, tag: item));
        _uris.add(uri);
      });

  /// Phones play without a tap.
  @override
  void prime() {}

  @override
  Future<void> removeFirst() => _serial(() async {
        if (_player.sequence.isEmpty) return;
        await _player.removeAudioSourceAt(0);
        if (_uris.isNotEmpty) _store.release(_uris.removeAt(0));
      });

  void _releaseAll() {
    _uris.forEach(_store.release);
    _uris.clear();
  }

  @override
  Future<void> play() async {
    if (!_sessionConfigured) {
      _sessionConfigured = true;
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    }
    _wantPlaying = true;
    unawaited(_player.play()); // completes only when playback stops
  }

  @override
  Future<void> pause() async {
    _wantPlaying = false;
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    _wantPlaying = false;
    _started = null;
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _player.dispose();
    _releaseAll();
    await _events.close();
  }
}
