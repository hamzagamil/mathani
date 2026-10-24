// Recitation catalogue for quran.db: reciter definitions, per-ayah sizes, and the tables that hold
// them (specs/004-ayah-recitations/contracts/recitation-catalogue.md, changed by
// specs/006-reciters-memorization/contracts/reciter-catalogue.md).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'sources.dart';

/// Reciter definitions, committed (tool/sources/ is gitignored).
const reciterDefinitions = 'tool/recitations.json';

/// Every reciter must have a recording of each of these ayat (FR-002).
const expectedAyahCount = 6236;

/// Sizes are packed as 3-byte little-endian integers (specs/006 research R4).
const maxPackedSize = 0xFFFFFF;

const recitationSources = {'everyayah', 'qul_ayah', 'qul_surah'};
const recitationStyles = {'murattal', 'mujawwad', 'muallim'};

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
        source = j['source'] as String? ?? 'everyayah',
        baseUrl = j['base_url'] as String,
        mirrorUrl = j['mirror_url'] as String?,
        filePattern = j['file_pattern'] as String? ?? '{sss}{aaa}.mp3',
        basmalaInAyah1 = (j['basmala_in_ayah1'] as int? ?? 0) == 1,
        qulId = j['qul_id'] as int?,
        bitrateKbps = j['bitrate_kbps'] as int,
        sort = j['sort'] as int;

  final String id, nameAr, nameEn, shortAr, shortEn, style, source, baseUrl, filePattern;
  final String? mirrorUrl;
  final bool basmalaInAyah1;
  final int? qulId;
  final int bitrateKbps, sort;

  bool get isSurahFiles => source == 'qul_surah';

  /// The recording of [ayah] for ayah sources; for surah files, the file of [surah] (the ayah is
  /// a byte range of it). A `base_url` ending in `/` keeps the host's double slash.
  String urlFor(int surah, int ayah, {bool mirror = false}) {
    final base = mirror ? mirrorUrl! : baseUrl;
    final file = filePattern
        .replaceAll('{sss}', _pad3(surah))
        .replaceAll('{s}', '$surah')
        .replaceAll('{aaa}', _pad3(ayah));
    return '$base/$file';
  }
}

String _pad3(int n) => n.toString().padLeft(3, '0');

List<ReciterDefinition> loadReciterDefinitions() => [
      for (final j in jsonDecode(File(reciterDefinitions).readAsStringSync()) as List)
        ReciterDefinition.fromJson((j as Map).cast<String, dynamic>()),
    ];

/// Checks the definitions for the rules in specs/006 data-model › Reciter; exits on the first
/// violation.
void validateReciterDefinitions(List<ReciterDefinition> reciters) {
  final ids = <String>{};
  final urls = <String>{};
  for (final r in reciters) {
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(r.id)) _fail('Reciter id "${r.id}" is not a slug.');
    if (!ids.add(r.id)) _fail('Duplicate reciter id "${r.id}".');
    if (!urls.add('${r.baseUrl}|${r.filePattern}')) _fail('Duplicate base_url for "${r.id}".');
    if (r.nameAr.isEmpty || r.nameEn.isEmpty) _fail('Reciter "${r.id}" has an empty name.');
    if (!recitationStyles.contains(r.style)) _fail('Reciter "${r.id}": unknown style ${r.style}.');
    if (!recitationSources.contains(r.source)) {
      _fail('Reciter "${r.id}": unknown source ${r.source}.');
    }
    if (r.isSurahFiles && !r.basmalaInAyah1) {
      _fail('Reciter "${r.id}": qul_surah reciters must have basmala_in_ayah1 = 1.');
    }
    if (r.isSurahFiles && r.qulId == null) _fail('Reciter "${r.id}": qul_surah needs qul_id.');
  }
}

/// Packs [sizes] as 3-byte little-endian integers, in order.
Uint8List packSizes(List<int> sizes) {
  final out = Uint8List(sizes.length * 3);
  for (var i = 0; i < sizes.length; i++) {
    final s = sizes[i];
    out[i * 3] = s & 0xFF;
    out[i * 3 + 1] = (s >> 8) & 0xFF;
    out[i * 3 + 2] = (s >> 16) & 0xFF;
  }
  return out;
}

