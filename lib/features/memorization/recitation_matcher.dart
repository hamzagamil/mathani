// Follows a recitation word by word against the ayat being memorised (specs/006
// contracts/memorization-engine.md › RecitationMatcher, research R11; specs/007
// contracts/live-recognition.md › RecitationMatcher). Pure Dart: no Flutter or plugin imports, so
// it is tested over the whole Quran without a device.
import 'dart:math' as math;

import 'speech_words.dart';

export 'speech_words.dart' show Hearing;

/// Similarity at which a heard word matches a word of the ayah (tuned in spike S1, T035).
const thetaMatch = 0.75;

/// Below [thetaMatch] but at least this: an unclear word. It never advances and is never a
/// mistake by itself.
const thetaUnsure = 0.55;

/// How far ahead a skip is recognised as a missed word.
const lookAhead = 3;

/// Similarity a joined reading (two heard words for one, or one for two) needs.
const joinMatch = 0.9;

/// Final segments in a row with only unclear words at the same place before it counts as wrong.
const unclearSegmentsForMistake = 2;

/// While the reader keeps reciting, a mistake is declared only when at least this many of the
/// words heard after it line up with the reading that explains it (specs/007 research R5, FR-009).
const liveMistakeRun = 2;

/// While the reader keeps reciting, a mistake is declared only once this many live passes in a
/// row found it at the same word: the model hears short words differently from one window to the
/// next («من» heard «منن», then not at all; desktop live run, research R5).
const livePassesForMistake = 2;

/// One word of an ayah: its Uthmani word id (to show or hide it on the page), its 1-based
/// position in the ayah, and its imla'i form normalised like the recogniser's output.
class RefWord {
  const RefWord(this.wordId, this.position, this.form);

  final int wordId;
  final int position;
  final String form;
}

enum MistakeKind { missed, wrong, added }

/// A mistake in the expected ayah, at word [position] (an added word sits before it). [heard] is
/// the normalised word heard, for wrong and added words; kept only in memory, for the review.
class AyahMistake {
  const AyahMistake(this.position, this.kind, [this.heard]);

  final int position;
  final MistakeKind kind;
  final String? heard;

  @override
  bool operator ==(Object other) =>
      other is AyahMistake && other.position == position && other.kind == kind;

  @override
  int get hashCode => Object.hash(position, kind);

  @override
  String toString() => 'AyahMistake($position, ${kind.name}${heard == null ? '' : ', $heard'})';
}

/// The thresholds of the matcher; [MatchTuning.new] is what the app uses.
class MatchTuning {
  const MatchTuning({
    this.match = thetaMatch,
    this.unsure = thetaUnsure,
    this.ahead = lookAhead,
  });

  final double match;
  final double unsure;
  final int ahead;
}

/// What one call to the matcher changed.
class MatchEvents {
  const MatchEvents({
    this.matched = const [],
    this.mistakes = const [],
    this.completed = const [],
    this.lastMatchedToken = -1,
    this.droppedRest = false,
  });

  /// Words matched or hinted in this call, as (index of the ayah in the range, position).
  final List<(int, int)> matched;

  /// Mistakes declared in this call, in the ayah expected after it ([RecitationMatcher.ayahIndex]).
  final List<AyahMistake> mistakes;

  /// Indexes of the ayat completed in this call, in order. A segment can complete several short
  /// ayat recited without a pause.
  final List<int> completed;

  bool get ayahCompleted => completed.isNotEmpty;

  /// Index in the tokens of the last one matched to a word, going forward or back; -1 if none.
  /// The live follow moves its anchor to that word (specs/007 contract › MemorizationController).
  final int lastMatchedToken;

  /// The tokens after a mistake were dropped, also when the mistake was not declared again
  /// (rule 11): everything heard up to the end of this pass has been used.
  final bool droppedRest;

  static const none = MatchEvents();
}

/// What the reader did in one ayah of the range, for the score and the review.
class AyahTally {
  final mistakes = <AyahMistake>[];
  final hints = <int>{};
  bool revealed = false;
  bool complete = false;

  /// Some words recited or hinted, but not complete: the ayah the reader was in when they ended.
  bool started = false;
}

