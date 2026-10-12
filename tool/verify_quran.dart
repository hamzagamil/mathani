// Verifies assets/db/quran.db (research R10, SC-003). Exits non-zero on any failure.
//
// Usage: dart run tool/verify_quran.dart [--db-only] [--release]
//   (default)  structure checks + every ayah compared with the Tanzil Uthmani reference
//   --db-only  structure checks only (CI, where the licensed sources are not available)
//   --release  default checks, plus: no dev layout, approved encoding map, measured line widths
import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'src/sources.dart';

final _failures = <String>[];
final _warnings = <String>[];

void main(List<String> args) {
  final dbOnly = args.contains('--db-only');
  final release = args.contains('--release');
  if (!File(outputDb).existsSync()) {
    stderr.writeln('Missing $outputDb: run tool/build_quran_db.dart first.');
    exit(1);
  }
  final db = sqlite3.open(outputDb, mode: OpenMode.readOnly);
  final meta = {for (final r in db.select('SELECT key, value FROM meta')) r['key']: r['value']};
  final dev = meta['dev_layout'] == 'true';

  int count(String sql) => db.select(sql).first.columnAt(0) as int;
  void expect(String what, int actual, int expected) {
    if (actual != expected) _failures.add('$what: expected $expected, found $actual');
  }

  // 1. Counts.
  expect('surahs', count('SELECT COUNT(*) FROM surahs'), 114);
  expect('ayahs', count('SELECT COUNT(*) FROM ayahs'), 6236);
  expect('pages', count('SELECT COUNT(DISTINCT page) FROM mushaf_lines'), 604);
  expect('juz', count("SELECT COUNT(*) FROM divisions WHERE kind = 'juz'"), 30);
  expect('hizb quarters', count("SELECT COUNT(*) FROM divisions WHERE kind = 'hizb_quarter'"), 240);
  expect('sajdah ayahs', count('SELECT COUNT(*) FROM ayahs WHERE sajdah = 1'), 15);
  final overfull = count('SELECT COUNT(*) FROM (SELECT page FROM mushaf_lines GROUP BY page '
      'HAVING COUNT(*) > 15)');
  if (overfull > 0) {
    (dev ? _warnings : _failures).add('$overfull pages have more than 15 lines');
  }

  // 2. Every word in exactly one ayah line, in ascending order across the Mushaf.
  final wordCount = count('SELECT COUNT(*) FROM words');
  var expectedNext = 1;
  for (final l in db.select("SELECT page, line, first_word_id, last_word_id FROM mushaf_lines "
      "WHERE type = 'ayah' ORDER BY page, line")) {
    final first = l['first_word_id'] as int, last = l['last_word_id'] as int;
    if (first != expectedNext || last < first) {
      _failures.add('Line ${l['page']}:${l['line']} covers words $first–$last; expected to '
          'start at $expectedNext');
      break;
    }
    expectedNext = last + 1;
  }
  if (expectedNext != wordCount + 1 && _failures.isEmpty) {
    _failures.add('Lines cover ${expectedNext - 1} of $wordCount words');
  }

  // 3. Basmala rules (FR-006).
  expect('basmallah lines for surah 9',
      count("SELECT COUNT(*) FROM mushaf_lines WHERE type = 'basmallah' AND surah = 9"), 0);
  expect('separate basmallah lines for surah 1',
      count("SELECT COUNT(*) FROM mushaf_lines WHERE type = 'basmallah' AND surah = 1"), 0);
  expect('surah name lines', count("SELECT COUNT(*) FROM mushaf_lines WHERE type = 'surah_name'"),
      114);
  expect('basmallah lines', count("SELECT COUNT(*) FROM mushaf_lines WHERE type = 'basmallah'"), 112);
  expect('header lines without a surah',
      count("SELECT COUNT(*) FROM mushaf_lines WHERE type != 'ayah' AND surah IS NULL"), 0);

  // 4. Text identical to the Tanzil Uthmani reference, under the approved encoding map only.
  if (!dbOnly) {
    checkSources([uthmaniXml]);
    final map = jsonDecode(File('tool/encoding_map.json').readAsStringSync()) as Map;
    final pairs = [
      for (final p in map['pairs'] as List) (p['from'] as String, p['to'] as String),
    ];
    if (release && map['approved'] != true) {
      _failures.add('tool/encoding_map.json is not approved by the owner');
    }
    final reference = loadTanzilText('$sourcesDir/$uthmaniXml');
    final words = db.select('SELECT surah, ayah, text_uthmani, is_ayah_end FROM words ORDER BY id');
    final rebuilt = <String, List<String>>{};
    for (final w in words) {
      if (w['is_ayah_end'] == 1) continue;
      rebuilt.putIfAbsent('${w['surah']}:${w['ayah']}', () => []).add(w['text_uthmani'] as String);
    }
    final diffs = <String, int>{};
    var mismatched = 0;
    for (final r in reference) {
      var ours = (rebuilt['${r.sura}:${r.aya}'] ?? const []).join(' ');
      for (final (from, to) in pairs) {
        ours = ours.replaceAll(from, to);
      }
      if (ours != r.text) {
        mismatched++;
        final (a, b) = _middle(ours, r.text);
        final key = '${_cp(a)}  →  ${_cp(b)}';
        diffs[key] = (diffs[key] ?? 0) + 1;
        if (mismatched <= 5) {
          stderr.writeln('  ${r.sura}:${r.aya} differs: ${_cp(a)} vs Tanzil ${_cp(b)}');
        }
      }
    }
    if (mismatched > 0) {
      _failures.add('$mismatched ayahs differ from the Tanzil Uthmani reference');
      final top = diffs.entries.toList()..sort((x, y) => y.value.compareTo(x.value));
      stderr.writeln('Most frequent differing segments (ours → Tanzil), for tool/encoding_map.md:');
      for (final e in top.take(30)) {
        stderr.writeln('  ${e.value.toString().padLeft(5)}  ${e.key}');
      }
    }
  }

  // 5. Release gates.
  if (release) {
    if (dev) _failures.add('database was built from DEV sources (approximate line breaks)');
    if ((double.tryParse(meta['max_line_width_em'] as String? ?? '') ?? 0) <= 0) {
      _failures.add('meta.max_line_width_em not measured (run tool/measure_line_widths_test.dart)');
    }
  }

  db.close();
  for (final w in _warnings) {
    stdout.writeln('WARNING: $w');
  }
  if (dev) stdout.writeln('NOTE: dev layout (approximate line breaks); not for release.');
  if (_failures.isNotEmpty) {
    for (final f in _failures) {
      stderr.writeln('FAIL: $f');
    }
    exit(1);
  }
  stdout.writeln('PASS (114 surahs, 6236 ayat, 604 pages, 30 juz, 240 hizb quarters, '
      '15 sajdah ayat${dbOnly ? '; text comparison skipped' : '; text identical to Tanzil'})');
  stdout.writeln('quran.db SHA-256 ${sha256Of(outputDb)}');
}

/// The differing middle segments of [a] and [b] after removing their common prefix and suffix.
(String, String) _middle(String a, String b) {
  var p = 0;
  while (p < a.length && p < b.length && a.codeUnitAt(p) == b.codeUnitAt(p)) {
    p++;
  }
  var s = 0;
  while (s < a.length - p && s < b.length - p &&
      a.codeUnitAt(a.length - 1 - s) == b.codeUnitAt(b.length - 1 - s)) {
    s++;
  }
  return (a.substring(p, a.length - s), b.substring(p, b.length - s));
}

String _cp(String s) => s.isEmpty
    ? '(nothing)'
    : s.runes.map((c) => 'U+${c.toRadixString(16).toUpperCase().padLeft(4, '0')}').join(' ');
