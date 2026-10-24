// Speech to text for memorization (specs/006 contracts/memorization-engine.md › SpeechRecogniser,
// research R8): Silero VAD splits the reader's voice into segments and Whisper decodes each one,
// on a background isolate so the UI thread never blocks. Audio stays in memory.
import 'dart:async';
import 'dart:ffi' show DynamicLibrary;
import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Samples per second of the microphone stream and of both models.
const micSampleRate = 16000;

/// Voice activity settings (contract › VAD); tuned in spike S1. The threshold is below Silero's
/// usual 0.5 because chanted elongations score low as speech (research R8 › Export findings).
const vadThreshold = 0.25;
const vadMinSilence = 0.5; // s
const vadMinSpeech = 0.25; // s
const vadMaxSpeech = 12.0; // s; sherpa-onnx treats it as a soft limit
const vadWindow = 512; // samples, Silero's window at 16 kHz

/// The longest audio decoded at once, well under Whisper's 30 s window: longer segments are cut
/// into pieces of this length.
const maxPiece = 25 * micSampleRate;

/// Consecutive pieces overlap by a second, so a word on the cut is heard whole.
const forcedSplitOverlap = micSampleRate;

/// Silence appended before decoding: without it Whisper drops the last word (research R8).
const tailSilence = 2 * micSampleRate;

/// What the reader said in one VAD segment.
class Segment {
  const Segment(this.text, {this.forcedSplit = false});
  final String text;

  /// Cut at [vadMaxSpeech] rather than at a pause: the reader is still reciting.
  final bool forcedSplit;

  @override
  String toString() => 'Segment($text${forcedSplit ? ', forced' : ''})';
}

abstract class SpeechRecogniser {
  /// Loads the model from [modelDir] (AsrModel.modelDir); once per app run.
  Future<void> load(String modelDir);

  /// Samples from [MicSource], in order.
  void accept(Float32List samples);

  /// One per VAD segment, decoded.
  Stream<Segment> get segments;

  /// On pause or end: decodes what is buffered.
  void flush();

  /// Drops buffered audio without decoding it.
  void reset();

  Future<void> dispose();
}

/// The recogniser on sherpa-onnx, in a long-lived isolate.
class SherpaSpeechRecogniser implements SpeechRecogniser {
  /// [nativeLibraryDir]: where sherpa-onnx's library is, for desktop tests; the app finds it
  /// itself.
  SherpaSpeechRecogniser({this.nativeLibraryDir});

  final String? nativeLibraryDir;
  final _segments = StreamController<Segment>.broadcast();
  Isolate? _isolate;
  SendPort? _worker;
  ReceivePort? _port;
  Completer<void>? _loaded;

  @override
  Stream<Segment> get segments => _segments.stream;

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
        case (final String text, final bool forced):
          _segments.add(Segment(text, forcedSplit: forced));
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
  _Worker? worker;
  inbox.listen((message) {
    switch (message) {
      case ('load', final String dir, final int threads, final String? library):
        try {
          worker = _Worker(dir, threads, library, main);
          main.send('loaded');
        } catch (e) {
          main.send(('error', '$e'));
        }
      case final TransferableTypedData data:
        worker?.accept(data.materialize().asFloat32List());
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

/// The VAD and recogniser, owned by the speech isolate.
class _Worker {
  _Worker(String dir, int threads, String? library, this._main) {
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
    _recogniser = sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        whisper: sherpa.OfflineWhisperModelConfig(
          encoder: '$dir/encoder.int8.onnx',
          decoder: '$dir/decoder.int8.onnx',
          language: 'ar',
          task: 'transcribe',
        ),
        tokens: '$dir/tokens.txt',
        numThreads: threads,
        debug: false,
      ),
    ));
  }

  final SendPort _main;
  late final sherpa.VoiceActivityDetector _vad;
  late final sherpa.OfflineRecognizer _recogniser;

  /// Samples short of a whole VAD window.
  Float32List _pending = Float32List(0);

  /// Segments ended by the length limit, held until the reader pauses so an ayah is decoded whole.
  Float32List _held = Float32List(0);

  void accept(Float32List samples) {
    final all = _join(_pending, samples);
    var i = 0;
    for (; i + vadWindow <= all.length; i += vadWindow) {
      _vad.acceptWaveform(Float32List.sublistView(all, i, i + vadWindow));
    }
    _pending = Float32List.fromList(Float32List.sublistView(all, i));
    _drain();
  }

  void flush() {
    if (_pending.isNotEmpty) _vad.acceptWaveform(_pending);
    _pending = Float32List(0);
    _vad.flush();
    _drain();
    if (_held.isNotEmpty) _send(_held, forced: false);
    _held = Float32List(0);
  }

  void reset() {
    _vad.reset();
    _pending = Float32List(0);
    _held = Float32List(0);
  }

  void _drain() {
    while (!_vad.isEmpty()) {
      final segment = _vad.front().samples;
      _vad.pop();
      // Ended by the length limit rather than a pause: the reader is still reciting.
      final forced = segment.length >= (vadMaxSpeech * micSampleRate).round() - vadWindow;
      _held = _join(_held, segment);
      // Hold a forced segment while one more would still fit in a piece.
      if (forced && _held.length + vadMaxSpeech * micSampleRate <= maxPiece) continue;
      _send(_held, forced: forced);
      _held = Float32List(0);
    }
  }

  /// Decodes [audio] in pieces of at most [maxPiece], each overlapping the previous by a second.
  void _send(Float32List audio, {required bool forced}) {
    for (var start = 0;; start += maxPiece - forcedSplitOverlap) {
      final end = start + maxPiece;
      final last = end >= audio.length;
      final text = _decode(Float32List.sublistView(audio, start, last ? audio.length : end)).trim();
      if (text.isNotEmpty) _main.send((text, last ? forced : true));
      if (last) break;
    }
  }

  String _decode(Float32List audio) {
    final stream = _recogniser.createStream();
    try {
      stream.acceptWaveform(
          samples: _join(audio, Float32List(tailSilence)), sampleRate: micSampleRate);
      _recogniser.decode(stream);
      return _recogniser.getResult(stream).text;
    } finally {
      stream.free();
    }
  }

  void free() {
    _vad.free();
    _recogniser.free();
  }

  static Float32List _join(Float32List a, Float32List b) {
    if (a.isEmpty) return b;
    return Float32List(a.length + b.length)
      ..setAll(0, a)
      ..setAll(a.length, b);
  }
}
