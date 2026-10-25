import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/memorization/speech_words.dart';

/// Pieces and their times become cleaned words with their start (specs/007 T008).
void main() {
  test('pieces join into words that start at their first piece, less the margin', () {
    // Reported at 20 ms per frame: 0.10 s is Khatma's 0.40 s (khatmaFrameScale).
    final words = wordsFromPieces([' بِسْمِ', ' ال', 'لَّهِ', '،'], [0.02, 0.10, 0.12, 0.14],
        windowStart: 16000);
    expect(words, const [HeardWord('بسم', 16000), HeardWord('الله', 16000 + 6400 - 2560)]);
  });

  test('a word ends where its last piece was heard', () {
    final words = wordsFromPieces([' ال', 'لَّهِ', ' أَحَدٌ'], [0.10, 0.15, 0.30], windowStart: 0);
    expect([for (final w in words) w.endSample], [9600, 19200]);
  });

  test('SentencePiece word marks start words too', () {
    expect(wordsFromPieces(['▁قُلْ', '▁هُوَ'], [0.5, 1.0], windowStart: 0),
        const [HeardWord('قل', 32000 - 2560), HeardWord('هو', 64000 - 2560)]);
  });

  test('punctuation-only words are dropped', () {
    expect(wordsFromPieces([' يس', ' .', ' ؟'], [0.1, 0.2, 0.3], windowStart: 0).map((w) => w.text),
        ['يس']);
  });

  test('a word never starts before its window', () {
    final words = wordsFromPieces([' الم'], [0.0], windowStart: 48000);
    expect(words.single.startSample, 48000);
  });

  test('no pieces, no words', () {
    expect(wordsFromPieces(const [], const [], windowStart: 0), isEmpty);
  });
}
