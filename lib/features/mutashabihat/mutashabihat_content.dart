// Plain Dart, no Flutter: tool/check_mutashabihat.dart uses this file too (specs/010 research R2).
import '../../data/models.dart';

/// Ayat in each surah (Hafs), index = surah - 1. Checked against quran.db by
/// test/unit/mutashabihat_content_test.dart, so the check runs without the database.
const List<int> ayahCounts = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 110, 98, 135, //
  112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83, 182, 88, 75, 85, //
  54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13, //
  14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, //
  29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, //
  11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6, //
];

/// Ayat the owner linked as similar, with one explanation (specs/010 data-model.md).
class MutashabihGroup {
  const MutashabihGroup({required this.ayat, required this.explanation, required this.line});

  /// Two or more distinct ayat, in Mushaf order.
  final List<AyahRef> ayat;

  /// The owner's text: paragraphs separated by one blank line, lines kept as written.
  final String explanation;

  /// 1-based line of the group's `##` heading in the content file.
  final int line;
}

/// The loaded content file: valid groups in file order, and which ayat they link.
class Mutashabihat {
  Mutashabihat(this.groups) : _index = _indexOf(groups);

  const Mutashabihat._empty()
      : groups = const [],
        _index = const {};

  /// No content: nothing is coloured and the action never appears (FR-019).
  static const empty = Mutashabihat._empty();

  final List<MutashabihGroup> groups;
  final Map<AyahRef, List<int>> _index;

  static Map<AyahRef, List<int>> _indexOf(List<MutashabihGroup> groups) {
    final index = <AyahRef, List<int>>{};
    for (var g = 0; g < groups.length; g++) {
      for (final ref in groups[g].ayat) {
        (index[ref] ??= []).add(g);
      }
    }
    return index;
  }

  bool isLinked(AyahRef ref) => _index.containsKey(ref);

  /// The groups [ref] belongs to, in file order; empty when it is not linked.
  List<MutashabihGroup> groupsOf(AyahRef ref) => [for (final g in _index[ref] ?? const <int>[]) groups[g]];

  /// The linked ayat among [refs], once each, in the order given.
  List<AyahRef> linkedOnPage(Iterable<AyahRef> refs) => {...refs.where(isLinked)}.toList();

  /// Number of distinct linked ayat.
  int get linkedCount => _index.length;
}

enum ContentProblemKind { badReference, noSuchAyah, tooFewAyat, emptyExplanation, duplicateAyah }

/// A problem in the content file, for the release check (contracts/content-file.md › Checks).
class ContentProblem {
  const ContentProblem(this.line, this.kind, this.heading, this.detail);

  final int line;
  final ContentProblemKind kind;

  /// The group's heading line as written, for example `## 2:35 7:19`.
  final String heading;
  final String detail;

  /// A duplicate is dropped with a warning; every other problem leaves the group out.
  bool get isError => kind != ContentProblemKind.duplicateAyah;

  String get message => 'line $line ($heading): $detail';

  @override
  String toString() => message;
}

final _reference = RegExp(r'^(\d+):(\d+)$');
final _separators = RegExp(r'[\s,،]+');
final _blankLines = RegExp(r'\n[ \t]*(\n[ \t]*)+');

/// Arabic-Indic and Eastern Arabic-Indic digits to Western ones.
String _westernDigits(String s) => s.replaceAllMapped(RegExp('[٠-٩۰-۹]'), (m) {
      final c = m[0]!.codeUnitAt(0);
      return String.fromCharCode(0x30 + (c >= 0x06F0 ? c - 0x06F0 : c - 0x0660));
    });

/// Parses the content file (contracts/content-file.md). Groups with an error are left out of the
/// result, so the reader keeps working; the problems are for the release check.
(Mutashabihat, List<ContentProblem>) parseMutashabihat(String text) {
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  final groups = <MutashabihGroup>[];
  final problems = <ContentProblem>[];

  void addGroup(int line, String heading, List<String> body) {
    final errors = <ContentProblem>[];
    final ayat = <AyahRef>{};
    final pipe = heading.indexOf('|');
    final refs = (pipe < 0 ? heading.substring(3) : heading.substring(3, pipe)).trim();
    for (final token in _westernDigits(refs).split(_separators)) {
      if (token.isEmpty) continue;
      final m = _reference.firstMatch(token);
      if (m == null) {
        errors.add(ContentProblem(line, ContentProblemKind.badReference, heading,
            '"$token" is not a reference (use surah:ayah)'));
        continue;
      }
      final surah = int.parse(m[1]!);
      final ayah = int.parse(m[2]!);
      if (surah < 1 || surah > ayahCounts.length) {
        errors.add(ContentProblem(
            line, ContentProblemKind.noSuchAyah, heading, '$token: there is no surah $surah'));
      } else if (ayah < 1 || ayah > ayahCounts[surah - 1]) {
        errors.add(ContentProblem(line, ContentProblemKind.noSuchAyah, heading,
            '$token is not an ayah (surah $surah has ${ayahCounts[surah - 1]})'));
      } else if (!ayat.add(AyahRef(surah, ayah))) {
        problems.add(ContentProblem(line, ContentProblemKind.duplicateAyah, heading,
            '$token is listed twice; kept once'));
      }
    }
    if (errors.isEmpty && ayat.length < 2) {
      errors.add(ContentProblem(line, ContentProblemKind.tooFewAyat, heading,
          'a group needs at least two different ayat'));
    }
    final explanation = body.join('\n').trim().replaceAll(_blankLines, '\n\n');
    if (explanation.isEmpty) {
      errors.add(ContentProblem(
          line, ContentProblemKind.emptyExplanation, heading, 'the explanation is empty'));
    }
    problems.addAll(errors);
    if (errors.isEmpty) {
      groups.add(MutashabihGroup(
        ayat: ayat.toList()..sort(),
        explanation: explanation,
        line: line,
      ));
    }
  }

  int? headingLine;
  String? heading;
  final body = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i].trimRight();
    if (l.startsWith('## ')) {
      if (heading != null) addGroup(headingLine!, heading, body);
      headingLine = i + 1;
      heading = l;
      body.clear();
    } else if (heading != null) {
      body.add(l);
    }
    // Lines before the first group are notes for the owner.
  }
  if (heading != null) addGroup(headingLine!, heading, body);
  return (Mutashabihat(groups), problems);
}
