// Kashida justification rules (specs/002-print-like-mushaf-page/contracts/page-typesetting.md).
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/reader/kashida.dart';

const _tatweel = 0x0640;

bool _isMark(int c) =>
    (c >= 0x0610 && c <= 0x061A) || (c >= 0x064B && c <= 0x065F) || c == 0x0670 ||
    (c >= 0x06D6 && c <= 0x06ED);

void main() {
  group('joinPoints', () {
    test('after seen and sad first', () {
      final points = joinPoints('بِسْمِ');
      final afterSeen = 'بِسْ'.length;
      expect(points.where((p) => p.offset == afterSeen && p.priority == 0), hasLength(1));
    });

    test('before the last letter has priority 1', () {
      final points = joinPoints('كَفَرُوا۟');
      // ك ف ر و ا: ك–ف joins (priority 2), ف–ر joins and is not last; ر does not join left.
      expect(points.map((p) => p.priority), everyElement(anyOf(1, 2)));
      final mun = joinPoints('مُؤْمِنِينَ');
      expect(mun.where((p) => p.priority == 1), hasLength(1));
    });

    test('never next to an existing tatweel', () {
      const word = 'ٱلْكِتَـٰبُ';
      final at = word.codeUnits.indexOf(_tatweel);
      for (final p in joinPoints(word)) {
        expect(p.offset, isNot(at), reason: 'before the tatweel');
        expect(p.offset, isNot(at + 1), reason: 'after the tatweel');
        expect(word.codeUnitAt(p.offset - 1), isNot(_tatweel));
      }
    });

    test('no point inside lam-alef', () {
      for (final word in ['لَا', 'قَالَ', 'ٱلْأَرْضِ', 'إِلَّآ']) {
        for (final p in joinPoints(word)) {
          final before = word.substring(0, p.offset).runes.where((c) => !_isMark(c)).last;
          final after = word.substring(p.offset).runes.firstWhere((c) => !_isMark(c));
          expect(before == 0x0644 && 'اأإآٱ'.runes.contains(after), isFalse, reason: word);
        }
      }
    });

    test('none in the name of Allah or in short words', () {
      for (final word in ['ٱللَّهِ', 'لِلَّهِ', 'وَٱللَّهُ', 'ٱللَّهُمَّ', 'مَا', 'بِهِۦ', 'لَهُمْ']) {
        if (word == 'لَهُمْ') continue; // 3 letters: allowed
        expect(joinPoints(word), isEmpty, reason: word);
      }
      expect(joinPoints('لَهُمْ'), isNotEmpty);
    });

    test('points sit after a letter and all its marks', () {
      for (final word in ['بِسْمِ', 'ٱلرَّحْمَـٰنِ', 'يُخَـٰدِعُونَ', 'شَيَـٰطِينِهِمْ']) {
        for (final p in joinPoints(word)) {
          expect(p.offset, inInclusiveRange(1, word.length - 1), reason: word);
          expect(_isMark(word.codeUnitAt(p.offset)), isFalse, reason: '$word at ${p.offset}');
        }
      }
    });
  });

  group('justifyLine', () {
    const space = 0.3, tatweel = 0.24;
    List<JoinPoint> pts(int n) => [for (var i = 0; i < n; i++) JoinPoint(i + 1, i == 0 ? 1 : 2)];

    test('centred lines and single words keep normal spacing', () {
      for (final (widths, centered) in [
        ([3.0, 2.0, 4.0], true),
        ([5.0], false),
      ]) {
        final j = justifyLine(
          wordWidths: widths,
          space: space,
          tatweel: tatweel,
          points: [for (final _ in widths) pts(2)],
          target: 20,
          centered: centered,
        );
        expect(j.gap, space);
        expect(j.scale, 1);
        expect(j.tatweels.expand((m) => m.values), everyElement(0));
        expect(j.centered, isTrue);
      }
    });

    test('short lines are filled round-robin, capped per point, gaps 0.5–1.5 × space', () {
      final widths = [2.0, 2.5, 1.8, 3.0, 2.2, 1.5];
      final j = justifyLine(
        wordWidths: widths,
        space: space,
        tatweel: tatweel,
        points: [for (final _ in widths) pts(3)],
        target: 16,
        centered: false,
      );
      final perWord = [for (final m in j.tatweels) m.values.fold<int>(0, (s, v) => s + v)];
      expect(perWord.reduce((a, b) => a > b ? a : b) - perWord.reduce((a, b) => a < b ? a : b),
          lessThanOrEqualTo(1), reason: 'round-robin spreads evenly: $perWord');
      expect(j.tatweels.expand((m) => m.values), everyElement(lessThanOrEqualTo(maxTatweelsPerPoint)));
      expect(j.gap, inInclusiveRange(0.5 * space, 1.5 * space));
      expect(j.overGap, isFalse);
      expect(j.scale, 1);
      final total = widths.fold<double>(0, (s, w) => s + w) +
          perWord.fold<int>(0, (s, v) => s + v) * tatweel + (widths.length - 1) * j.gap;
      expect(total, closeTo(16, 1e-9));
      expect(j.width, closeTo(16, 1e-9));
    });

    test('long lines tighten gaps first, then shrink no further than 0.95', () {
      final tighten = justifyLine(
        wordWidths: [5, 5, 5],
        space: space,
        tatweel: tatweel,
        points: [pts(2), pts(2), pts(2)],
        target: 15.4,
        centered: false,
      );
      expect(tighten.scale, 1);
      expect(tighten.gap, closeTo(0.2, 1e-9));
      expect(tighten.gap, greaterThanOrEqualTo(0.5 * space));

      final shrink = justifyLine(
        wordWidths: [5, 5, 5],
        space: space,
        tatweel: tatweel,
        points: [pts(2), pts(2), pts(2)],
        target: 15,
        centered: false,
      );
      expect(shrink.gap, 0.5 * space);
      expect(shrink.scale, closeTo(15 / 15.3, 1e-9));
      expect(shrink.width, closeTo(15, 1e-9));

      final floor = justifyLine(
        wordWidths: [5, 5, 5],
        space: space,
        tatweel: tatweel,
        points: [pts(2), pts(2), pts(2)],
        target: 10,
        centered: false,
      );
      expect(floor.scale, 0.95);
    });

    test('a line that runs out of join points keeps a wider gap and says so', () {
      final j = justifyLine(
        wordWidths: [2, 2],
        space: space,
        tatweel: tatweel,
        points: [pts(1), const []],
        target: 8,
        centered: false,
      );
      expect(j.tatweels[0].values.single, maxTatweelsPerPoint);
      expect(j.gap, greaterThan(1.5 * space));
      expect(j.overGap, isTrue);
      expect(j.width, closeTo(8, 1e-9));
    });

    test('deterministic', () {
      LineJustification run() => justifyLine(
            wordWidths: [2.0, 2.5, 1.8, 3.0],
            space: space,
            tatweel: tatweel,
            points: [pts(2), pts(3), pts(1), pts(2)],
            target: 12,
            centered: false,
          );
      expect(run().tatweels, run().tatweels);
      expect(run().gap, run().gap);
    });
  });

  test('a word fills its best join point before a second one', () {
    final j = justifyLine(
      wordWidths: [2, 2],
      space: 0.3,
      tatweel: 0.24,
      points: [
        [const JoinPoint(1, 2), const JoinPoint(2, 0)],
        const [],
      ],
      target: 4.3 + 3 * 0.24,
      centered: false,
    );
    expect(j.tatweels[0], {2: 3});
  });

  test('withKashida inserts tatweels at the offsets only', () {
    const word = 'بِسْمِ';
    final at = 'بِسْ'.length;
    final s = withKashida(word, {at: 2});
    expect(s, '${word.substring(0, at)}ــ${word.substring(at)}');
    expect(withKashida(word, const {}), word);
  });
}
