// Plain Dart, no Flutter (specs/013 research R8).

/// Words shown on a tab before it is cut with «…» (specs/013 FR-018).
const tabLabelWords = 5;

/// Pause marks, the hizb mark and the sajdah mark: left out of a tab's text.
final _marks = RegExp('[ۖ-ۜ۞۩]');
final _spaces = RegExp(r'\s+');

/// The tab texts of the «عرض المتشابه» sheet for an ayah in several groups (specs/013
/// contracts/reader-ui.md › Similar-ayah tabs): one per group, in the order given.
///
/// [pressed] is the pressed ayah's Uthmani words without its end marker. [groups] holds, for
/// each group, the words of each of its other ayat. Words are compared by [key]. A tab shows the
/// longest run of [pressed] found in at least half of the group's other ayat, or, when that is
/// under two words, the longest run found in one of them; with no run it shows [number] of its
/// place. Tabs that would read the same get their number added.
List<String> tabLabels({
  required List<String> pressed,
  required List<List<List<String>>> groups,
  required String Function(String word) key,
  required String Function(int n) number,
}) {
  final keys = [for (final w in pressed) key(w)];
  final labels = <String>[];
  final wording = <bool>[];
  for (var g = 0; g < groups.length; g++) {
    // For each other ayah, the longest match that starts at each word of the pressed ayah.
    final matches = [
      for (final ayah in groups[g]) _matchLengths(keys, [for (final w in ayah) key(w)]),
    ];
    var (start, length) = _longestRun(matches, keys.length, (matches.length + 1) ~/ 2);
    if (length < 2) {
      final (anyStart, anyLength) = _longestRun(matches, keys.length, 1);
      if (anyLength > length) (start, length) = (anyStart, anyLength);
    }
    wording.add(length > 0);
    labels.add(length > 0 ? _label(pressed.sublist(start, start + length)) : number(g + 1));
  }
  final count = <String, int>{};
  for (final l in labels) {
    count[l] = (count[l] ?? 0) + 1;
  }
  return [
    for (var g = 0; g < labels.length; g++)
      wording[g] && count[labels[g]]! > 1 ? '${labels[g]} (${number(g + 1)})' : labels[g],
  ];
}

/// For each index of [a], the length of the longest run starting there that is also in [b].
List<int> _matchLengths(List<String> a, List<String> b) {
  final best = List.filled(a.length, 0);
  var next = List.filled(b.length + 1, 0); // run lengths for a[i + 1]
  for (var i = a.length - 1; i >= 0; i--) {
    final row = List.filled(b.length + 1, 0);
    for (var j = b.length - 1; j >= 0; j--) {
      if (a[i] == b[j]) {
        final run = next[j + 1] + 1;
        row[j] = run;
        if (run > best[i]) best[i] = run;
      }
    }
    next = row;
  }
  return best;
}

/// The earliest longest run found in at least [needed] ayat: its start and length (0: none).
(int, int) _longestRun(List<List<int>> matches, int words, int needed) {
  if (needed < 1 || matches.length < needed) return (0, 0);
  var start = 0, length = 0;
  for (var i = 0; i < words; i++) {
    final here = [for (final m in matches) m[i]]..sort((x, y) => y.compareTo(x));
    if (here[needed - 1] > length) (start, length) = (i, here[needed - 1]);
  }
  return (start, length);
}

String _label(List<String> run) {
  final words = [
    for (final w in run.take(tabLabelWords)) w.replaceAll(_marks, '').trim().replaceAll(_spaces, ' '),
  ];
  return '${words.join(' ')}${run.length > tabLabelWords ? '…' : ''}';
}
