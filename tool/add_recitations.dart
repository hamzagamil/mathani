// Adds (or refreshes) the recitation catalogue in the existing assets/db/quran.db, the same way
// measure_line_widths_test.dart and build_replica_lettering_test.dart patch it after a build.
// tool/build_quran_db.dart writes the same tables in a full rebuild.
//
// Usage: dart run tool/add_recitations.dart
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'src/recitations.dart';
import 'src/sources.dart';

void main() {
  final db = sqlite3.open(outputDb);
  writeRecitationTables(db);
  final count = db.select('SELECT COUNT(*) AS n FROM recitation_sizes').first['n'];
  db.execute('VACUUM');
  db.close();
  File(outputVersion).writeAsStringSync('${sha256Of(outputDb)}\n');
  stdout.writeln('quran.db: ${loadReciterDefinitions().length} reciters, $count surah rows.');
}
