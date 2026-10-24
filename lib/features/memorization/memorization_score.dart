// The result of a memorization session (specs/006 data-model › Session Result; FR-023, FR-024).
// Pure Dart, so the score rule is tested without a device.
import 'recitation_matcher.dart';

/// How an ayah of the range ended; an ayah counts by its weakest outcome.
enum AyahOutcome { noMistake, corrected, hinted, revealed, notReached }

/// Credit of each outcome in the score (FR-024).
const outcomeCredit = {
  AyahOutcome.noMistake: 1.0,
  AyahOutcome.corrected: 0.5,
  AyahOutcome.hinted: 0.25,
  AyahOutcome.revealed: 0.0,
};

/// One ayah of the range at the end of the session, for the score and the review.
class AyahProgress {
  const AyahProgress(this.outcome,
      {this.mistakes = const [], this.hints = const {}, this.unfinished = false});

  /// The outcome of [tally]: revealed, then hinted, then corrected, then no mistake. An ayah not
  /// finished when the session ended (including the one being recited) is not reached
  /// (data-model, FR-024).
  factory AyahProgress.of(AyahTally tally) {
    final outcome = !tally.complete
        ? AyahOutcome.notReached
        : tally.revealed
            ? AyahOutcome.revealed
            : tally.hints.isNotEmpty
                ? AyahOutcome.hinted
                : tally.mistakes.isNotEmpty
                    ? AyahOutcome.corrected
                    : AyahOutcome.noMistake;
    return AyahProgress(
      outcome,
      mistakes: List.unmodifiable(tally.mistakes),
      hints: Set.unmodifiable(tally.hints),
      unfinished: outcome == AyahOutcome.notReached && tally.started,
    );
  }

  final AyahOutcome outcome;
  final List<AyahMistake> mistakes;

  /// Word positions shown with "Next word".
  final Set<int> hints;

  /// Started but not finished when the session ended: shown as "not finished" in the review.
  final bool unfinished;
}

/// The score, counts and review of a session; shown once at the end and never kept (FR-026).
class SessionResult {
  SessionResult(this.review) : counts = _count(review);

  /// From the matcher's tallies, one per ayah of the range, in order.
  factory SessionResult.fromTallies(List<AyahTally> tallies) =>
      SessionResult([for (final t in tallies) AyahProgress.of(t)]);

  /// The range's ayat in order.
  final List<AyahProgress> review;
  final Map<AyahOutcome, int> counts;

  static Map<AyahOutcome, int> _count(List<AyahProgress> review) => {
        for (final o in AyahOutcome.values) o: review.where((p) => p.outcome == o).length,
      };

  int get reached => review.length - counts[AyahOutcome.notReached]!;

  /// Out of 100, rounded half away from zero; null when no ayah was reached (shown as «—»).
  int? get score {
    if (reached == 0) return null;
    var credit = 0.0;
    for (final p in review) {
      credit += outcomeCredit[p.outcome] ?? 0;
    }
    return (100 * credit / reached).round();
  }
}
