// Print-like justification of Mushaf lines with kashida (tatweel, U+0640), so lines are filled
// by lengthening joins rather than by widening the gaps between words
// (specs/002-print-like-mushaf-page/contracts/page-typesetting.md, research P2).
//
// Pure Dart and unit-agnostic: widths may be in em or pixels, as long as they agree. Kashida is
// only ever added to the strings that are painted; the Quran text itself never changes (FR-005).
import 'dart:math' as math;

/// Gaps never tighten below this fraction of a normal space.
const minGapFactor = 0.5;

/// Gaps above this fraction of a normal space count as too wide (FR-002).
const maxGapFactor = 1.5;

/// Kashida fills a line until its gaps come down to about this fraction of a space.
const targetGapFactor = 1.25;

/// A line may shrink this far when it is still too wide with its gaps tightened (FR-004).
const minLineScale = 0.95;

/// Tatweels at any one join point.
const maxTatweelsPerPoint = 4;

const tatweel = 'ـ';
const _tatweel = 0x0640;

/// A place inside a word where tatweel may be inserted.
class JoinPoint {
  const JoinPoint(this.offset, this.priority);

  /// Index in the word after which tatweel goes: after a letter and all its combining marks.
  final int offset;

  /// 0 after «س ش ص ض», 1 before the last letter, 2 otherwise. Lower is used first.
  final int priority;

  @override
  bool operator ==(Object other) =>
      other is JoinPoint && other.offset == offset && other.priority == priority;

  @override
  int get hashCode => Object.hash(offset, priority);

  @override
  String toString() => 'JoinPoint($offset, $priority)';
}

bool _isMark(int c) =>
    (c >= 0x0610 && c <= 0x061A) || // Quranic honorifics and small marks
    (c >= 0x064B && c <= 0x065F) || // tashkeel
    c == 0x0670 || // superscript alef
    (c >= 0x06D6 && c <= 0x06ED); // Quranic annotation marks and small letters

final _dualJoining = 'بتثجحخسشصضطظعغفقكلمنهيئى'.runes.toSet();
final _rightJoining = 'اأإآٱدذرزوؤة'.runes.toSet();
final _alefForms = 'اأإآٱ'.runes.toSet();
final _seenSad = 'سشصض'.runes.toSet();
const _lam = 0x0644;

/// The join points of [word], following the contract's rules: between two letters that join,
/// never inside lam-alef, never next to an existing tatweel, never in the name of Allah, and
/// never in words of 2 letters or fewer.
List<JoinPoint> joinPoints(String word) {
  final units = word.codeUnits; // Arabic is in the BMP: one code unit per character
  final letters = <(int, int)>[]; // (letter, offset just after its marks)
  for (var i = 0; i < units.length; i++) {
    if (_isMark(units[i])) continue;
    var end = i + 1;
    while (end < units.length && _isMark(units[end])) {
      end++;
    }
    letters.add((units[i], end));
  }
  if (letters.where((l) => l.$1 != _tatweel).length <= 2) return const [];
  if (String.fromCharCodes(letters.map((l) => l.$1)).contains('لله')) return const [];

  final points = <JoinPoint>[];
  for (var k = 0; k + 1 < letters.length; k++) {
    final a = letters[k].$1, b = letters[k + 1].$1;
    if (a == _tatweel || b == _tatweel) continue;
    if (!_dualJoining.contains(a)) continue;
    if (!_dualJoining.contains(b) && !_rightJoining.contains(b)) continue;
    if (a == _lam && _alefForms.contains(b)) continue;
    final priority = _seenSad.contains(a) ? 0 : (k + 1 == letters.length - 1 ? 1 : 2);
    points.add(JoinPoint(letters[k].$2, priority));
  }
  return points;
}

/// [word] with `counts[offset]` tatweels inserted at each offset.
String withKashida(String word, Map<int, int> counts) {
  if (counts.values.every((n) => n == 0)) return word;
  final out = StringBuffer();
  for (var i = 0; i <= word.length; i++) {
    final n = counts[i] ?? 0;
    for (var k = 0; k < n; k++) {
      out.write(tatweel);
    }
    if (i < word.length) out.writeCharCode(word.codeUnitAt(i));
  }
  return out.toString();
}

