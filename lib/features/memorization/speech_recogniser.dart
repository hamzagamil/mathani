// Speech to text for memorization (specs/007 contracts/live-recognition.md › SpeechRecogniser,
// research R2, R5): Khatma's FastConformer decodes the reader's voice on a background isolate, so
// the UI thread never blocks. While the reader speaks, the audio since the last word the matcher
// accepted (the anchor) is decoded again every so often (live passes); at a pause, the rest is
// decoded once (a pause pass). Audio stays in memory.
import 'dart:async';
import 'dart:ffi' show DynamicLibrary;
import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'speech_words.dart';

export 'speech_words.dart' show Hearing, HeardWord, micSampleRate;

/// Voice activity settings (006 contract › VAD); tuned in 006 spike S1. The threshold is below
/// Silero's usual 0.5 because chanted elongations score low as speech (006 research R8).
const vadThreshold = 0.25;
const vadMinSilence = 0.5; // s
const vadMinSpeech = 0.25; // s

/// sherpa-onnx's soft limit on one segment. A segment it ends is speech continuing, not a pause.
const vadMaxSpeech = 12.0; // s
const vadWindow = 512; // samples, Silero's window at 16 kHz

/// New speech needed before the next live pass (research R5).
const livePassEvery = 0.5; // s

/// A live pass slower than this stops live passes until the next pause (FR-010).
const liveSlowPass = Duration(seconds: 2);

/// Audio held without a commit beyond this is still decoded, then cut to its last second, like
/// 006's forced split.
const maxHeld = 20; // s

/// Audio before the anchor decoded with it, for context: a window of a second or two hears cut
/// and invented words (desktop live run, research R5). Words that start before the anchor are
/// context only and are not sent.
const liveContext = 3.0; // s

/// A word heard again may start this much before the anchor and still count as at it: CTC frames
/// are 80 ms.
const anchorTolerance = 0.12; // s

/// One line per pass with `--dart-define=MEMO_TRACE=true` (spike S2); never words or audio.
const memoTrace = bool.fromEnvironment('MEMO_TRACE');

/// The words of one pass (data-model › Heard).
class Heard {
  const Heard(this.pass, this.hearing, this.words, this.windowStart, this.endSample);

  /// Increases by one for every pass, live or pause; a commit names the live pass it answers.
  final int pass;
  final Hearing hearing;
  final List<HeardWord> words;

  /// The first and last samples decoded, counted from the start of the session. A pass whose
  /// [windowStart] is the start of the last word matched hears that word again (matcher rule 12).
  final int windowStart;
  final int endSample;

  @override
  String toString() => 'Heard($pass, ${hearing.name}, $words, $windowStart..$endSample)';
}

abstract class SpeechRecogniser {
  /// Loads the model from [modelDir] (AsrModel.modelDir); once per app run.
  Future<void> load(String modelDir);

  /// Samples from [MicSource], in order.
  void accept(Float32List samples);

  /// One per pass.
  Stream<Heard> get heard;

  /// After a live [Heard]: drop audio before [fromSample] and allow the next live pass. Ignored
  /// when [pass] is not the latest pass.
  void commit(int pass, int fromSample);

  /// On pause or end: a pause pass over what is held.
  void flush();

  /// Drops held audio without decoding it.
  void reset();

  Future<void> dispose();
}

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