/// The isti'adha and basmala, which readers may recite before an ayah (FR-014): ignored unless
/// they are the expected words (1:1, 27:30).
const _openings = [
  ['اعوذ', 'بالله', 'من', 'الشيطان', 'الرجيم'],
  ['بسم', 'الله', 'الرحمن', 'الرحيم'],
];

/// Spelling pairs that normalisation leaves different between the Uthmani-influenced forms a
/// recogniser may write and the imla'i reference (T037). Applied to both sides before comparing.
const kVariantPairs = <(String, String)>[
  ('الصلوه', 'الصلاه'),
  ('الزكوه', 'الزكاه'),
  ('الحيوه', 'الحياه'),
  ('النجوه', 'النجاه'),
  ('مشكوه', 'مشكاه'),
  ('ابرهيم', 'ابراهيم'),
  ('اسمعيل', 'اسماعيل'),
  ('اسحق', 'اسحاق'),
  ('الرحمن', 'الرحمان'),
  ('هذا', 'هاذا'),
  ('هذه', 'هاذه'),
  ('ذلك', 'ذالك'),
  ('لكن', 'لاكن'),
  ('اولئك', 'اولائك'),
  ('السموت', 'السماوات'),
  ('يايها', 'يا ايها'),
];

/// [word] with every variant spelling replaced by its imla'i form.
String canonical(String word) {
  var w = word;
  for (final (variant, imlaei) in kVariantPairs) {
    if (w.contains(variant)) w = w.replaceAll(variant, imlaei);
  }
  return w;
}

/// `1 − levenshtein(a, b) / max(|a|, |b|)` on canonical forms.
double similarity(String a, String b) {
  final x = canonical(a), y = canonical(b);
  if (x == y) return 1;
  if (x.isEmpty || y.isEmpty) return 0;
  var previous = List<int>.generate(y.length + 1, (j) => j);
  for (var i = 1; i <= x.length; i++) {
    final current = List<int>.filled(y.length + 1, 0)..[0] = i;
    for (var j = 1; j <= y.length; j++) {
      final cost = x.codeUnitAt(i - 1) == y.codeUnitAt(j - 1) ? 0 : 1;
      current[j] = math.min(math.min(current[j - 1] + 1, previous[j] + 1), previous[j - 1] + cost);
    }
    previous = current;
  }
  return 1 - previous[y.length] / math.max(x.length, y.length);
}

/// Aligns what the reader recites with the ayat of a memorization range (rules 1–9 of the
/// contract). The expected ayah is revealed only once every one of its words was matched or
/// hinted, in order. After a mistake the reader carries on from the word they got wrong
/// (Clarification Q1).
class RecitationMatcher {
  RecitationMatcher(List<List<RefWord>> ayat, {this.tuning = const MatchTuning()})
      : ayat = [
          for (final words in ayat)
            [
              for (final w in words)
                for (final part in w.form.split(' '))
                  if (part.isNotEmpty) RefWord(w.wordId, w.position, part),
            ],
        ],
        tallies = [for (final _ in ayat) AyahTally()];

  /// The range's ayat, each as its reference words in order. A word whose imla'i form is
  /// several words (يَبْنَؤُمَّ: «يا ابن ام») is split into parts that share its id and position.
  final List<List<RefWord>> ayat;
  final MatchTuning tuning;

  /// One per ayah of [ayat].
  final List<AyahTally> tallies;

  int _ayah = 0;
  int _cursor = 1;
  int _unclearSegments = 0;

  /// The unexplained word that ended the previous final segment at the cursor, if any.
  String? _pendingHeard;

  /// The last mistake declared in this stretch of speech, as (ayah, position): not declared again
  /// until a pause pass ends the stretch (rule 11).
  (int, int)? _lastMistakeInStretch;

  /// A mistake one live pass found and the next must find again, as (ayah, position), with the
  /// passes that found it so far.
  (int, int)? _liveSuspect;
  int _liveSuspectPasses = 0;

  /// Index in [ayat] of the expected ayah; equals `ayat.length` once the range is done.
  int get ayahIndex => _ayah;

