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
    var e = m.accept(t('قل هو'), hearing: Hearing.pause);
    expect(e.matched, [(0, 1), (0, 2)]);
    expect((e.ayahCompleted, m.cursor), (false, 3));
    e = m.accept(t('الله احد الله الصمد'), hearing: Hearing.pause);
    expect(e.completed, [0, 1], reason: 'two short ayat in one breath');
    expect((m.ayahIndex, m.cursor), (2, 1));
    expect(m.tallies[0].mistakes, isEmpty);
  });

  test('rule 2: going back within the ayah, repeating or restarting, is not a mistake', () {
    final m = matcher();
    final e = m.accept(t('قل هو قل هو الله الله احد'), hearing: Hearing.pause);
    expect(e.ayahCompleted, isTrue);
    expect(e.mistakes, isEmpty);
  });

  test('rule 3: an opening isti\'adha and basmala are ignored, except as the expected words', () {
    final m = matcher();
    final e = m.accept(t('اعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم قل هو الله احد'),
        hearing: Hearing.pause);
    expect(e.ayahCompleted, isTrue);
    expect(e.mistakes, isEmpty);

    final fatiha = matcher([ayah('بسم الله الرحمن الرحيم'), ayah('الحمد لله رب العالمين')]);
    final f = fatiha.accept(t('بسم الله الرحمن الرحيم'), hearing: Hearing.pause);
    expect(f.ayahCompleted, isTrue, reason: '1:1 is the basmala itself');
  });

  test('rule 4: a missed word is declared at the cursor, which stays on it', () {
    final m = matcher()..accept(t('قل هو الله احد الله الصمد'), hearing: Hearing.pause);
    final e = m.accept(t('لم ولم يولد'), hearing: Hearing.pause);
    expect(e.mistakes, [const AyahMistake(2, MistakeKind.missed)]);
    expect((m.ayahIndex, m.cursor), (2, 2), reason: 'carry on from the word got wrong (Q1)');
    final again = m.accept(t('يلد ولم يولد'), hearing: Hearing.pause);
    expect(again.ayahCompleted, isTrue);
    expect(again.mistakes, isEmpty);
    expect(m.tallies[2].mistakes, hasLength(1), reason: 'counts as corrected');
  });

  test('rule 4: a wrong word is declared with what was heard', () {
    final m = matcher()..accept(t('قل هو الله احد الله الصمد'), hearing: Hearing.pause);
    final e = m.accept(t('لم ينم ولم يولد'), hearing: Hearing.pause);
    expect(e.mistakes, [const AyahMistake(2, MistakeKind.wrong)]);
    expect(e.mistakes.single.heard, 'ينم');
    expect(m.cursor, 2);
  });

  test('rule 5: an added word is declared before the cursor', () {
    final m = matcher();
    final e = m.accept(t('قل يا هو الله احد'), hearing: Hearing.pause);
    expect(e.mistakes, [const AyahMistake(2, MistakeKind.added)]);
    expect(e.mistakes.single.heard, 'يا');
    expect(m.cursor, 2);
  });

  test('rule 6: an unclear word becomes wrong only after two final segments', () {
    final m = matcher()..accept(t('قل هو'), hearing: Hearing.pause);
    expect(m.accept(t('الاهي'), hearing: Hearing.pause).mistakes, isEmpty);
    final e = m.accept(t('الاهي'), hearing: Hearing.pause);
    expect(e.mistakes, [const AyahMistake(3, MistakeKind.wrong)]);
  });

  test('a wrong word said before a pause is reported as wrong, not missed', () {
    final m = matcher()..accept(t('قل هو'), hearing: Hearing.pause);
    expect(m.accept(t('الاهي'), hearing: Hearing.pause).mistakes, isEmpty);
    final e = m.accept(t('احد'), hearing: Hearing.pause);
    expect(e.mistakes, [const AyahMistake(3, MistakeKind.wrong)]);
    expect(e.mistakes.single.heard, 'الاهي');
  });

  test('noise far from every word is never a mistake by itself', () {
    final m = matcher()..accept(t('قل هو'), hearing: Hearing.pause);
    for (var i = 0; i < 4; i++) {
      expect(m.accept(t('شكرا'), hearing: Hearing.pause).mistakes, isEmpty);
    }
    expect(m.cursor, 3);
  });

  group('live passes (specs/007 contract › rule changes)', () {
    /// The same live pass twice: a mistake needs two passes in a row (livePassesForMistake).
    MatchEvents twice(RecitationMatcher m, String words) {
      final first = m.accept(t(words), hearing: Hearing.live);
      expect(first.mistakes, isEmpty, reason: 'one pass only suspects it');
      return m.accept(t(words), hearing: Hearing.live);
    }

    test('rule 7: a live pass goes on past an unclear word', () {
      final m = matcher();
      var e = m.accept(t('قل هو شكرا الله'), hearing: Hearing.live);
      expect(e.mistakes, isEmpty, reason: 'one word after شكرا cannot judge it');
      expect((m.cursor, e.lastMatchedToken), (3, 1), reason: 'it waits at شكرا for more words');
      e = twice(m, 'هو شكرا ققق الله احد');
      expect(e.mistakes, [const AyahMistake(3, MistakeKind.added, 'شكرا')],
          reason: 'with more words, شكرا is an added word');
      final n = matcher()..accept(t('قل هو'), hearing: Hearing.pause);
      e = n.accept(t('ققق ققق ققق'), hearing: Hearing.live);
      expect(e.mistakes, isEmpty);
      expect(n.cursor, 3, reason: 'noise explained by nothing is passed');
    });

    test('rules 4, 5: a skip is declared once two following words confirm it', () {
      final m = matcher()..accept(t('قل هو الله احد الله الصمد'), hearing: Hearing.pause);
      final e = twice(m, 'لم ولم يولد');
      expect(e.mistakes, [const AyahMistake(2, MistakeKind.missed)]);
      expect(e.droppedRest, isTrue);
      expect(m.cursor, 2, reason: 'the reader goes back to the missed word');
    });

    test('rules 4, 5: one following word is not enough while reciting', () {
      final m = matcher()..accept(t('قل هو الله احد الله الصمد'), hearing: Hearing.pause);
      expect(m.accept(t('لم ولم'), hearing: Hearing.live).mistakes, isEmpty);
      expect(m.accept(t('لم ينم ولم'), hearing: Hearing.live).mistakes, isEmpty,
          reason: 'a wrong word with one word after it');
      expect(twice(m, 'لم ينم ولم يولد').mistakes, [const AyahMistake(2, MistakeKind.wrong, 'ينم')]);
    });

    test('rules 4, 5: an added word needs two words after it too', () {
      expect(matcher().accept(t('قل يا هو'), hearing: Hearing.live).mistakes, isEmpty);
      expect(twice(matcher(), 'قل يا هو الله').mistakes, [const AyahMistake(2, MistakeKind.added, 'يا')]);
    });

    test('a mistake found by one live pass and not the next is not declared', () {
      final m = matcher()..accept(t('قل هو الله احد الله الصمد'), hearing: Hearing.pause);
      expect(m.accept(t('لم ولم يولد'), hearing: Hearing.live).mistakes, isEmpty);
      expect(m.accept(t('لم يلد ولم يولد'), hearing: Hearing.live).mistakes, isEmpty,
          reason: 'the next pass heard يلد after all');
      expect(m.done, isFalse);
      expect(m.ayahIndex, 3);
    });

    test('rule 6: live passes never count unclear words toward a mistake', () {
      final m = matcher()..accept(t('قل هو'), hearing: Hearing.pause);
      for (var k = 0; k < 3; k++) {
        expect(m.accept(t('الاهي'), hearing: Hearing.live).mistakes, isEmpty);
      }
      expect(m.accept(t('الاهي'), hearing: Hearing.pause).mistakes, isEmpty,
          reason: 'the first pause pass with the unclear word');
      expect(m.accept(t('الاهي'), hearing: Hearing.pause).mistakes, hasLength(1),
          reason: 'the second one');
    });

    test('rule 10: the end of the previous ayah said again is a repeat', () {
      for (final hearing in Hearing.values) {
        final m = matcher()..accept(t('قل هو الله احد'), hearing: Hearing.pause);
        var e = m.accept(t('احد الله الصمد'), hearing: hearing);
        expect(e.mistakes, isEmpty, reason: '$hearing: last word');
        expect(e.completed, [1]);
        final n = matcher()..accept(t('قل هو الله احد الله الصمد'), hearing: Hearing.pause);
        e = n.accept(t('الله الصمد لم يلد'), hearing: hearing);
        expect(e.mistakes, isEmpty, reason: '$hearing: last two words');
        expect(n.cursor, 3);
        expect(e.lastMatchedToken, 3);
      }
    });

    test('rule 10: words from the middle of the previous ayah are still judged', () {
      final m = matcher()..accept(t('قل هو الله احد'), hearing: Hearing.pause);
      final e = m.accept(t('هو الصمد لم يلد'), hearing: Hearing.pause);
      expect(e.mistakes, isNotEmpty);
    });

    test('rule 11: a mistake is not declared twice in one stretch of speech', () {
      final m = matcher()..accept(t('قل هو الله احد الله الصمد'), hearing: Hearing.pause);
      expect(twice(m, 'لم ولم يولد').mistakes, hasLength(1));
      // The closing pause pass hears the same audio again.
      final again = m.accept(t('لم ولم يولد'), hearing: Hearing.pause);
      expect(again.mistakes, isEmpty);
      expect(again.droppedRest, isTrue);
      expect(m.tallies[2].mistakes, hasLength(1));
      // A new stretch: the same mistake counts again.
      expect(twice(m, 'لم ولم يولد').mistakes, hasLength(1));
    });
  });

  test('rule 8: only matched or hinted words complete an ayah; hints count as matched', () {
    final m = matcher();
    m.accept(t('قل هو الله'), hearing: Hearing.pause);
    expect(m.ayahIndex, 0);
    final hint = m.hintNextWord();
    expect(hint.matched, [(0, 4)]);
    expect(hint.completed, [0]);
    expect(m.tallies[0].hints, {4});
    expect(m.tallies[0].complete, isTrue);
  });

  test('revealRest completes the expected ayah as revealed', () {
    final m = matcher()..accept(t('قل'), hearing: Hearing.pause);
    expect(m.revealRest().ayahCompleted, isTrue);
    expect((m.tallies[0].revealed, m.ayahIndex), (true, 1));
  });

  test('rule 9: words after the last ayah of the range are ignored', () {
    final m = matcher([ikhlas.last]);
    expect(m.accept(t('ولم يكن له كفوا احد'), hearing: Hearing.pause).ayahCompleted, isTrue);
    expect(m.done, isTrue);
    expect(m.accept(t('قل اعوذ برب الفلق'), hearing: Hearing.pause), same(MatchEvents.none));
  });

  test('one recognised word for two reference words, and two for one', () {
    final m = matcher([ayah('يا ايها الناس')]);
    expect(m.accept(t('ياايها الناس'), hearing: Hearing.pause).ayahCompleted, isTrue);
    final n = matcher([ayah('فسيكفيكهم الله')]);
    expect(n.accept(t('فسيكفيك هم الله'), hearing: Hearing.pause).ayahCompleted, isTrue);
  });

  test('a skip next to a word that also appears earlier is still a missed word', () {
    // «الله» appears at 3 and is skipped at 1 of ayah 2: going back to 3 would hide the skip.
    final m = matcher()..accept(t('قل هو الله احد'), hearing: Hearing.pause);
    final e = m.accept(t('الصمد'), hearing: Hearing.pause);
    expect(e.mistakes, [const AyahMistake(1, MistakeKind.missed)]);
  });

  test('lastMatchedToken: the last token matched going forward or back, or -1', () {
    final m = matcher();
    expect(m.accept(t('قل هو شكرا'), hearing: Hearing.live).lastMatchedToken, 1);
    expect(m.accept(t('هو الله'), hearing: Hearing.live).lastMatchedToken, 1, reason: 'back, then on');
    expect(m.accept(t('الله'), hearing: Hearing.live).lastMatchedToken, 0,
        reason: 'back only: the last word again');
    expect(m.accept(t('قل'), hearing: Hearing.live).lastMatchedToken, -1,
        reason: 'one word further back waits for the words after it');
    expect(m.accept(t('شكرا'), hearing: Hearing.live).lastMatchedToken, -1);
  });

  test('similarity and canonical spellings', () {
    expect(similarity('الله', 'الله'), 1);
    expect(similarity('الصلوه', 'الصلاه'), 1, reason: 'variant spelling');
    expect(similarity('ينم', 'يلد'), lessThan(thetaMatch));
  });
}
