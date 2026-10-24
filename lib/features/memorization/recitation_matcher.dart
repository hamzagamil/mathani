// Follows a recitation word by word against the ayat being memorised (specs/006
// contracts/memorization-engine.md › RecitationMatcher, research R11). Pure Dart: no Flutter or
// plugin imports, so it is tested over the whole Quran without a device.
import 'dart:math' as math;

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
  });

  /// Words matched or hinted in this call, as (index of the ayah in the range, position).
  final List<(int, int)> matched;

  /// Mistakes declared in this call, in the ayah expected after it ([RecitationMatcher.ayahIndex]).
  final List<AyahMistake> mistakes;

  /// Indexes of the ayat completed in this call, in order. A segment can complete several short
  /// ayat recited without a pause.
  final List<int> completed;

  bool get ayahCompleted => completed.isNotEmpty;

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

  /// Matches [tokens], one segment of the recogniser's output, already normalised and split.
  /// Mistakes are declared only on a [finalSegment] (rules 4–7).
  MatchEvents accept(List<String> tokens, {required bool finalSegment}) {
    if (done) return MatchEvents.none; // rule 9
    final matched = <(int, int)>[];
    final mistakes = <AyahMistake>[];
    final completed = <int>[];
    var progressed = false;
    String? unclearHeard;
    var unclearClose = false;
    var i = 0;
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
      // Rules 2, 4 and 5: back to an earlier word (a repeat or a restart), or a mistake. Each
      // reading is scored by how many of the following words line up with it; a tie goes to
      // going back, which is never a mistake.
      final (backTo, backRun) = _bestBack(tokens, i);
      final mistake = _explain(tokens, i,
          beat: backRun, heardBefore: unclearHeard ?? (i == 0 ? _pendingHeard : null));
      if (mistake == null && backTo != null) {
        final m = _matchAt(tokens, i, backTo)!;
        _cursor = backTo + m.$2;
        i += m.$1;
        unclearHeard = null;
        unclearClose = false;
        continue;
      }
      if (!finalSegment) break; // rule 7: provisional output never declares mistakes
      final token = tokens[i];
      if (mistake != null) {
        mistakes.add(mistake);
        tallies[_ayah].mistakes.add(mistake);
        tallies[_ayah].started = true;
        _unclearSegments = 0;
        break; // the reader carries on from the wrong word; the rest of the segment is dropped
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
            final m = AyahMistake(_positionAt(_cursor), MistakeKind.wrong, unclearHeard);
            mistakes.add(m);
            tallies[_ayah].mistakes.add(m);
            tallies[_ayah].started = true;
            _unclearSegments = 0;
            _pendingHeard = null;
          }
        } else if (progressed) {
          _unclearSegments = 0;
          // A word left unexplained at the end, after progress, may be the start of a mistake.
          if (unclearHeard != null) _pendingHeard = unclearHeard;
        }
      }
    }
    return MatchEvents(matched: matched, mistakes: mistakes, completed: completed);
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
  /// tokens). Null when nothing explains it.
  AyahMistake? _explain(List<String> tokens, int i, {required int beat, String? heardBefore}) {
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
    if (nextWords.isNotEmpty) {
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
    return best;
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
    _complete();
    return MatchEvents(completed: [ayah]);
  }
}