  /// 1-based index of the next part of the expected ayah ([ayat] parts, not word positions).
  int get cursor => _cursor;

  /// Word position of the part at [index] (1-based) of the expected ayah, for mistakes.
  int _positionAt(int index) {
    final words = _words;
    return words[(index.clamp(1, words.length)) - 1].position;
  }

  bool get done => _ayah >= ayat.length;

  List<RefWord> get _words => ayat[_ayah];

  bool _matches(String token, String word) => similarity(token, word) >= tuning.match;

  /// How many tokens from [i] match how many words from position [p] (1-based), or null. Also
  /// accepts two tokens for one word and one token for two words, as recognisers split and join
  /// Arabic words differently from the imla'i text; the most similar reading wins.
  (int, int)? _matchAt(List<String> tokens, int i, int p, [int? ayah]) {
    final words = ayat[ayah ?? _ayah];
    if (p < 1 || p > words.length || i >= tokens.length) return null;
    (int, int)? best;
    var bestSimilarity = tuning.match;
    void consider((int, int) reading, String heard, String word) {
      final s = similarity(heard, word);
      if (s > bestSimilarity || (best == null && s >= bestSimilarity)) {
        best = reading;
        bestSimilarity = s;
      }
    }

    consider((1, 1), tokens[i], words[p - 1].form);
    // Joined readings must be near-exact, or a word left out would hide inside the join.
    final single = bestSimilarity;
    bestSimilarity = math.max(bestSimilarity, joinMatch);
    if (single < 1 && i + 1 < tokens.length) {
      consider((2, 1), '${tokens[i]}${tokens[i + 1]}', words[p - 1].form);
    }
    if (single < 1 && p < words.length) {
      consider((1, 2), tokens[i], '${words[p - 1].form}${words[p].form}');
    }
    // Two words heard with the space in the wrong place («وسعكر سيه» for «وسع كرسيه»).
    if (single < 1 && i + 1 < tokens.length && p < words.length) {
      consider((2, 2), '${tokens[i]}${tokens[i + 1]}', '${words[p - 1].form}${words[p].form}');
    }
    return best;
  }

  /// Length of an opening (isti'adha or basmala) at [i] in [tokens], or 0.
  int _openingAt(List<String> tokens, int i) {
    for (final opening in _openings) {
      if (i + opening.length > tokens.length) continue;
      var all = true;
      for (var k = 0; k < opening.length && all; k++) {
        all = _matches(tokens[i + k], opening[k]);
      }
      if (!all) continue;
      // Not ignored when it is the expected text itself (1:1, 27:30).
      final expected = [for (final w in _words.skip(_cursor - 1).take(opening.length)) w.form];
      final isExpected = expected.length == opening.length &&
          [for (var k = 0; k < opening.length; k++) _matches(expected[k], opening[k])].every((m) => m);
      return isExpected ? 0 : opening.length;
    }
    return 0;
  }

