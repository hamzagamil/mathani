// Writes build/web/editor/quran.json, the surah names and every ayah's Uthmani text that the
// Mutashabihat editor shows next to a chosen ayah (specs/011 research R8, FR-005). Run by
// tool/web_deploy.mjs after `flutter build web`; not committed.
//
// Usage: dart run tool/build_editor_quran.dart [out]
import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'src/sources.dart';

void main(List<String> args) {
  final out = File(args.isEmpty ? 'build/web/editor/quran.json' : args.first);
  if (!File(outputDb).existsSync()) {
    stderr.writeln('Missing $outputDb.');
    exit(1);
  }
  final db = sqlite3.open(outputDb, mode: OpenMode.readOnly);
  final surahs = [
    for (final r in db.select('SELECT number, name_ar, ayah_count FROM surahs ORDER BY number'))
      {'n': r['number'], 'name': r['name_ar'], 'count': r['ayah_count']},
  ];
  final ayat = <String, String>{};
  final words = <String, List<String>>{};
  for (final r in db.select(
      'SELECT surah, ayah, text_uthmani FROM words WHERE is_ayah_end = 0 ORDER BY surah, ayah, position')) {
    (words['${r['surah']}:${r['ayah']}'] ??= []).add(r['text_uthmani'] as String);
  }
  words.forEach((ref, w) => ayat[ref] = w.join(' '));
  db.dispose();
  if (ayat.length != 6236) {
    stderr.writeln('Expected 6236 ayat, found ${ayat.length}.');
    exit(1);
  }
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(jsonEncode({'surahs': surahs, 'ayat': ayat}));
  stdout.writeln('${out.path}: ${surahs.length} surahs, ${ayat.length} ayat, '
      '${(out.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB');
}
