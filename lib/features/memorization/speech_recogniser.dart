// Speech to text for memorization (specs/007 contracts/live-recognition.md › SpeechRecogniser,
// research R2, R5): Khatma's FastConformer decodes the reader's voice off the UI thread, so it
// never blocks: sherpa-onnx in an isolate on phones (sherpa_recogniser.dart), its WebAssembly
// build in a Web Worker in browsers (specs/008 research R10). Live follow is in
// live_follower.dart. Audio stays in memory. Pure Dart, so the browser's worker compiles it too.
import 'dart:typed_data';

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
