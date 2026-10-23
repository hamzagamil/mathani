// Records the size of every ayah recording of each reciter, for the recitation catalogue in
// quran.db (specs/004-ayah-recitations/contracts/recitation-catalogue.md). Fails if any ayah is
// missing, so a reciter is only ever offered with all 6,236 ayat (FR-002, SC-003).
//
// Usage: dart run tool/build_recitation_manifest.dart [--reciter <id>] [--concurrency <n>]
//   reads   tool/recitations.json (reciter definitions) and tool/sources/quran-data.xml
//   writes  tool/sources/recitations/<id>.json and its SHA-256 in tool/sources.lock.json
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'src/recitations.dart';
import 'src/sources.dart';

/// Requests in flight at once. EveryAyah's CDN throttled 2–5% of requests at 16 (research R6).
const manifestConcurrency = 4;

/// Waits before each retry of a failed request; after the last, the mirror is tried once.
const manifestBackoff = [Duration(seconds: 1), Duration(seconds: 4), Duration(seconds: 16)];

Future<void> main(List<String> args) async {
  String? option(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final only = option('--reciter');
  final concurrency = int.tryParse(option('--concurrency') ?? '') ?? manifestConcurrency;
  final reciters = [
    for (final r in loadReciterDefinitions())
      if (only == null || r.id == only) r,
  ];
  if (reciters.isEmpty) {
    stderr.writeln('No reciter "$only" in $reciterDefinitions.');
    exit(64);
  }
  final ayahCounts = [for (final s in TanzilMetadata.load('$sourcesDir/$metadataXml').suras) s.ayas];
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);

  var failed = false;
  for (final r in reciters) {
    final refs = [
      for (var s = 1; s <= ayahCounts.length; s++)
        for (var a = 1; a <= ayahCounts[s - 1]; a++) (s, a),
    ];
    final sizes = <(int, int), int>{};
    final failures = <String>[];
    var next = 0, done = 0;

    Future<void> worker() async {
      while (next < refs.length) {
        final (s, a) = refs[next++];
        final size = await _sizeOf(client, r, s, a);
        if (size == null) {
          failures.add('$s:$a');
        } else {
          sizes[(s, a)] = size;
        }
        if (++done % 250 == 0 || done == refs.length) {
          stdout.write('\r${r.id}: $done/${refs.length}');
        }
      }
    }

    await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
    stdout.writeln('\r${r.id}: ${sizes.length}/${refs.length}');
    if (failures.isNotEmpty || sizes.length != expectedAyahCount) {
      stderr.writeln('FAIL ${r.id}: ${failures.length} ayat missing: ${failures.join(', ')}');
      failed = true;
      continue;
    }
    writeManifest(r.id, {
      for (final (s, a) in refs) '$s:$a': sizes[(s, a)]!,
    });
    stdout.writeln('Wrote ${manifestPath(r.id)}');
  }
  client.close(force: true);
  if (failed) exit(1);
}

/// The size of one recording, or null if it is missing after the retries and the mirror.
Future<int?> _sizeOf(HttpClient client, ReciterDefinition r, int surah, int ayah) async {
  for (var attempt = 0; attempt <= manifestBackoff.length; attempt++) {
    final mirror = attempt == manifestBackoff.length;
    final size = await _head(client, r.urlFor(surah, ayah, mirror: mirror));
    if (size != null) return size;
    if (!mirror) await Future<void>.delayed(manifestBackoff[attempt]);
  }
  return null;
}

/// The `Content-Length` of an `audio/mpeg` file answered with 200, or null.
Future<int?> _head(HttpClient client, String url) async {
  try {
    final request = await client.headUrl(Uri.parse(url));
    final response = await request.close().timeout(const Duration(seconds: 30));
    await response.drain<void>();
    final type = response.headers.contentType?.mimeType;
    final length = response.contentLength;
    if (response.statusCode == HttpStatus.ok && type == 'audio/mpeg' && length > 0) return length;
  } on Object {
    // Network error or timeout: retried by the caller.
  }
  return null;
}

/// Writes the manifest and records its checksum, so build_quran_db.dart can verify it.
void writeManifest(String id, Map<String, int> files) {
  final path = manifestPath(id);
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('${jsonEncode({'reciter': id, 'files': files})}\n');
  final lock = (jsonDecode(File(lockFile).readAsStringSync()) as Map).cast<String, dynamic>();
  lock[manifestLockKey(id)] = sha256Of(path);
  File(lockFile).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(lock)}\n');
}
