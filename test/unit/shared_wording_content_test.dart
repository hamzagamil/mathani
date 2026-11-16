// The tab texts on the shipped content file and database (specs/013 SC-006, SC-007).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/mutashabihat/mutashabihat_content.dart';
import 'package:mathani/features/mutashabihat/similar_sheet.dart';
import 'package:mathani/features/search/arabic_normalizer.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';

void main() {
  late ReaderController reader;
  late Mutashabihat content;
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    reader = await openTestReader();
    content =
        parseMutashabihat(File('assets/mutashabihat/mutashabihat.md').readAsStringSync()).$1;
  });

  Future<List<String>> keysOf(AyahRef ref) async => [
        for (final w in await reader.quran.wordsOf(ref))
          if (!w.isAyahEnd) normalizeArabic(w.text),
      ];

  bool contains(List<String> ayah, List<String> run) {
    for (var i = 0; i + run.length <= ayah.length; i++) {
      var same = true;
      for (var k = 0; same && k < run.length; k++) {
        same = ayah[i + k] == run[k];
      }
      if (same) return true;
    }
    return false;
  }

  test('2:162 reads as its two wordings', () async {
    const ref = AyahRef(2, 162);
    final labels =
        await similarTabLabels(reader.quran, ref, content.groupsOf(ref), (n) => '$n');
    // Compared without vowel marks: their order in the database text is not the typed order.
    expect([for (final l in labels) normalizeArabic(l)],
        ['يخفف عنهم العذاب ولا هم', 'ولا هم ينظرون']);
  });

  test('every multi-group ayah: different tabs, wording from the ayah and one other', () async {
    final refs = {
      for (final g in content.groups)
        for (final ref in g.ayat)
          if (content.groupsOf(ref).length > 1) ref,
    };
    expect(refs, isNotEmpty);
    var tabs = 0, twoWords = 0;
    for (final ref in refs) {
      final groups = content.groupsOf(ref);
      final labels = await similarTabLabels(reader.quran, ref, groups, (n) => '#$n');
      expect(labels, hasLength(groups.length));
      expect(labels.toSet(), hasLength(labels.length), reason: '$ref: $labels');
      final pressed = await keysOf(ref);
      for (var g = 0; g < groups.length; g++) {
        tabs++;
        if (labels[g] == '#${g + 1}') continue;
        final text = labels[g].replaceAll(' (#${g + 1})', '').replaceAll('…', '');
        final run = [for (final w in text.split(' ')) normalizeArabic(w)];
        if (run.length >= 2) twoWords++;
        expect(contains(pressed, run), isTrue, reason: '$ref tab ${g + 1}: ${labels[g]}');
        var inAnother = false;
        for (final other in groups[g].ayat) {
          if (other != ref && contains(await keysOf(other), run)) inAnother = true;
        }
        expect(inAnother, isTrue, reason: '$ref tab ${g + 1}: ${labels[g]}');
      }
    }
    expect(twoWords / tabs, greaterThanOrEqualTo(0.9), reason: '$twoWords of $tabs tabs');
  });
}
