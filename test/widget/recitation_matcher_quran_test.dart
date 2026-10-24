import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/memorization/recitation_matcher.dart';

import '../support/harness.dart';

/// The matcher's property test over all 6,236 ayat (specs/006 T031): an ayah's own words complete
/// it with no mistake; dropping, swapping or inserting one word declares exactly one mistake of the
/// right kind, at the right place. Positions are sampled in long ayat to keep the run short.
void main() {
  testWidgets('every ayah, and one-word mistakes in it', (tester) async {
    final reader = (await tester.runAsync(openTestReader))!;
    final quran = reader.quran;
    const foreign = 'قققق'; // close to no word of the Quran
    var ayat = 0, mutations = 0;
    final failures = <String>[];

    for (final surah in quran.surahList) {
      final words = (await tester.runAsync(
          () => quran.memorizationWords(surah.number, 1, surah.ayahCount)))!;
      expect(words, hasLength(surah.ayahCount));
      for (var a = 0; a < words.length; a++) {
        final ref = [for (final w in words[a]) RefWord(w.wordId, w.position, w.form)];
        final forms = [for (final w in ref) w.form];
        final tokens = [for (final f in forms) ...f.split(' ')];
        ayat++;

        // The ayah's own words complete it with no mistake.
        final own = RecitationMatcher([ref]).accept(tokens, finalSegment: true);
        if (!own.ayahCompleted || own.mistakes.isNotEmpty) {
          failures.add('${surah.number}:${a + 1} own words: ${own.mistakes}');
        }

        final n = forms.length;
        final step = n <= 12 ? 1 : n ~/ 6;
        for (var p = 1; p <= n; p += step) {
          bool similar(String x, String y) => similarity(x, y) >= thetaMatch;
          // Positions where the mutation is ambiguous for any listener: the neighbouring word
          // repeats the word at p, or the words after p repeat words before it.
          final repeatsEarlier = p < n && [for (var j = 0; j < p; j++) forms[j]].any((f) => similar(f, forms[p]));
          final repeatsNeighbour = p < n && similar(forms[p - 1], forms[p]);

          void check(String label, List<String> mutated, MistakeKind kind) {
            mutations++;
            final m = RecitationMatcher([ref]);
            final e = m.accept(mutated, finalSegment: true);
            final ok = e.mistakes.length == 1 &&
                e.mistakes.single.kind == kind &&
                e.mistakes.single.position == p &&
                !e.ayahCompleted;
            if (!ok) failures.add('${surah.number}:${a + 1} $label at $p: ${e.mistakes}');
          }

          List<String> tokensOf(List<String> fs) => [for (final f in fs) ...f.split(' ')];
          if (p < n && !repeatsEarlier && !repeatsNeighbour) {
            check('drop', tokensOf([...forms.sublist(0, p - 1), ...forms.sublist(p)]),
                MistakeKind.missed);
          }
          if (p < n && !repeatsNeighbour) {
            check('swap', tokensOf([...forms.sublist(0, p - 1), foreign, ...forms.sublist(p)]),
                MistakeKind.wrong);
          }
          if (!repeatsEarlier || p == 1) {
            check('insert', tokensOf([...forms.sublist(0, p - 1), foreign, ...forms.sublist(p - 1)]),
                MistakeKind.added);
          }
        }
      }
    }
    expect(ayat, 6236);
    final rate = 1 - failures.length / mutations;
    // ignore: avoid_print
    print('matcher property: $mutations mutations, ${failures.length} failed '
        '(${(rate * 100).toStringAsFixed(2)}% exact); first: ${failures.take(8).join(' | ')}');
    expect(failures.where((f) => f.contains('own words')), isEmpty);
    expect(failures, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
