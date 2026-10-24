import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/memorization/memorization_score.dart';
import 'package:mathani/features/memorization/recitation_matcher.dart';

/// The score rule (specs/006 T050, FR-024): 1 / 0.5 / 0.25 / 0 over the ayat reached, the weakest
/// outcome of an ayah wins, rounded half away from zero, and «—» when nothing was reached.
void main() {
  AyahTally tally({bool complete = true, int mistakes = 0, int hints = 0, bool revealed = false,
      bool started = true}) {
    final t = AyahTally()
      ..complete = complete
      ..revealed = revealed
      ..started = started;
    for (var i = 0; i < mistakes; i++) {
      t.mistakes.add(AyahMistake(i + 1, MistakeKind.missed));
    }
    for (var i = 0; i < hints; i++) {
      t.hints.add(i + 1);
    }
    return t;
  }

  test('User Story 3: Al-Mulk 1–10 scores 72', () {
    // 1–4 correct, a correction in 5, a hint in 6, 7 revealed, 8 correct, then End mid-9.
    final result = SessionResult.fromTallies([
      for (var a = 1; a <= 4; a++) tally(),
      tally(mistakes: 1),
      tally(hints: 1),
      tally(revealed: true),
      tally(),
      tally(complete: false), // being recited when the reader ended: not reached
      tally(complete: false, started: false),
    ]);
    expect(result.score, 72, reason: '(5 + 0.5 + 0.25 + 0) / 8 × 100 = 71.875');
    expect(result.reached, 8);
    expect(result.counts, {
      AyahOutcome.noMistake: 5,
      AyahOutcome.corrected: 1,
      AyahOutcome.hinted: 1,
      AyahOutcome.revealed: 1,
      AyahOutcome.notReached: 2,
    });
  });

  test('quickstart Q-12: Al-Ikhlas scores 69', () {
    final result = SessionResult.fromTallies(
        [tally(), tally(mistakes: 1), tally(hints: 1), tally()]);
    expect(result.score, 69, reason: '(1 + 0.5 + 0.25 + 1) / 4 × 100 = 68.75');
  });

  test('the weakest outcome wins: revealed, then hinted, then corrected', () {
    expect(AyahProgress.of(tally(mistakes: 2, hints: 1, revealed: true)).outcome,
        AyahOutcome.revealed);
    expect(AyahProgress.of(tally(mistakes: 2, hints: 1)).outcome, AyahOutcome.hinted);
    expect(AyahProgress.of(tally(mistakes: 2)).outcome, AyahOutcome.corrected);
    expect(AyahProgress.of(tally()).outcome, AyahOutcome.noMistake);
  });

  test('nothing reached gives no score; rounding is half away from zero', () {
    expect(SessionResult.fromTallies([tally(complete: false)]).score, isNull);
    // 1 of 8 corrected, 7 with no mistake: 7.5 / 8 = 93.75 → 94.
    expect(SessionResult.fromTallies([tally(mistakes: 1), for (var i = 0; i < 7; i++) tally()]).score,
        94);
    // 1 hinted of 2: 1.25 / 2 = 62.5 → 63.
    expect(SessionResult.fromTallies([tally(hints: 1), tally()]).score, 63);
  });
}
