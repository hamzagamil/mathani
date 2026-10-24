import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/memorization/recitation_matcher.dart';

/// The rules of the recitation matcher (specs/006 T031, contracts/memorization-engine.md ›
/// RecitationMatcher, rules 1–9), on Al-Ikhlas.
void main() {
  List<RefWord> ayah(String text) {
    final words = text.split(' ');
    return [for (var i = 0; i < words.length; i++) RefWord(1000 + i, i + 1, words[i])];
  }

  final ikhlas = [
    ayah('قل هو الله احد'),
    ayah('الله الصمد'),
    ayah('لم يلد ولم يولد'),
    ayah('ولم يكن له كفوا احد'),
  ];

  RecitationMatcher matcher([List<List<RefWord>>? ayat]) => RecitationMatcher(ayat ?? ikhlas);
  List<String> t(String s) => s.split(' ');

  test('rule 1: the next words advance; the ayah completes when all are matched', () {
    final m = matcher();
    var e = m.accept(t('قل هو'), finalSegment: true);
    expect(e.matched, [(0, 1), (0, 2)]);
    expect((e.ayahCompleted, m.cursor), (false, 3));
    e = m.accept(t('الله احد الله الصمد'), finalSegment: true);
    expect(e.completed, [0, 1], reason: 'two short ayat in one breath');
    expect((m.ayahIndex, m.cursor), (2, 1));
    expect(m.tallies[0].mistakes, isEmpty);
  });

  test('rule 2: going back within the ayah, repeating or restarting, is not a mistake', () {
    final m = matcher();
    final e = m.accept(t('قل هو قل هو الله الله احد'), finalSegment: true);
    expect(e.ayahCompleted, isTrue);
    expect(e.mistakes, isEmpty);
  });

  test('rule 3: an opening isti\'adha and basmala are ignored, except as the expected words', () {
    final m = matcher();
    final e = m.accept(t('اعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم قل هو الله احد'),
        finalSegment: true);
    expect(e.ayahCompleted, isTrue);
    expect(e.mistakes, isEmpty);

    final fatiha = matcher([ayah('بسم الله الرحمن الرحيم'), ayah('الحمد لله رب العالمين')]);
    final f = fatiha.accept(t('بسم الله الرحمن الرحيم'), finalSegment: true);
    expect(f.ayahCompleted, isTrue, reason: '1:1 is the basmala itself');
  });

  test('rule 4: a missed word is declared at the cursor, which stays on it', () {
    final m = matcher()..accept(t('قل هو الله احد الله الصمد'), finalSegment: true);
    final e = m.accept(t('لم ولم يولد'), finalSegment: true);
    expect(e.mistakes, [const AyahMistake(2, MistakeKind.missed)]);
    expect((m.ayahIndex, m.cursor), (2, 2), reason: 'carry on from the word got wrong (Q1)');
    final again = m.accept(t('يلد ولم يولد'), finalSegment: true);
    expect(again.ayahCompleted, isTrue);
    expect(again.mistakes, isEmpty);
    expect(m.tallies[2].mistakes, hasLength(1), reason: 'counts as corrected');
  });

  test('rule 4: a wrong word is declared with what was heard', () {
    final m = matcher()..accept(t('قل هو الله احد الله الصمد'), finalSegment: true);
    final e = m.accept(t('لم ينم ولم يولد'), finalSegment: true);
    expect(e.mistakes, [const AyahMistake(2, MistakeKind.wrong)]);
    expect(e.mistakes.single.heard, 'ينم');
    expect(m.cursor, 2);
  });

  test('rule 5: an added word is declared before the cursor', () {
    final m = matcher();
    final e = m.accept(t('قل يا هو الله احد'), finalSegment: true);
    expect(e.mistakes, [const AyahMistake(2, MistakeKind.added)]);
    expect(e.mistakes.single.heard, 'يا');
    expect(m.cursor, 2);
  });

  test('rule 6: an unclear word becomes wrong only after two final segments', () {
    final m = matcher()..accept(t('قل هو'), finalSegment: true);
    expect(m.accept(t('الاهي'), finalSegment: true).mistakes, isEmpty);
    final e = m.accept(t('الاهي'), finalSegment: true);
    expect(e.mistakes, [const AyahMistake(3, MistakeKind.wrong)]);
  });

  test('a wrong word said before a pause is reported as wrong, not missed', () {
    final m = matcher()..accept(t('قل هو'), finalSegment: true);
    expect(m.accept(t('الاهي'), finalSegment: true).mistakes, isEmpty);
    final e = m.accept(t('احد'), finalSegment: true);
    expect(e.mistakes, [const AyahMistake(3, MistakeKind.wrong)]);
    expect(e.mistakes.single.heard, 'الاهي');
  });

  test('noise far from every word is never a mistake by itself', () {
    final m = matcher()..accept(t('قل هو'), finalSegment: true);
    for (var i = 0; i < 4; i++) {
      expect(m.accept(t('شكرا'), finalSegment: true).mistakes, isEmpty);
    }
    expect(m.cursor, 3);
  });

  test('rule 7: provisional segments may advance but never declare a mistake', () {
    final m = matcher()..accept(t('قل هو الله احد الله الصمد'), finalSegment: true);
    final e = m.accept(t('لم ولم يولد'), finalSegment: false);
    expect(e.mistakes, isEmpty);
    expect(m.cursor, 2, reason: 'لم advanced; the skip is not judged yet');
  });

  test('rule 8: only matched or hinted words complete an ayah; hints count as matched', () {
    final m = matcher();
    m.accept(t('قل هو الله'), finalSegment: true);
    expect(m.ayahIndex, 0);
    final hint = m.hintNextWord();
    expect(hint.matched, [(0, 4)]);
    expect(hint.completed, [0]);
    expect(m.tallies[0].hints, {4});
    expect(m.tallies[0].complete, isTrue);
  });

  test('revealRest completes the expected ayah as revealed', () {
    final m = matcher()..accept(t('قل'), finalSegment: true);
    expect(m.revealRest().ayahCompleted, isTrue);
    expect((m.tallies[0].revealed, m.ayahIndex), (true, 1));
  });

  test('rule 9: words after the last ayah of the range are ignored', () {
    final m = matcher([ikhlas.last]);
    expect(m.accept(t('ولم يكن له كفوا احد'), finalSegment: true).ayahCompleted, isTrue);
    expect(m.done, isTrue);
    expect(m.accept(t('قل اعوذ برب الفلق'), finalSegment: true), same(MatchEvents.none));
  });

  test('one recognised word for two reference words, and two for one', () {
    final m = matcher([ayah('يا ايها الناس')]);
    expect(m.accept(t('ياايها الناس'), finalSegment: true).ayahCompleted, isTrue);
    final n = matcher([ayah('فسيكفيكهم الله')]);
    expect(n.accept(t('فسيكفيك هم الله'), finalSegment: true).ayahCompleted, isTrue);
  });

  test('a skip next to a word that also appears earlier is still a missed word', () {
    // «الله» appears at 3 and is skipped at 1 of ayah 2: going back to 3 would hide the skip.
    final m = matcher()..accept(t('قل هو الله احد'), finalSegment: true);
    final e = m.accept(t('الصمد'), finalSegment: true);
    expect(e.mistakes, [const AyahMistake(1, MistakeKind.missed)]);
  });

  test('similarity and canonical spellings', () {
    expect(similarity('الله', 'الله'), 1);
    expect(similarity('الصلوه', 'الصلاه'), 1, reason: 'variant spelling');
    expect(similarity('ينم', 'يلد'), lessThan(thetaMatch));
  });
}