/// The VAD, recogniser and held audio, owned by the speech isolate (data-model › Live follow
/// state).
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

  final SendPort _main;
  late final sherpa.VoiceActivityDetector _vad;
  late final sherpa.OfflineRecognizer _recogniser;

  /// Samples short of a whole VAD window.
  Float32List _pending = Float32List(0);

  /// Every sample accepted so far, and the count when the VAD was last reset (its segment starts
  /// count from there).
  int _total = 0;
  int _vadOrigin = 0;

  /// Where the next pass starts hearing words, and the audio from [_heldStart] (up to
  /// [liveContext] before it, never before the last reset) to [_total].
  int _anchor = 0;
  int _heldStart = 0;
  Float32List _held = Float32List(0);

  int _pass = 0;
  bool _latestLive = false;
  bool _awaitingCommit = false;
  bool _liveSuspended = false;
  int _samplesAtLastPass = 0;
  int _lastPassMs = 0;
  final _sinceLastPass = Stopwatch();

  void accept(Float32List samples) {
    _held = _join(_held, samples);
    _total += samples.length;
    final all = _join(_pending, samples);
    var i = 0;
    for (; i + vadWindow <= all.length; i += vadWindow) {
      _vad.acceptWaveform(Float32List.sublistView(all, i, i + vadWindow));
    }
    _pending = Float32List.fromList(Float32List.sublistView(all, i));
    if (!_drain()) _maybeLive();
  }

  /// Pause passes for the segments the VAD ended at a pause; true when there was one.
  bool _drain() {
    var paused = false;
    while (!_vad.isEmpty()) {
      final segment = _vad.front();
      _vad.pop();
      // Ended by the length limit rather than a pause: the reader is still reciting.
      if (segment.samples.length >= (vadMaxSpeech * micSampleRate).round() - vadWindow) continue;
      final end = _vadOrigin + segment.start + segment.samples.length;
      _pausePass(end > _anchor && end <= _total ? end : _total);
      paused = true;
    }
    return paused;
  }

  void _maybeLive() {
    final held = _total - _anchor;
    final long = held > maxHeld * micSampleRate;
    if (_awaitingCommit || (_liveSuspended && !long) || !_vad.isDetected()) return;
    if (_total - _samplesAtLastPass < livePassEvery * micSampleRate) return;
    if (_sinceLastPass.isRunning && _sinceLastPass.elapsedMilliseconds < _lastPassMs) return;
    final took = _decode(Hearing.live, _total);
    _awaitingCommit = true;
    if (took > liveSlowPass.inMilliseconds) _liveSuspended = true;
  }

  void commit(int pass, int from) {
    if (pass != _pass || !_latestLive || !_awaitingCommit) return;
    _moveAnchor(from.clamp(_anchor, _total));
    if (_total - _anchor > maxHeld * micSampleRate) _moveAnchor(_total - micSampleRate);
    _awaitingCommit = false;
  }

  void _pausePass(int end) {
    if (end > _anchor) _decode(Hearing.pause, end);
    _moveAnchor(math.max(_anchor, end));
    _awaitingCommit = false;
    _liveSuspended = false;
  }

  void flush() {
    if (_pending.isNotEmpty) _vad.acceptWaveform(_pending);
    _pending = Float32List(0);
    _vad.flush();
    while (!_vad.isEmpty()) {
      _vad.pop(); // what is held covers them
    }
    _pausePass(_total);
  }

  void reset() {
    _vad.reset();
    _vadOrigin = _total;
    _pending = Float32List(0);
    _moveAnchor(_total);
    _held = Float32List(0); // what came before a reset is not context
    _heldStart = _total;
    _awaitingCommit = false;
    _liveSuspended = false;
  }

  /// Decodes `_anchor → end` with up to [liveContext] before it, sends the words from the anchor
  /// on, and returns how long it took in milliseconds.
  int _decode(Hearing hearing, int end) {
    final timer = Stopwatch()..start();
    final start = math.max(_heldStart, _anchor - (liveContext * micSampleRate).round());
    final audio = Float32List.sublistView(_held, start - _heldStart, end - _heldStart);
    final stream = _recogniser.createStream();
    final List<HeardWord> words;
    try {
      stream.acceptWaveform(samples: audio, sampleRate: micSampleRate);
      _recogniser.decode(stream);
      final result = _recogniser.getResult(stream);
      final from = _anchor - (anchorTolerance * micSampleRate).round();
      words = [
        for (final w in wordsFromPieces(result.tokens, result.timestamps, windowStart: start))
          if (w.startSample >= from) w,
      ];
    } finally {
      stream.free();
    }
    _pass++;
    _latestLive = hearing == Hearing.live;
    _samplesAtLastPass = _total;
    _main.send(Heard(_pass, hearing, words, _anchor, end));
    final took = timer.elapsedMilliseconds;
    _lastPassMs = took;
    _sinceLastPass
      ..reset()
      ..start();
    if (memoTrace) {
      // ignore: avoid_print
      print('memo ${hearing.name} #$_pass ${(audio.length / micSampleRate).toStringAsFixed(1)}s '
          '${took}ms ${words.length} words');
    }
    return took;
  }

  void _moveAnchor(int to) {
    if (to <= _anchor) return;
    _anchor = to;
    final keep = math.max(_heldStart, to - (liveContext * micSampleRate).round());
    _held = Float32List.fromList(Float32List.sublistView(_held, math.min(keep - _heldStart, _held.length)));
    _heldStart = keep;
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
