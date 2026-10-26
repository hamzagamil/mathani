// The browser's speech worker (specs/008 research R10, contracts/web-platform.md › Speech worker):
// the same LiveFollower as the phones' speech isolate, over sherpa-onnx's WebAssembly build.
// Compiled on its own, into web/speech/speech_worker.dart.js:
//   dart compile js -O2 -o build/web/speech/speech_worker.dart.js lib/features/memorization/web_worker_main.dart
// (tool/web_deploy.mjs runs it). Audio and words never leave the worker except as `heard`
// messages to the page; the only files it reads are the model's, from the browser's private file
// system, where the app saved them (FR-024).
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'live_follower.dart';
import 'speech_recogniser.dart';

/// Where the model's files are put in the WebAssembly file system.
const _modelDir = '/model';
const _modelFiles = ['model.int8.onnx', 'tokens.txt', 'silero_vad.onnx'];

LiveFollower? _follower;

void main() {
  _self.onmessage = ((_MessageEvent event) {
    unawaited(_handle(event.data));
  }).toJS;
}

Future<void> _handle(JSAny? data) async {
  if (data.isA<JSFloat32Array>()) {
    _follower?.accept((data as JSFloat32Array).toDart);
    return;
  }
  final message = data as JSObject;
  switch ((message['type'] as JSString).toDart) {
    case 'load':
      await _load((message['dir'] as JSString).toDart);
    case 'commit':
      _follower?.commit((message['pass'] as JSNumber).toDartInt, (message['from'] as JSNumber).toDartInt);
    case 'flush':
      _follower?.flush();
    case 'reset':
      _follower?.reset();
    case 'dispose':
      _follower?.free();
      _follower = null;
      _self.close();
  }
}

/// Copies the model from the private file system into sherpa-onnx's, builds the VAD and the
/// recogniser with the phones' settings, and answers `loaded` or `error`.
Future<void> _load(String dir) async {
  if (_follower != null) {
    _post({'type': 'loaded'});
    return;
  }
  final _Sherpa sherpa;
  try {
    sherpa = _self.mathaniSherpa;
  } on Object {
    _post({'type': 'error', 'code': 'unsupported'});
    return;
  }
  try {
    final module = await sherpa.load().toDart;
    final fs = module['FS'] as _Fs;
    try {
      fs.mkdir(_modelDir);
    } on Object {
      // Already there.
    }
    final folder = await _opfsDir(dir);
    for (final name in _modelFiles) {
      final file = await (await folder.getFileHandle(name).toDart).getFile().toDart;
      fs.writeFile('$_modelDir/$name', (await file.arrayBuffer().toDart).toDart.asUint8List().toJS);
    }
    final engine = _JsSherpaEngine(module, sherpa);
    // The recogniser holds the model in its own memory now: free the file-system copies.
    for (final name in _modelFiles) {
      fs.unlink('$_modelDir/$name');
    }
    _follower = LiveFollower(engine, _sendHeard);
    _post({'type': 'loaded'});
  } on Object catch (e) {
    final text = '$e';
    final memory = text.contains('RangeError') || text.contains('memory') || text.contains('OOM');
    _post({'type': 'error', 'code': memory ? 'memory' : 'failed', 'detail': text});
  }
}

Future<_Dir> _opfsDir(String path) async {
  var d = await _self.navigator.storage.getDirectory().toDart;
  for (final name in path.split('/').where((s) => s.isNotEmpty)) {
    d = await d.getDirectoryHandle(name).toDart;
  }
  return d;
}

void _sendHeard(Heard h) => _post({
      'type': 'heard',
      'pass': h.pass,
      'hearing': h.hearing.name,
      'windowStart': h.windowStart,
      'endSample': h.endSample,
      'words': [
        for (final w in h.words) {'text': w.text, 'start': w.startSample, 'end': w.endSample},
      ],
    });

void _post(Map<String, Object?> message) => _self.postMessage(message.jsify());

