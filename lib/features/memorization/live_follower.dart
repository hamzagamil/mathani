// Live follow (specs/007 contracts/live-recognition.md › SpeechRecogniser, research R5): while the
// reader speaks, the audio since the anchor (the start of the last word the matcher accepted) is
// decoded again every so often (live passes); at a pause, the rest is decoded once (a pause pass).
// Shared by the phones' speech isolate and the browser's speech worker (specs/008 research R10).
import 'dart:math' as math;
import 'dart:typed_data';

import 'speech_recogniser.dart';
import 'speech_words.dart';

/// What [LiveFollower] needs from a recogniser: Silero VAD fed in [vadWindow]-sample windows, and
/// a CTC decode of a stretch of audio (specs/008 contracts/web-platform.md › SpeechEngine).
abstract class SpeechEngine {
  /// Exactly [vadWindow] samples, or the last few at [LiveFollower.flush].
  void vadAccept(Float32List window);
  bool get vadDetected;
  bool get vadEmpty;

  /// The oldest finished segment: its first sample since the last [vadReset], and its length.
  ({int start, int length}) vadFront();
  void vadPop();
  void vadFlush();
  void vadReset();

  /// Decodes [audio] at [micSampleRate]: tokens and their start times in seconds.
  ({List<String> tokens, List<double> timestamps}) decode(Float32List audio);
  void free();
}

/// The VAD state, held audio and passes of one session, over a [SpeechEngine] (specs/007
/// data-model › Live follow state). Owned by the speech isolate on phones and by the Web Worker in
/// browsers (specs/008 research R10), so live reveal behaves the same everywhere.
class LiveFollower {
  LiveFollower(this._engine, this._send);

  final SpeechEngine _engine;
  final void Function(Heard) _send;

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
      _engine.vadAccept(Float32List.sublistView(all, i, i + vadWindow));
    }
    _pending = Float32List.fromList(Float32List.sublistView(all, i));
    if (!_drain()) _maybeLive();
  }

  /// Pause passes for the segments the VAD ended at a pause; true when there was one.
  bool _drain() {
    var paused = false;
    while (!_engine.vadEmpty) {
      final segment = _engine.vadFront();
      _engine.vadPop();
      // Ended by the length limit rather than a pause: the reader is still reciting.
      if (segment.length >= (vadMaxSpeech * micSampleRate).round() - vadWindow) continue;
      final end = _vadOrigin + segment.start + segment.length;
      _pausePass(end > _anchor && end <= _total ? end : _total);
      paused = true;
    }
    return paused;
  }

  void _maybeLive() {
    final held = _total - _anchor;
    final long = held > maxHeld * micSampleRate;
    if (_awaitingCommit || (_liveSuspended && !long) || !_engine.vadDetected) return;
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
    if (_pending.isNotEmpty) _engine.vadAccept(_pending);
    _pending = Float32List(0);
    _engine.vadFlush();
    while (!_engine.vadEmpty) {
      _engine.vadPop(); // what is held covers them
    }
    _pausePass(_total);
  }

  void reset() {
    _engine.vadReset();
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
    final result = _engine.decode(audio);
    final from = _anchor - (anchorTolerance * micSampleRate).round();
    final words = [
      for (final w in wordsFromPieces(result.tokens, result.timestamps, windowStart: start))
        if (w.startSample >= from) w,
    ];
    _pass++;
    _latestLive = hearing == Hearing.live;
    _samplesAtLastPass = _total;
    _send(Heard(_pass, hearing, words, _anchor, end));
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

  void free() => _engine.free();

  static Float32List _join(Float32List a, Float32List b) {
    if (a.isEmpty) return b;
    return Float32List(a.length + b.length)
      ..setAll(0, a)
      ..setAll(a.length, b);
  }
}
