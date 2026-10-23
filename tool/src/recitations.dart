// Recitation catalogue for quran.db: reciter definitions, per-ayah file sizes, and the tables
// that hold them (specs/004-ayah-recitations/contracts/recitation-catalogue.md).
import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'sources.dart';

/// Reciter definitions, committed (tool/sources/ is gitignored).
const reciterDefinitions = 'tool/recitations.json';

/// Every reciter must have a recording of each of these ayat (FR-002).
const expectedAyahCount = 6236;

String manifestLockKey(String id) => 'recitations/$id.json';
String manifestPath(String id) => '$sourcesDir/${manifestLockKey(id)}';

class ReciterDefinition {
  ReciterDefinition.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        nameAr = j['name_ar'] as String,
        nameEn = j['name_en'] as String,
        shortAr = j['short_ar'] as String,
        shortEn = j['short_en'] as String,
        style = j['style'] as String,
        baseUrl = j['base_url'] as String,
        mirrorUrl = j['mirror_url'] as String,
        bitrateKbps = j['bitrate_kbps'] as int,
        sort = j['sort'] as int;

  final String id, nameAr, nameEn, shortAr, shortEn, style, baseUrl, mirrorUrl;
  final int bitrateKbps, sort;

  String urlFor(int surah, int ayah, {bool mirror = false}) =>
      '${mirror ? mirrorUrl : baseUrl}/${_pad3(surah)}${_pad3(ayah)}.mp3';
}

String _pad3(int n) => n.toString().padLeft(3, '0');

List<ReciterDefinition> loadReciterDefinitions() => [
      for (final j in jsonDecode(File(reciterDefinitions).readAsStringSync()) as List)
        ReciterDefinition.fromJson((j as Map).cast<String, dynamic>()),
    ];

/// (Re)creates the `reciters` and `recitation_files` tables in [db] from the definitions and the
/// manifests, and records their checksums in `meta`. Exits if a manifest is missing, differs from
/// tool/sources.lock.json, or does not list every ayah.
void writeRecitationTables(Database db) {
  final lock = (jsonDecode(File(lockFile).readAsStringSync()) as Map).cast<String, dynamic>();
  final reciters = loadReciterDefinitions();
  final manifests = <String, Map<String, dynamic>>{};
  for (final r in reciters) {
    final path = manifestPath(r.id);
    if (!File(path).existsSync()) {
      _fail('Missing $path: run dart run tool/build_recitation_manifest.dart first.');
    }
    final hash = sha256Of(path);
    if (lock[manifestLockKey(r.id)] != hash) {
      _fail('Checksum mismatch for $path: re-run tool/build_recitation_manifest.dart.');
    }
    final files = ((jsonDecode(File(path).readAsStringSync()) as Map)['files'] as Map)
        .cast<String, dynamic>();
    if (files.length != expectedAyahCount) {
      _fail('$path lists ${files.length} ayat, not $expectedAyahCount.');
    }
    manifests[r.id] = files;
  }

  db.execute('DROP TABLE IF EXISTS recitation_files');
  db.execute('DROP TABLE IF EXISTS reciters');
  db.execute(recitationSchema);
  db.execute('BEGIN');
  final insReciter = db.prepare('INSERT INTO reciters VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
  final insFile = db.prepare('INSERT INTO recitation_files VALUES (?, ?, ?, ?)');
  final insMeta = db.prepare('INSERT OR REPLACE INTO meta VALUES (?, ?)');
  for (final r in reciters) {
    insReciter.execute([
      r.id, r.nameAr, r.nameEn, r.shortAr, r.shortEn, r.style, r.baseUrl, r.mirrorUrl,
      r.bitrateKbps, r.sort,
    ]);
    manifests[r.id]!.forEach((key, bytes) {
      final [s, a] = key.split(':').map(int.parse).toList();
      insFile.execute([r.id, s, a, bytes as int]);
    });
    insMeta.execute(['source_recitations_${r.id}_sha256', lock[manifestLockKey(r.id)]]);
  }
  insMeta.execute(['recitations_built_at', DateTime.now().toUtc().toIso8601String()]);
  db.execute('COMMIT');
  insReciter.close();
  insFile.close();
  insMeta.close();
}

const recitationSchema = '''
CREATE TABLE reciters (
  id TEXT PRIMARY KEY, name_ar TEXT NOT NULL, name_en TEXT NOT NULL,
  short_ar TEXT NOT NULL, short_en TEXT NOT NULL, style TEXT NOT NULL,
  base_url TEXT NOT NULL, mirror_url TEXT NOT NULL,
  bitrate_kbps INTEGER NOT NULL, sort INTEGER NOT NULL) WITHOUT ROWID;
CREATE TABLE recitation_files (
  reciter TEXT NOT NULL REFERENCES reciters(id), surah INTEGER NOT NULL, ayah INTEGER NOT NULL,
  bytes INTEGER NOT NULL, PRIMARY KEY (reciter, surah, ayah)) WITHOUT ROWID;
''';

Never _fail(String message) {
  stderr.writeln('ERROR: $message');
  exit(1);
}