  /// Matches [tokens], the words of one pass of the recogniser, already normalised. A live pass
  /// declares a mistake only when [liveMistakeRun] words confirm it; a pause pass follows 006's
  /// final-segment rules (rules 4–7, 10, 11). [startsOnMatched]: the pass was decoded from the
  /// start of the last word matched, so its first word is that word again (rule 12).
  MatchEvents accept(List<String> tokens, {required Hearing hearing, bool startsOnMatched = false}) {
    if (done) return MatchEvents.none; // rule 9
    final finalSegment = hearing == Hearing.pause;
    var lastMatched = -1;
    var dropped = false;
    var suspected = false;
    // Rule 12: the first word of a pass that starts on the last word matched is that word, not the
    // next one, even when the two look alike («الله والله»).
    final again = startsOnMatched ? _lastWordAt(tokens) : 0;
    final matched = <(int, int)>[];
    final mistakes = <AyahMistake>[];
    final completed = <int>[];
    var progressed = false;
    String? unclearHeard;
    var unclearClose = false;
    var i = again;
    if (again > 0) lastMatched = again - 1;
    while (i < tokens.length && !done) {
      final words = _words;
      // Rule 3: an opening before the ayah is ignored.
      if (_cursor == 1) {
        final opening = _openingAt(tokens, i);
        if (opening > 0) {
          i += opening;
          continue;
        }
      }
      // Rule 1: the next word.
      final next = _matchAt(tokens, i, _cursor);
      if (next != null) {
        for (var k = 0; k < next.$2; k++) {
          matched.add((_ayah, _cursor + k));
        }
        _cursor += next.$2;
        i += next.$1;
        lastMatched = i - 1;
        progressed = true;
        unclearHeard = null; // what came before is explained by moving on
        unclearClose = false;
        tallies[_ayah].started = true;
        if (_cursor > words.length) {
          completed.add(_ayah);
          progressed = false; // the next ayah starts fresh
          _complete();
        }
        continue;
      }
      // Rule 10: at the start of an ayah, the end of the previous one said again (a window that
      // starts on the word that completed it, or a reader linking the ayat).
      final linked = _cursor == 1 && _ayah > 0 ? _previousEndAt(tokens, i) : 0;
      if (linked > 0) {
        i += linked;
        lastMatched = i - 1;
        unclearHeard = null;
        unclearClose = false;
        continue;
      }
      // Rules 2, 4 and 5: back to an earlier word (a repeat or a restart), or a mistake. Each
      // reading is scored by how many of the following words line up with it; a tie goes to
      // going back, which is never a mistake.
      final (backTo, backRun) = _bestBack(tokens, i);
      var (mistake, run) = _explain(tokens, i,
          beat: backRun,
          heardBefore: unclearHeard ?? (i == 0 && finalSegment ? _pendingHeard : null),
          // A word of this ayah said again is a repeat, not a word said instead of the expected
          // one: a live window starts on the last word accepted.
          wrongAllowed: backTo == null);
      // A live pass needs the words after a mistake to confirm it (rules 4, 5 live), and the
      // words after a jump back too, unless it repeats the last word: one common word could go
      // back anywhere.
      final unconfirmed = !finalSegment && mistake != null && run < liveMistakeRun;
      if (unconfirmed) mistake = null;
      final canJudge = finalSegment || tokens.length - i - 1 >= liveMistakeRun;
      if (mistake == null &&
          backTo != null &&
          !unconfirmed &&
          (canJudge || backRun >= liveMistakeRun || backTo == _cursor - 1)) {
        final m = _matchAt(tokens, i, backTo)!;
        _cursor = backTo + m.$2;
        i += m.$1;
        lastMatched = i - 1;
        unclearHeard = null;
        unclearClose = false;
        continue;
      }
      // Rule 7 (specs/007): a live pass waits at a word it cannot judge yet, until enough words
      // follow it; with them and still no explanation, it goes on past it as a pause pass does.
      if (mistake == null && !canJudge) break;
      final token = tokens[i];
      if (mistake != null && !finalSegment && !_confirmedLive(mistake)) {
        suspected = true;
        break; // wait for the next pass to find it too
      }
      if (mistake != null) {
        _declare(mistake, mistakes);
        dropped = true;
        break; // the reader carries on from the wrong word; the rest of the pass is dropped
      }
      // An unclear or unexplained word: neither progress nor a mistake on its own (rule 6). Only
      // a word close to the expected one (an unclear word, not noise) can become a mistake by
      // persisting.
      unclearHeard = token;
      if (_cursor <= words.length && similarity(token, words[_cursor - 1].form) >= tuning.unsure) {
        unclearClose = true;
      }
      i++;
    }
    if (finalSegment) {
      _pendingHeard = null;
      if (mistakes.isEmpty && !done) {
        if (unclearHeard != null && !progressed) {
          _pendingHeard = unclearHeard;
          if (unclearClose && ++_unclearSegments >= unclearSegmentsForMistake) {
            _declare(AyahMistake(_positionAt(_cursor), MistakeKind.wrong, unclearHeard), mistakes);
            _pendingHeard = null;
          }
        } else if (progressed) {
          _unclearSegments = 0;
          // A word left unexplained at the end, after progress, may be the start of a mistake.
          if (unclearHeard != null) _pendingHeard = unclearHeard;
        }
      }
      _lastMistakeInStretch = null; // a pause ends the stretch of speech (rule 11)
    }
    if (!suspected) _liveSuspect = null; // only passes in a row confirm one another
    return MatchEvents(
        matched: matched,
        mistakes: mistakes,
        completed: completed,
        lastMatchedToken: lastMatched,
        droppedRest: dropped);
  }

