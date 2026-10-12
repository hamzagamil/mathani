// Prints the tables, columns, row counts and first rows of a SQLite file, to check a downloaded
// source before adding it to tool/sources/.
//   dart run tool/inspect_sqlite.dart <file.db> [rows]
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/inspect_sqlite.dart <file.db> [rows]');
    exit(64);
  }
  final rows = args.length > 1 ? int.parse(args[1]) : 3;
  final db = sqlite3.open(args[0], mode: OpenMode.readOnly);
  for (final t in db.select("SELECT name, sql FROM sqlite_master WHERE type = 'table'")) {
    final name = t['name'] as String;
    final count = db.select('SELECT COUNT(*) AS n FROM "$name"').first['n'];
    stdout.writeln('\n== $name ($count rows)\n${t['sql']}');
    for (final r in db.select('SELECT * FROM "$name" LIMIT $rows')) {
      stdout.writeln('  $r');
    }
  }
  db.close();
}
