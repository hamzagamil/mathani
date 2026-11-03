// The Mutashabihat content file: format, checks and the shipped file (specs/010
// contracts/content-file.md).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/mutashabihat/mutashabihat_content.dart';

import '../support/harness.dart';

const _fixture = 'test/fixtures/mutashabihat/quickstart.md';

List<ContentProblemKind> _kinds(List<ContentProblem> problems) => [for (final p in problems) p.kind];

void main() {
  group('format', () {
    test('notes before the first group are ignored; the note after | is dropped', () {
      final (content, problems) = parseMutashabihat('''
# عنوان
ملاحظة للمالك: ## ليست مجموعة
- ## 1:1 1:2 داخل قائمة

## 2:35 7:19 | آدم في الجنة
شرح
''');
      expect(problems, isEmpty);
      expect(content.groups, hasLength(1));
      expect(content.groups.single.ayat, [const AyahRef(2, 35), const AyahRef(7, 19)]);
      expect(content.groups.single.explanation, 'شرح');
      expect(content.groups.single.line, 5);
    });

    test('Arabic-Indic digits, commas and spaces; ayat kept in Mushaf order', () {
      final (content, problems) = parseMutashabihat('## ٧:١٩، 2:35 ,20:117\nشرح');
      expect(problems, isEmpty);
      expect(content.groups.single.ayat,
          [const AyahRef(2, 35), const AyahRef(7, 19), const AyahRef(20, 117)]);
    });

    test('paragraphs and line breaks are kept; ### lines are text', () {
      final (content, _) = parseMutashabihat(
          '## 2:35 7:19\n\n\nسطر أول\nسطر ثان\n\n\n\n### فقرة\n\n');
      expect(content.groups.single.explanation, 'سطر أول\nسطر ثان\n\n### فقرة');
    });

    test('Windows line endings', () {
      final (content, problems) = parseMutashabihat('## 2:35 7:19\r\nشرح\r\n\r\nثان\r\n');
      expect(problems, isEmpty);
      expect(content.groups.single.explanation, 'شرح\n\nثان');
    });
  });

  group('checks', () {
    test('a bad reference is an error naming the token, and the group is skipped', () {
      final (content, problems) = parseMutashabihat('## 2:35 7;19\nشرح\n\n## 2:58 7:161\nشرح');
      expect(_kinds(problems), [ContentProblemKind.badReference]);
      expect(problems.single.message, 'line 1 (## 2:35 7;19): "7;19" is not a reference (use surah:ayah)');
      expect(problems.single.isError, isTrue);
      expect(content.groups.single.ayat.first, const AyahRef(2, 58));
    });

    test('ayat and surahs that do not exist', () {
      final (content, problems) = parseMutashabihat('## 2:35 2:300 115:1 3:0\nشرح');
      expect(_kinds(problems), List.filled(3, ContentProblemKind.noSuchAyah));
      expect(problems[0].message, 'line 1 (## 2:35 2:300 115:1 3:0): 2:300 is not an ayah (surah 2 has 286)');
      expect(problems[1].detail, '115:1: there is no surah 115');
      expect(content.groups, isEmpty);
    });

    test('fewer than two different ayat', () {
      final (_, problems) = parseMutashabihat('## 3:7\nشرح\n\n## 3:7 ٣:٧\nشرح');
      expect(_kinds(problems), [
        ContentProblemKind.tooFewAyat,
        ContentProblemKind.duplicateAyah,
        ContentProblemKind.tooFewAyat,
      ]);
    });

    test('an empty explanation', () {
      final (content, problems) = parseMutashabihat('## 3:7 39:23\n\n   \n## 2:35 7:19\nشرح');
      expect(_kinds(problems), [ContentProblemKind.emptyExplanation]);
      expect(problems.single.line, 1);
      expect(content.groups, hasLength(1));
    });

    test('a duplicate is a warning and is kept once', () {
      final (content, problems) = parseMutashabihat('## 2:35 2:35 7:19\nشرح');
      expect(_kinds(problems), [ContentProblemKind.duplicateAyah]);
      expect(problems.single.isError, isFalse);
      expect(problems.single.detail, '2:35 is listed twice; kept once');
      expect(content.groups.single.ayat, [const AyahRef(2, 35), const AyahRef(7, 19)]);
    });
  });

  group('lookups', () {
    test('groupsOf in file order, isLinked, linkedOnPage', () {
      final (content, problems) = parseMutashabihat(File(_fixture).readAsStringSync());
      expect(problems, isEmpty);
      expect(content.groups, hasLength(5));
      expect(content.groupsOf(const AyahRef(2, 35)).map((g) => g.line).toList(), [5, 13]);
      expect(content.groupsOf(const AyahRef(20, 117)), hasLength(1));
      expect(content.groupsOf(const AyahRef(2, 34)), isEmpty);
      expect(content.isLinked(const AyahRef(55, 77)), isTrue);
      expect(content.isLinked(const AyahRef(55, 14)), isFalse);
      expect(
        content.linkedOnPage(const [AyahRef(2, 34), AyahRef(2, 35), AyahRef(2, 35), AyahRef(2, 36)]),
        [const AyahRef(2, 35)],
      );
      expect(content.groupsOf(const AyahRef(55, 13)).single.ayat, hasLength(31));
    });

    test('empty content links nothing', () {
      expect(Mutashabihat.empty.isLinked(const AyahRef(2, 35)), isFalse);
      expect(Mutashabihat.empty.groupsOf(const AyahRef(2, 35)), isEmpty);
      expect(Mutashabihat.empty.linkedCount, 0);
    });
  });

  // FR-016: a bad edit to the shipped file fails `flutter test` as well as the release check.
  test('the shipped content file has no errors', () {
    final (_, problems) =
        parseMutashabihat(File('assets/mutashabihat/mutashabihat.md').readAsStringSync());
    expect(problems.where((p) => p.isError), isEmpty);
  });

  testWidgets('ayahCounts matches quran.db', (tester) async {
    await tester.runAsync(() async {
      final surahs = (await openTestReader()).quran.surahList;
      expect(surahs, hasLength(ayahCounts.length));
      for (var i = 0; i < surahs.length; i++) {
        expect(ayahCounts[i], surahs[i].ayahCount, reason: 'surah ${i + 1}');
      }
    });
  });
}