  /// Whether this live pass is the [livePassesForMistake]th in a row to find [mistake].
  bool _confirmedLive(AyahMistake mistake) {
    final at = (_ayah, mistake.position);
    _liveSuspectPasses = _liveSuspect == at ? _liveSuspectPasses + 1 : 1;
    _liveSuspect = at;
    if (_liveSuspectPasses < livePassesForMistake) return false;
    _liveSuspect = null;
    return true;
  }

  /// Records [mistake] in the expected ayah, unless it is the one already declared at the same
  /// place in this stretch of speech (rule 11).
  void _declare(AyahMistake mistake, List<AyahMistake> declared) {
    _unclearSegments = 0;
    final at = (_ayah, mistake.position);
    if (_lastMistakeInStretch == at) return;
    _lastMistakeInStretch = at;
    declared.add(mistake);
    tallies[_ayah].mistakes.add(mistake);
    tallies[_ayah].started = true;
  }

  /// Rule 12: how many tokens at the start of [tokens] say the word before the cursor (or, at the
  /// start of an ayah, the last word of the previous one); 0 when they do not.
  int _lastWordAt(List<String> tokens) {
    if (_cursor > 1) {
      final wordId = _words[_cursor - 2].wordId;
      var p = _cursor - 1; // the first part of the last word matched
      while (p > 1 && _words[p - 2].wordId == wordId) {
        p--;
      }
      final whole = _readsTo(tokens, p, _cursor);
      return whole > 0 || p == _cursor - 1 ? whole : _readsTo(tokens, _cursor - 1, _cursor);
    }
    if (_ayah == 0) return 0;
    final previous = ayat[_ayah - 1];
    var p = previous.length;
    while (p > 1 && previous[p - 2].wordId == previous[p - 1].wordId) {
      p--;
    }
    final whole = _readsTo(tokens, p, previous.length + 1, _ayah - 1);
    return whole > 0 || p == previous.length
        ? whole
        : _readsTo(tokens, previous.length, previous.length + 1, _ayah - 1);
  }

  /// Tokens from the start of [tokens] that read parts [from]..[to) of an ayah exactly; 0 if not.
  int _readsTo(List<String> tokens, int from, int to, [int? ayah]) {
    var t = 0, q = from;
    while (q < to) {
      final m = _matchAt(tokens, t, q, ayah);
      if (m == null) return 0;
      t += m.$1;
      q += m.$2;
    }
    return q == to ? t : 0;
  }

  /// Rule 10: how many tokens from [i] say the last words of the previous ayah, in order, up to
  /// its end; 0 when they do not.
  int _previousEndAt(List<String> tokens, int i) {
    final previous = _ayah - 1;
    final length = ayat[previous].length;
    var best = 0;
    for (var p = length; p >= 1; p--) {
      var t = i, q = p;
      while (q <= length) {
        final m = _matchAt(tokens, t, q, previous);
        if (m == null) break;
        t += m.$1;
        q += m.$2;
      }
      if (q > length && t - i > best) best = t - i;
    }
    return best;
  }

  /// How many tokens from [i] go on matching the words of the expected ayah (or of [ayah]) from
  /// position [p], one by one (or split or joined as in [_matchAt]).
  int _run(List<String> tokens, int i, int p, [int? ayah]) {
    var n = 0;
    while (true) {
      final m = _matchAt(tokens, i, p, ayah);
      if (m == null) return n;
      n += m.$1;
      i += m.$1;
      p += m.$2;
    }
  }

  /// The earlier word of the ayah that the token at [i] best goes back to, with how many tokens
  /// line up from there; (null, 0) when it matches no earlier word.
  (int?, int) _bestBack(List<String> tokens, int i) {
    int? best;
    var bestRun = 0;
    for (var p = _cursor - 1; p >= 1; p--) {
      final run = _run(tokens, i, p);
      if (run > bestRun) {
        best = p;
        bestRun = run;
      }
    }
    return (best, bestRun);
  }