/// How one line is set.
class LineJustification {
  const LineJustification({
    required this.tatweels,
    required this.gap,
    required this.scale,
    required this.width,
    required this.centered,
    required this.overGap,
  });

  /// Per word: join-point offset → tatweels to insert there.
  final List<Map<int, int>> tatweels;

  /// Space between words, before [scale].
  final double gap;

  /// Shrink factor for the whole line; below 1 only for lines too wide with tight gaps.
  final double scale;

  /// Width of the line as set, after [scale].
  final double width;

  /// Set at its natural width and centred, not justified.
  final bool centered;

  /// The line ran out of join points, so its gaps stay wider than [maxGapFactor] × space.
  final bool overGap;

  int get tatweelCount => tatweels.fold(0, (s, m) => s + m.values.fold(0, (a, b) => a + b));
}

/// Sets a line of words to [target] (contract › Line justification).
///
/// [wordWidths] are the words' natural widths, [points] their join points, [space] the width of
/// a normal space and [tatweel] the width one tatweel adds.
LineJustification justifyLine({
  required List<double> wordWidths,
  required double space,
  required double tatweel,
  required List<List<JoinPoint>> points,
  required double target,
  required bool centered,
}) {
  final n = wordWidths.length;
  final gaps = n - 1;
  final none = [for (var i = 0; i < n; i++) <int, int>{}];
  final words = wordWidths.fold<double>(0, (s, w) => s + w);

  if (centered || gaps == 0) {
    return LineJustification(
      tatweels: none,
      gap: space,
      scale: 1,
      width: words + gaps * space,
      centered: true,
      overGap: false,
    );
  }

  // Too wide: tighten the gaps, then shrink, never below minLineScale.
  if (words + gaps * space > target) {
    final minGap = minGapFactor * space;
    final tight = words + gaps * minGap;
    if (tight <= target) {
      return LineJustification(
        tatweels: none,
        gap: (target - words) / gaps,
        scale: 1,
        width: target,
        centered: false,
        overGap: false,
      );
    }
    final scale = math.max(minLineScale, target / tight);
    return LineJustification(
      tatweels: none,
      gap: minGap,
      scale: scale,
      width: tight * scale,
      centered: false,
      overGap: false,
    );
  }

  // Short: lengthen joins round-robin across the words, then let the gaps take the rest.
  final counts = [for (var i = 0; i < n; i++) <int, int>{}];
  final order = [
    for (final p in points) [...p]..sort((a, b) => a.priority.compareTo(b.priority)),
  ];
  var added = 0;
  double gapNow() => (target - words - added * tatweel) / gaps;

  /// Adds one tatweel to word [i] at its best point with room, so a word gets one longer
  /// stretch, as in print, before a second one; false if all its points are full.
  bool addTo(int i) {
    for (final p in order[i]) {
      final c = counts[i][p.offset] ?? 0;
      if (c < maxTatweelsPerPoint) {
        counts[i][p.offset] = c + 1;
        added++;
        return true;
      }
    }
    return false;
  }

  /// One pass over the words; false once no word can take more.
  bool pass(bool Function() wantMore) {
    var any = false;
    for (var i = 0; i < n && wantMore(); i++) {
      if (order[i].isEmpty) continue;
      any = addTo(i) || any;
    }
    return any;
  }

  // Fill until the gaps come down to about targetGapFactor × space...
  while (gapNow() - targetGapFactor * space > tatweel / (2 * gaps)) {
    if (!pass(() => gapNow() - targetGapFactor * space > tatweel / (2 * gaps))) break;
  }
  // ...and never leave them wider than maxGapFactor × space while a point has room.
  while (gapNow() > maxGapFactor * space) {
    if (!pass(() => gapNow() > maxGapFactor * space)) break;
  }

  final gap = gapNow();
  return LineJustification(
    tatweels: counts,
    gap: gap,
    scale: 1,
    width: target,
    centered: false,
    overGap: gap > maxGapFactor * space + 1e-9,
  );
}
