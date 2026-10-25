// The words of one decoding pass (specs/007 contracts/live-recognition.md › Words from pieces,
// research R5, R6). Pure Dart: no Flutter or plugin imports, so the speech isolate and the matcher
// share it and it is tested without the native library.
import 'dart:math' as math;

import '../search/arabic_normalizer.dart';

/// Samples per second of the microphone stream and of both models.
const micSampleRate = 16000;

/// A word's anchor sits this far before its first piece: CTC frames are 80 ms, and a piece's time
/// is where its spike is, not where the word begins (research R5).
const anchorMargin = 0.16; // s

/// sherpa-onnx reports a raw-audio model's piece times at 20 ms per frame; Khatma's frames are
/// 80 ms (8× subsampling), so its times are multiplied by this (research R2).
const khatmaFrameScale = 4;

/// How a pass heard the reader.
enum Hearing {
  /// While the reader keeps reciting: words are revealed, and a mistake needs two following words
  /// to confirm it (contract › rule changes).
  live,

  /// At a pause, or on pause and end: 006's final-segment rules.
  pause,
}

/// One word heard: cleaned and normalised, and where it starts and ends in the session's audio.
class HeardWord {
  const HeardWord(this.text, this.startSample, [int? endSample]) : endSample = endSample ?? startSample;

  final String text;

  /// Sample index (16 kHz) from the start of the session, already [anchorMargin] early.
  final int startSample;

  /// Where its last piece was heard. Nothing heard after it for a while means the word was
  /// finished (memorization_controller.dart › wordEndGap).
  final int endSample;

  @override
  bool operator ==(Object other) =>
      other is HeardWord && other.text == text && other.startSample == startSample;

  @override
  int get hashCode => Object.hash(text, startSample);

  @override
  String toString() => 'HeardWord($text, $startSample)';
}

/// Unicode punctuation, which includes the Arabic comma, semicolon and question mark (، ؛ ؟),
/// the full stop ۔ and the percent and star signs ٪ ٭. Khatma writes some (research R6).
final _punctuation = RegExp(r'\p{P}', unicode: true);

/// Joins sherpa-onnx's pieces into words. A piece starting with a space (sherpa-onnx's spelling of
/// SentencePiece's `▁`) or with `▁` starts a word; [timestamps] are the pieces' reported times
/// in seconds from [windowStart]. Words that are empty once cleaned are dropped.
List<HeardWord> wordsFromPieces(List<String> tokens, List<double> timestamps,
    {required int windowStart}) {
  final words = <HeardWord>[];
  final text = StringBuffer();
  var start = 0, end = 0;

  void close() {
    final cleaned = normalizeArabic(text.toString().replaceAll(_punctuation, ''));
    if (cleaned.isNotEmpty) words.add(HeardWord(cleaned, start, end));
    text.clear();
  }

  int at(int i) =>
      windowStart + ((i < timestamps.length ? timestamps[i] : 0.0) * khatmaFrameScale * micSampleRate).round();

  for (var i = 0; i < tokens.length; i++) {
    final piece = tokens[i];
    if (text.isEmpty || piece.startsWith(' ') || piece.startsWith('▁')) {
      if (text.isNotEmpty) close();
      start = math.max(windowStart, at(i) - (anchorMargin * micSampleRate).round());
    }
    end = at(i);
    text.write(piece.replaceAll('▁', ' '));
  }
  if (text.isNotEmpty) close();
  return words;
}