  /// Rules 4 and 5 for the token at [i], which does not match the word at the cursor: a wrong
  /// word (the tokens after it go on from the word after the cursor), a missed word (it is a
  /// word further on), or an added word (the tokens after it match the cursor). The reading whose
  /// following words line up best wins, and must line up better than going back ([beat]
  /// tokens). Null when nothing explains it; with it, how many tokens line up.
  (AyahMistake?, int) _explain(List<String> tokens, int i,
      {required int beat, String? heardBefore, bool wrongAllowed = true}) {
    final token = tokens[i];
    final words = _words;
    final position = _positionAt(_cursor);
    AyahMistake? best;
    var bestRun = beat;
    void consider(AyahMistake m, int run) {
      if (run > bestRun) {
        best = m;
        bestRun = run;
      }
    }

    // The first part of each of the next words after the cursor's word (a word can be several
    // imla'i parts).
    final nextWords = <int>[];
    for (var j = _cursor + 1; j <= words.length && nextWords.length < tuning.ahead; j++) {
      if (words[j - 1].wordId != words[j - 2].wordId) nextWords.add(j);
    }

    // Wrong: a different word, then the reader continues from the word after the cursor's.
    if (nextWords.isNotEmpty && wrongAllowed) {
      consider(AyahMistake(position, MistakeKind.wrong, token), _run(tokens, i + 1, nextWords.first));
    }
    // Missed: the token is a word up to lookAhead words further on. A word left unexplained just
    // before (in this segment, or ending the previous one) and then the next word means that word
    // was said wrongly.
    for (var k = 0; k < nextWords.length; k++) {
      consider(
        k == 0 && heardBefore != null
            ? AyahMistake(position, MistakeKind.wrong, heardBefore)
            : AyahMistake(position, MistakeKind.missed),
        _run(tokens, i, nextWords[k]),
      );
    }
    // Added: extra words, then the word at the cursor.
    for (var k = 1; k <= tuning.ahead && i + k < tokens.length; k++) {
      consider(AyahMistake(position, MistakeKind.added, token), _run(tokens, i + k, _cursor));
    }
    // On to the next ayah of the range, leaving words of this one out (edge case: reciting a
    // different ayah). At least two words must line up, so one common word is not enough.
    if (_ayah + 1 < ayat.length) {
      final run = _run(tokens, i, 1, _ayah + 1);
      final lastWord = nextWords.isEmpty;
      if (run >= 2) {
        consider(
          lastWord && heardBefore != null
              ? AyahMistake(position, MistakeKind.wrong, heardBefore)
              : AyahMistake(position, MistakeKind.missed),
          run,
        );
      }
    }
    return (best, bestRun);
  }

  bool _complete() {
    tallies[_ayah].complete = true;
    _ayah++;
    _cursor = 1;
    _unclearSegments = 0;
    _pendingHeard = null;
    return true;
  }

  /// Shows the next word of the expected ayah as a hint (FR-016); it counts as matched.
  MatchEvents hintNextWord() {
    if (done) return MatchEvents.none;
    final ayah = _ayah;
    final words = _words;
    final wordId = words[_cursor - 1].wordId;
    final position = words[_cursor - 1].position;
    tallies[ayah]
      ..hints.add(position)
      ..started = true;
    while (_cursor <= words.length && words[_cursor - 1].wordId == wordId) {
      _cursor++;
    }
    _unclearSegments = 0;
    _pendingHeard = null;
    _lastMistakeInStretch = null;
    final completed = _cursor > _words.length && _complete();
    return MatchEvents(matched: [(ayah, position)], completed: [if (completed) ayah]);
  }

  /// Reveals the rest of the expected ayah (FR-016).
  MatchEvents revealRest() {
    if (done) return MatchEvents.none;
    final ayah = _ayah;
    tallies[ayah]
      ..revealed = true
      ..started = true;
    _lastMistakeInStretch = null;
    _complete();
    return MatchEvents(completed: [ayah]);
  }
}
