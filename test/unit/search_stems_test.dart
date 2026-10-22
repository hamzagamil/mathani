// Stem rules of contracts/search-matching.md (specs/003-fix-search-result-details).
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/search/search_index.dart';

void main() {
  test('attached prefixes are removed, leaving at least 2 letters', () {
    expect(searchStems('برحمته'), contains('رحمته'));
    expect(searchStems('ولهم'), contains('لهم'));
    expect(searchStems('فمن'), contains('من'));
    expect(searchStems('لا'), ['لا']);
    expect(searchStems('المومنين'), contains('مومنين'));
    expect(searchStems('المومنين').where((s) => s.startsWith('من')), isEmpty);
  });

  test('«لل» also matches with the article', () {
    expect(searchStems('للمتقين'), containsAll(['المتقين', 'متقين']));
  });

  test('the name of Allah is never split', () {
    expect(searchStems('الله'), ['الله']);
    expect(searchStems('اللهم'), ['اللهم']);
    expect(searchStems('لله'), ['لله']);
    expect(searchStems('والله'), ['والله', 'الله']);
    expect(searchStems('بالله'), ['بالله', 'الله']);
    expect(searchStems('ولله'), ['ولله', 'لله']);
    for (final w in ['الله', 'والله', 'فالله', 'بالله', 'لله', 'ولله', 'فلله']) {
      expect(searchStems(w), isNot(contains('له')), reason: w);
    }
  });

  test('the word itself comes first and stems are distinct', () {
    final s = searchStems('وللكافرين');
    expect(s.first, 'وللكافرين');
    expect(s.toSet().length, s.length);
  });
}