/// (Re)creates the `reciters` and `recitation_sizes` tables in [db] from the definitions and the
/// manifests, and records their checksums in `meta`. Exits if a manifest is missing, differs from
/// tool/sources.lock.json, or does not list every ayah.
void writeRecitationTables(Database db) {
  final lock = (jsonDecode(File(lockFile).readAsStringSync()) as Map).cast<String, dynamic>();
  final reciters = loadReciterDefinitions();
  validateReciterDefinitions(reciters);
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
    final manifest = (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, dynamic>();
    final files = (manifest['files'] as Map).cast<String, dynamic>();
    if (files.length != expectedAyahCount) {
      _fail('$path lists ${files.length} ayat, not $expectedAyahCount.');
    }
    if (r.isSurahFiles && manifest['range_start'] == null) {
      _fail('$path has no range_start: re-run tool/build_recitation_manifest.dart.');
    }
    manifests[r.id] = manifest;
  }

  db.execute('DROP TABLE IF EXISTS recitation_files');
  db.execute('DROP TABLE IF EXISTS recitation_sizes');
  db.execute('DROP TABLE IF EXISTS reciters');
  db.execute(recitationSchema);
  db.execute('BEGIN');
  final insReciter =
      db.prepare('INSERT INTO reciters VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
  final insSizes = db.prepare('INSERT INTO recitation_sizes VALUES (?, ?, ?, ?)');
  final insMeta = db.prepare('INSERT OR REPLACE INTO meta VALUES (?, ?)');
  for (final r in reciters) {
    insReciter.execute([
      r.id, r.nameAr, r.nameEn, r.shortAr, r.shortEn, r.style, r.baseUrl, r.mirrorUrl,
      r.bitrateKbps, r.sort, r.source, r.filePattern, r.basmalaInAyah1 ? 1 : 0,
    ]);
    final manifest = manifests[r.id]!;
    final files = (manifest['files'] as Map).cast<String, dynamic>();
    final starts = (manifest['range_start'] as Map?)?.cast<String, dynamic>();
    final fileBytes = (manifest['file_bytes'] as Map?)?.cast<String, dynamic>();
    final bySurah = <int, List<int>>{};
    files.forEach((key, bytes) {
      final [s, a] = key.split(':').map(int.parse).toList();
      final list = bySurah.putIfAbsent(s, () => []);
      if (list.length != a - 1) _fail('${manifestPath(r.id)}: $key is out of order.');
      final size = bytes as int;
      if (size <= 0 || size > maxPackedSize) {
        _fail('${manifestPath(r.id)}: $key is $size bytes, outside 1..$maxPackedSize.');
      }
      list.add(size);
    });
    for (final MapEntry(key: s, value: sizes) in bySurah.entries) {
      final start = starts?['$s'] as int?;
      if (r.isSurahFiles) {
        final total = fileBytes?['$s'] as int?;
        final covered = start! + sizes.fold(0, (a, b) => a + b);
        if (total != null && covered != total) {
          _fail('${manifestPath(r.id)}: surah $s clips cover $covered bytes, file is $total.');
        }
      }
      insSizes.execute([r.id, s, packSizes(sizes), start]);
    }
    insMeta.execute(['source_recitations_${r.id}_sha256', lock[manifestLockKey(r.id)]]);
  }
  insMeta.execute(['recitations_built_at', DateTime.now().toUtc().toIso8601String()]);
  db.execute('COMMIT');
  insReciter.close();
  insSizes.close();
  insMeta.close();
}

const recitationSchema = '''
CREATE TABLE reciters (
  id TEXT PRIMARY KEY, name_ar TEXT NOT NULL, name_en TEXT NOT NULL,
  short_ar TEXT NOT NULL, short_en TEXT NOT NULL, style TEXT NOT NULL,
  base_url TEXT NOT NULL, mirror_url TEXT,
  bitrate_kbps INTEGER NOT NULL, sort INTEGER NOT NULL,
  source TEXT NOT NULL, file_pattern TEXT NOT NULL,
  basmala_in_ayah1 INTEGER NOT NULL DEFAULT 0) WITHOUT ROWID;
CREATE TABLE recitation_sizes (
  reciter TEXT NOT NULL REFERENCES reciters(id), surah INTEGER NOT NULL,
  sizes BLOB NOT NULL, range_start INTEGER,
  PRIMARY KEY (reciter, surah)) WITHOUT ROWID;
''';

Never _fail(String message) {
  stderr.writeln('ERROR: $message');
  exit(1);
}
