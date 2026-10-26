import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../features/memorization/speech_recogniser.dart';
import 'file_store.dart';
import 'gunzip.dart';
import 'speech_host.dart' show UnpackResult;

/// Off until spike S2 has shown the browser engine on the reference devices (specs/008 T052):
/// memorization then says it is not available in this browser rather than failing in a session.
/// Builds for the spikes turn it on with `--dart-define=MATHANI_WEB_MEMORIZATION=true`.
const speechEngineAvailable = bool.fromEnvironment('MATHANI_WEB_MEMORIZATION');

/// sherpa-onnx's WebAssembly build in a Web Worker.
SpeechRecogniser newSpeechRecogniser() => WebSpeechRecogniser();

/// [SpeechRecogniser] in the speech worker (web/speech/speech_worker.js running
/// lib/features/memorization/web_worker_main.dart): the page only passes audio in and passes
/// [Heard] on, so decoding never blocks it (constitution III).
class WebSpeechRecogniser implements SpeechRecogniser {
  final _heard = StreamController<Heard>.broadcast();
  _Worker? _worker;
  Completer<void>? _loaded;

  @override
  Stream<Heard> get heard => _heard.stream;

  @override
  Future<void> load(String modelDir) async {
    if (_loaded != null) return _loaded!.future;
    final loaded = _loaded = Completer<void>();
    final worker = _worker = _Worker('speech/speech_worker.js'.toJS);
    worker.onmessage = ((_MessageEvent event) {
      final message = event.data as JSObject;
      switch ((message['type'] as JSString).toDart) {
        case 'loaded':
          loaded.complete();
        case 'error':
          final code = (message['code'] as JSString).toDart;
          if (!loaded.isCompleted) loaded.completeError(StateError('speech worker: $code'));
        case 'heard':
          _heard.add(_heardOf(message));
      }
    }).toJS;
    worker.onerror = ((JSObject error) {
      if (!loaded.isCompleted) loaded.completeError(StateError('speech worker failed to start'));
    }).toJS;
    worker.postMessage({'type': 'load', 'dir': modelDir}.jsify());
    try {
      await loaded.future;
    } catch (_) {
      await dispose();
      rethrow;
    }
  }

  static Heard _heardOf(JSObject m) => Heard(
        (m['pass'] as JSNumber).toDartInt,
        Hearing.values.byName((m['hearing'] as JSString).toDart),
        [
          for (final w in (m['words'] as JSArray<JSObject>).toDart)
            HeardWord((w['text'] as JSString).toDart, (w['start'] as JSNumber).toDartInt,
                (w['end'] as JSNumber).toDartInt),
        ],
        (m['windowStart'] as JSNumber).toDartInt,
        (m['endSample'] as JSNumber).toDartInt,
      );

  @override
  void accept(Float32List samples) => _worker?.postMessage(samples.toJS);

  @override
  void commit(int pass, int fromSample) =>
      _worker?.postMessage({'type': 'commit', 'pass': pass, 'from': fromSample}.jsify());

  @override
  void flush() => _worker?.postMessage({'type': 'flush'}.jsify());

  @override
  void reset() => _worker?.postMessage({'type': 'reset'}.jsify());

  @override
  Future<void> dispose() async {
    _worker?.postMessage({'type': 'dispose'}.jsify());
    _worker?.terminate();
    _worker = null;
    _loaded = null;
  }
}

@JS('Worker')
extension type _Worker._(JSObject _) implements JSObject {
  external factory _Worker(JSString url);
  external set onmessage(JSFunction handler);
  external set onerror(JSFunction handler);
  external void postMessage(JSAny? message);
  external void terminate();
}

extension type _MessageEvent._(JSObject _) implements JSObject {
  external JSAny? get data;
}

/// Checks [packed], then streams it through the browser's DecompressionStream into `<kept>.part`
/// while hashing, and renames it once it matches. Each chunk is awaited, so the page keeps
/// drawing frames while 133 MB pass through.
Future<UnpackResult> unpackModel(FileStore store, StoreFile packed, StoreFile kept,
    {required String packedSha256, required int keptBytes, required String keptSha256}) async {
  if ((await sha256.bind(store.read(packed)).first).toString() != packedSha256) {
    return UnpackResult.badDownload;
  }
  final part = kept.part;
  await store.delete(part);
  final digest = _DigestSink();
  final hash = sha256.startChunkedConversion(digest);
  var written = 0;
  try {
    await store.append(
        part,
        gunzipStream(store.read(packed)).map((chunk) {
          hash.add(chunk);
          written += chunk.length;
          return chunk;
        }));
  } on NoSpaceException {
    await store.delete(part);
    return UnpackResult.noSpace;
  } on FormatException {
    await store.delete(part);
    return UnpackResult.badDownload;
  }
  hash.close();
  if (written != keptBytes || digest.value.toString() != keptSha256) {
    await store.delete(part);
    return UnpackResult.badResult;
  }
  await store.rename(part, kept);
  return UnpackResult.done;
}

/// Receives the digest of a chunked SHA-256.
class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