/// [SpeechEngine] on sherpa-onnx's JavaScript API, with the same settings as the phones'
/// SherpaEngine (sherpa_recogniser.dart).
class _JsSherpaEngine implements SpeechEngine {
  _JsSherpaEngine(JSObject module, _Sherpa sherpa)
      : _vad = sherpa.createVad(
            module,
            {
              'sileroVad': {
                'model': '$_modelDir/silero_vad.onnx',
                'threshold': vadThreshold,
                'minSilenceDuration': vadMinSilence,
                'minSpeechDuration': vadMinSpeech,
                'maxSpeechDuration': vadMaxSpeech,
                'windowSize': vadWindow,
              },
              'tenVad': {
                'model': '',
                'threshold': 0.5,
                'minSilenceDuration': 0.5,
                'minSpeechDuration': 0.25,
                'maxSpeechDuration': 20,
                'windowSize': 256,
              },
              'sampleRate': micSampleRate,
              'numThreads': 1,
              'provider': 'cpu',
              'debug': 0,
              'bufferSizeInSeconds': 30,
            }.jsify()! as JSObject),
        // Khatma's whole graph, features included, as a raw-audio CTC model (specs/007 R2).
        _recogniser = sherpa.createRecognizer(
            module,
            {
              'modelConfig': {
                'omnilingual': {'model': '$_modelDir/model.int8.onnx'},
                'tokens': '$_modelDir/tokens.txt',
                'numThreads': 1,
                'provider': 'cpu',
                'debug': 0,
              },
              'decodingMethod': 'greedy_search',
            }.jsify()! as JSObject);

  final _Vad _vad;
  final _Recognizer _recogniser;

  @override
  void vadAccept(Float32List window) => _vad.acceptWaveform(window.toJS);

  @override
  bool get vadDetected => _vad.isDetected();

  @override
  bool get vadEmpty => _vad.isEmpty();

  @override
  ({int start, int length}) vadFront() {
    final segment = _vad.front();
    return (start: segment.start, length: segment.samples.length);
  }

  @override
  void vadPop() => _vad.pop();

  @override
  void vadFlush() => _vad.flush();

  @override
  void vadReset() => _vad.reset();

  @override
  ({List<String> tokens, List<double> timestamps}) decode(Float32List audio) {
    final stream = _recogniser.createStream();
    try {
      stream.acceptWaveform(micSampleRate, audio.toJS);
      _recogniser.decode(stream);
      final result = _recogniser.getResult(stream);
      return (
        tokens: [for (final t in result.tokens.toDart) (t as JSString).toDart],
        timestamps: [for (final t in result.timestamps.toDart) (t as JSNumber).toDartDouble],
      );
    } finally {
      stream.free();
    }
  }

  @override
  void free() {
    _vad.free();
    _recogniser.free();
  }
}

// --- Worker and sherpa-onnx JavaScript API ---------------------------------------------------

@JS('self')
external _Scope get _self;

extension type _Scope._(JSObject _) implements JSObject {
  external set onmessage(JSFunction handler);
  external void postMessage(JSAny? message);
  external void close();
  external _Sherpa get mathaniSherpa;
  external _Navigator get navigator;
}

extension type _MessageEvent._(JSObject _) implements JSObject {
  external JSAny? get data;
}

extension type _Sherpa._(JSObject _) implements JSObject {
  external JSPromise<JSObject> load();
  external _Vad createVad(JSObject module, JSObject config);
  external _Recognizer createRecognizer(JSObject module, JSObject config);
}

extension type _Fs._(JSObject _) implements JSObject {
  external void mkdir(String path);
  external void writeFile(String path, JSUint8Array data);
  external void unlink(String path);
}

extension type _Vad._(JSObject _) implements JSObject {
  external void acceptWaveform(JSFloat32Array samples);
  external bool isDetected();
  external bool isEmpty();
  external _Segment front();
  external void pop();
  external void flush();
  external void reset();
  external void free();
}

extension type _Segment._(JSObject _) implements JSObject {
  external int get start;
  external JSFloat32Array get samples;
}

extension on JSFloat32Array {
  int get length => toDart.length;
}

extension type _Recognizer._(JSObject _) implements JSObject {
  external _Stream createStream();
  external void decode(_Stream stream);
  external _Result getResult(_Stream stream);
  external void free();
}

extension type _Stream._(JSObject _) implements JSObject {
  external void acceptWaveform(int sampleRate, JSFloat32Array samples);
  external void free();
}

extension type _Result._(JSObject _) implements JSObject {
  external JSArray<JSAny?> get tokens;
  external JSArray<JSAny?> get timestamps;
}

extension type _Navigator._(JSObject _) implements JSObject {
  external _Storage get storage;
}

extension type _Storage._(JSObject _) implements JSObject {
  external JSPromise<_Dir> getDirectory();
}

extension type _Dir._(JSObject _) implements JSObject {
  external JSPromise<_Dir> getDirectoryHandle(String name);
  external JSPromise<_FileHandle> getFileHandle(String name);
}

extension type _FileHandle._(JSObject _) implements JSObject {
  external JSPromise<_File> getFile();
}

extension type _File._(JSObject _) implements JSObject {
  external JSPromise<JSArrayBuffer> arrayBuffer();
}
