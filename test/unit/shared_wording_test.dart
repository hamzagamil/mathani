// The tab texts of the similar-ayah sheet (specs/013 FR-016 to FR-020, research R8).
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/mutashabihat/shared_wording.dart';
import 'package:mathani/features/search/arabic_normalizer.dart';

List<String> w(String s) => s.split(' ');

List<String> labels(String pressed, List<List<String>> groups,
        {String Function(String)? key}) =>
    tabLabels(
      pressed: w(pressed),
      groups: [
        for (final g in groups) [for (final a in g) w(a)],
      ],
      key: key ?? (x) => x,
      number: (n) => '#$n',
    );

void main() {
  test('a run in at least half of the other ayat wins over a longer run in fewer', () {
    expect(
      labels('a b c d e', [
        ['x b c y', 'b c z', 'a b c d', 'q q q'],
      ]),
      ['b c'],
    );
  });

  test('under two words, the longest run found in one other ayah is used', () {
    expect(
      labels('a b c d e', [
        ['c x', 'y c', 'b c d z'],
      ]),
      ['b c d'],
    );
  });

  test('ties go to the earliest run of the pressed ayah', () {
    expect(
      labels('a b x c d', [
        ['c d', 'a b'],
      ]),
      ['a b'],
    );
  });

  test('no shared word: the group number', () {
    expect(
      labels('a b', [
        ['x y'],
        ['a z'],
      ]),
      ['#1', 'a'],
    );
  });

  test('a long run shows five words and an ellipsis', () {
    expect(
      labels('a b c d e f g', [
        ['a b c d e f g'],
      ]),
      ['a b c d e…'],
    );
    expect(
      labels('a b c d e', [
        ['a b c d e'],
      ]),
      ['a b c d e'],
    );
  });

  test('pause marks are left out, and vowel marks do not matter when matching', () {
    expect(
      labels('فِيهَا لَا يُخَفَّفُ عَنْهُمُ', [
        ['فِيهَا لَا يُخَفَّفُ عَنْهُمْ'],
      ], key: normalizeArabic),
      ['فِيهَا لَا يُخَفَّفُ عَنْهُمُ'],
    );
    expect(
      tabLabels(
        pressed: ['فِيهَا ۖ', 'لَا'],
        groups: [
          [
            ['فِيهَا', 'لَا'],
          ],
        ],
        key: normalizeArabic,
        number: (n) => '$n',
      ),
      ['فِيهَا لَا'],
    );
  });

  test('equal texts get their numbers; others stay as they are', () {
    expect(
      labels('a b c d', [
        ['a b'],
        ['c d'],
        ['z a b'],
      ]),
      ['a b (#1)', 'c d', 'a b (#3)'],
    );
  });

  test('one text per group, in order; a group without other ayat gets its number', () {
    expect(
      labels('a b c', [
        ['b c'],
        [],
        ['a b'],
      ]),
      ['b c', '#2', 'a b'],
    );
  });
}
