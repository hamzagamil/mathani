import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import '../features/recitation/audio_engine.dart';
import '../features/recitation/recited_item.dart';
import 'file_store.dart';

AudioEngine newAudioEngine() => HtmlAudioEngine();

/// [AudioEngine] on one HTML audio element (specs/008 research R8). Safari on iOS lets an audio
/// element play only after it was started inside a tap; a recitation starts after its recording
/// has been fetched, long after the tap. So [prime] starts this element on a moment of silence
/// during the tap, and every ayah after that plays on the same, now unlocked, element.
/// just_audio's web player keeps its element private, so it cannot be primed.
class HtmlAudioEngine implements AudioEngine {
  HtmlAudioEngine({FileStore? store}) : _store = store ?? fileStore() {
    _audio
      ..addEventListener('ended', ((JSAny _) => _onEnded()).toJS)
      ..addEventListener('error', ((JSAny _) => _onError()).toJS)
      ..addEventListener('pause', ((JSAny _) => _onPause()).toJS);
  }

  final FileStore _store;
  final _audio = _Audio();
  final _events = StreamController<EngineEvent>.broadcast();

  /// The window: items with the URIs the element plays, and the one playing.
  final _items = <(RecitedItem, Uri)>[];
  int _index = 0;
  bool _wantPlaying = false;
  bool _priming = false;

  @override
  Stream<EngineEvent> get events => _events.stream;

  @override
  void prime() {
    if (_items.isNotEmpty) return; // already played: unlocked
    _priming = true;
    _audio.src = _silence;
    _audio.play().toDart.catchError((Object _) => null);
  }

  @override
  Future<void> setWindow(List<(RecitedItem, StoreFile)> items, {int currentIndex = 0}) async {
    final uris = [for (final (_, file) in items) await _store.playableUri(file)];
    _releaseAll();
    _items.addAll([for (var i = 0; i < items.length; i++) (items[i].$1, uris[i])]);
    _index = currentIndex;
    _load();
  }

  @override
  Future<void> append(RecitedItem item, StoreFile file) async =>
      _items.add((item, await _store.playableUri(file)));

  @override
  Future<void> removeFirst() async {
    if (_items.isEmpty) return;
    _store.release(_items.removeAt(0).$2);
    if (_index > 0) _index--;
  }

  @override
  Future<void> play() async {
    _wantPlaying = true;
    try {
      await _audio.play().toDart;
    } on Object catch (e) {
      _wantPlaying = false;
      _events.add(EngineFailed(e));
    }
  }

  @override
  Future<void> pause() async {
    _wantPlaying = false;
    _audio.pause();
  }

  @override
  Future<void> stop() async {
    _wantPlaying = false;
    _audio.pause();
    _releaseAll();
    _audio.removeAttribute('src');
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _events.close();
  }

  /// Puts the current item on the element and reports it.
  void _load() {
    _priming = false;
    final (item, uri) = _items[_index];
    _audio
      ..src = uri.toString()
      ..load();
    _events.add(ItemStarted(item));
  }

  void _onEnded() {
    if (_priming) {
      _priming = false;
      return;
    }
    if (_index + 1 < _items.length) {
      _index++;
      _load();
      if (_wantPlaying) unawaited(play());
    } else if (_items.isNotEmpty) {
      _wantPlaying = false;
      _events.add(WindowCompleted(_items.last.$1));
    }
  }

  void _onError() {
    if (_priming || _items.isEmpty) return;
    _events.add(EngineFailed(StateError('audio error ${_audio.error?.code}')));
  }

  /// Paused by the browser or the system (another tab's audio, a call), not by us.
  void _onPause() {
    if (_priming || _audio.ended || !_wantPlaying) return;
    _wantPlaying = false;
    _events.add(const EnginePausedBySystem());
  }

  void _releaseAll() {
    for (final (_, uri) in _items) {
      _store.release(uri);
    }
    _items.clear();
    _index = 0;
  }
}

/// A tenth of a second of silence, as a WAV data URI.
final String _silence = () {
  const rate = 8000, samples = 800;
  final b = ByteData(44 + samples);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  b.setUint32(4, 36 + samples, Endian.little);
  ascii(8, 'WAVEfmt ');
  b
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, 1, Endian.little) // mono
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate, Endian.little) // bytes per second, 8-bit mono
    ..setUint16(32, 1, Endian.little)
    ..setUint16(34, 8, Endian.little);
  ascii(36, 'data');
  b.setUint32(40, samples, Endian.little);
  for (var i = 0; i < samples; i++) {
    b.setUint8(44 + i, 128); // 8-bit silence
  }
  return 'data:audio/wav;base64,${base64Encode(b.buffer.asUint8List())}';
}();

@JS('Audio')
extension type _Audio._(JSObject _) implements JSObject {
  external factory _Audio();
  external set src(String value);
  external bool get ended;
  external _MediaError? get error;
  external JSPromise<JSAny?> play();
  external void pause();
  external void load();
  external void removeAttribute(String name);
  external void addEventListener(String type, JSFunction listener);
}

extension type _MediaError._(JSObject _) implements JSObject {
  external int get code;
}
