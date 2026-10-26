// Speech to text on sherpa-onnx through FFI, in a long-lived isolate (specs/007 research R2, R5).
// Phones and desktop tests only: browsers use the WebAssembly build (specs/008 research R10).
import 'dart:async';
import 'dart:ffi' show DynamicLibrary;
import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'live_follower.dart';
import 'speech_recogniser.dart';

/// The recogniser on sherpa-onnx, in a long-lived isolate.
class SherpaSpeechRecogniser implements SpeechRecogniser {
  /// [nativeLibraryDir]: where sherpa-onnx's library is, for desktop tests; the app finds it
  /// itself.
  SherpaSpeechRecogniser({this.nativeLibraryDir});

  final String? nativeLibraryDir;
  final _heard = StreamController<Heard>.broadcast();
  Isolate? _isolate;
  SendPort? _worker;
  ReceivePort? _port;
  Completer<void>? _loaded;

  @override
  Stream<Heard> get heard => _heard.stream;

  @override
  Future<void> load(String modelDir) async {
    if (_loaded != null) return _loaded!.future;
    final loaded = _loaded = Completer<void>();
    final port = _port = ReceivePort();
    port.listen((message) {
      switch (message) {
        case final SendPort worker:
          _worker = worker;
          worker.send(('load', modelDir, Platform.numberOfProcessors <= 4 ? 2 : 4, nativeLibraryDir));
        case 'loaded':
          loaded.complete();
        case ('error', final String error):
          if (!loaded.isCompleted) loaded.completeError(StateError(error));
        case final Heard heard:
          _heard.add(heard);
      }
    });
    _isolate = await Isolate.spawn(_run, port.sendPort, debugName: 'speech');
    try {
      await loaded.future;
    } catch (_) {
      await dispose();
      rethrow;
    }
  }

  @override
  void accept(Float32List samples) =>
      _worker?.send(TransferableTypedData.fromList([samples]));

  @override
  void commit(int pass, int fromSample) => _worker?.send(('commit', pass, fromSample));

  @override
  void flush() => _worker?.send('flush');

  @override
  void reset() => _worker?.send('reset');

  @override
  Future<void> dispose() async {
    _worker?.send('dispose');
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _port?.close();
    _isolate = null;
    _worker = null;
    _port = null;
    _loaded = null;
  }
}

void _run(SendPort main) {
  final inbox = ReceivePort();
  main.send(inbox.sendPort);
  LiveFollower? worker;
  inbox.listen((message) {
    switch (message) {
      case ('load', final String dir, final int threads, final String? library):
        try {
          worker = LiveFollower(SherpaEngine(dir, threads, library), main.send);
          main.send('loaded');
        } catch (e) {
          main.send(('error', '$e'));
        }
      case final TransferableTypedData data:
        worker?.accept(data.materialize().asFloat32List());
      case ('commit', final int pass, final int from):
        worker?.commit(pass, from);
      case 'flush':
        worker?.flush();
      case 'reset':
        worker?.reset();
      case 'dispose':
        worker?.free();
        worker = null;
        inbox.close();
    }
  });
}

/// [SpeechEngine] on sherpa-onnx through FFI, owned by the speech isolate.
class SherpaEngine implements SpeechEngine {
  SherpaEngine(String dir, int threads, String? library) {
    // Windows 11 has an older onnxruntime.dll in System32, which the loader would pick for
    // sherpa-onnx in desktop tests; loading the bundled one first makes it reuse that one.
    if (Platform.isWindows && library != null) DynamicLibrary.open('$library/onnxruntime.dll');
    sherpa.initBindings(library);
    _vad = sherpa.VoiceActivityDetector(
      config: sherpa.VadModelConfig(
        sileroVad: sherpa.SileroVadModelConfig(
          model: '$dir/silero_vad.onnx',
          threshold: vadThreshold,
          minSilenceDuration: vadMinSilence,
          minSpeechDuration: vadMinSpeech,
          maxSpeechDuration: vadMaxSpeech,
          windowSize: vadWindow,
        ),
        sampleRate: micSampleRate,
        debug: false,
      ),
      bufferSizeInSeconds: 30,
    );
    // Khatma's whole graph, features included, as a raw-audio CTC model (research R2).
    _recogniser = sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        omnilingual: sherpa.OfflineOmnilingualAsrCtcModelConfig(model: '$dir/model.int8.onnx'),
        tokens: '$dir/tokens.txt',
        numThreads: threads,
        debug: false,
      ),
    ));
  }

  late final sherpa.VoiceActivityDetector _vad;
  late final sherpa.OfflineRecognizer _recogniser;

  @override
  void vadAccept(Float32List window) => _vad.acceptWaveform(window);

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
      stream.acceptWaveform(samples: audio, sampleRate: micSampleRate);
      _recogniser.decode(stream);
      final result = _recogniser.getResult(stream);
      return (tokens: result.tokens, timestamps: result.timestamps);
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
