// Spike S-1 (specs/002-print-like-mushaf-page, task T024): does the KFGQPC V2 (1421 AH) page
// lettering use the same pages and lines as quran.db? Also saves each word's V2 glyph code for
// the printed-lettering build (tool/build_replica_pack.dart).
//
//   dart run tool/compare_layouts.dart
//
// Reads the public Quran.com API (fields code_v2, v2_page, line_v2) and writes
// tool/sources/qcf-v2-words.json (gitignored): {"<word id>": [page, line, "<glyphs>"]}.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'src/sources.dart' show outputDb, sourcesDir;

const _api = 'https://api.quran.com/api/v4/verses/by_page';
const _out = '$sourcesDir/qcf-v2-words.json';

Future<void> main() async {
  final db = sqlite3.open(outputDb, mode: OpenMode.readOnly);
  // (surah, ayah, position) → (word id, page, line)
  final ours = <String, (int, int, int)>{};
  final oursLetters = <String, String>{}; // letters only, for aligning words
  for (final r in db.select('''
      SELECT w.id, w.surah, w.ayah, w.position, w.text_uthmani, l.page, l.line FROM words w
      JOIN mushaf_lines l ON l.type = 'ayah' AND w.id BETWEEN l.first_word_id AND l.last_word_id''')) {
    final key = '${r['surah']}:${r['ayah']}:${r['position']}';
    ours[key] = (r['id'] as int, r['page'] as int, r['line'] as int);
    oursLetters[key] = _letters(r['text_uthmani'] as String);
  }
  db.close();

  final client = HttpClient();
  final glyphs = <String, List<Object>>{};
  var words = 0, pageDiff = 0, lineDiff = 0, missing = 0;
  final badPages = <int>{};
  for (var page = 1; page <= 604; page++) {
    for (var p = 1;; p++) {
      final req = await client.getUrl(Uri.parse('$_api/$page?words=true'
          '&word_fields=code_v2,v2_page,line_v2,position,text_uthmani&per_page=50&page=$p'));
      final body = jsonDecode(await (await req.close()).transform(utf8.decoder).join()) as Map;
      for (final v in body['verses'] as List) {
        // A printed word can span several of ours («بَعْدَ مَا» is one glyph, two words here):
        // its glyph goes on the first, and the others get an empty glyph.
        var position = 1;
        for (final w in v['words'] as List) {
          // How many of our words this printed word covers: add ours until the letters match.
          var spans = 1;
          if (w['char_type_name'] != 'end') {
            final target = _letters((w['text_uthmani'] as String?) ?? '');
            var acc = oursLetters['${v['verse_key']}:$position'] ?? '';
            while (acc.length < target.length && spans < 4) {
              final next = oursLetters['${v['verse_key']}:${position + spans}'];
              if (next == null) break;
              acc += next;
              spans++;
            }
            if (acc != target) spans = 1; // spelling differs: keep one-to-one
          }
          for (var k = 0; k < spans; k++, position++) {
            words++;
            final mine = ours['${v['verse_key']}:$position'];
            if (mine == null) {
              missing++;
              badPages.add(page);
              continue;
            }
            glyphs['${mine.$1}'] = [
              w['v2_page'] as int,
              w['line_v2'] as int,
              k == 0 ? w['code_v2'] as String : '',
            ];
            if (w['v2_page'] != mine.$2) {
              pageDiff++;
              badPages.add(page);
            } else if (w['line_v2'] != mine.$3) {
              lineDiff++;
              badPages.add(page);
            }
          }
        }
      }
      final next = (body['pagination'] as Map?)?['next_page'];
      if (next == null) break;
    }
    if (page % 50 == 0) stdout.write('$page ');
  }
  client.close();
  print('');
  File(_out).writeAsStringSync(jsonEncode(glyphs));
  print('V2 vs quran.db: $words words, $pageDiff on another page, $lineDiff on another line, '
      '$missing not found; ${badPages.length} pages differ${badPages.isEmpty ? '' : ': ${badPages.take(40).join(', ')}'}');
  print('Glyph codes for ${glyphs.length} of ${ours.length} words written to $_out');
}

/// The base letters of [text], without marks, spaces or pause signs; the alef forms are unified
/// so spelling variants of the same word still match.
String _letters(String text) => String.fromCharCodes(text.runes
    .where((c) => (c >= 0x0621 && c <= 0x064A) || c == 0x0671)
    .map((c) => switch (c) { 0x0671 || 0x0623 || 0x0625 || 0x0622 => 0x0627, _ => c }));
