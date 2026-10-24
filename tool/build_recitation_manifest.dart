// Records the size of every ayah recording of each reciter, for the recitation catalogue in
// quran.db (specs/004-ayah-recitations/contracts/recitation-catalogue.md, changed by
// specs/006-reciters-memorization/contracts/reciter-catalogue.md). Fails a reciter if any ayah
// is missing, so a reciter is only ever offered with all 6,236 ayat (FR-002, SC-003).
//
// Usage: dart run tool/build_recitation_manifest.dart [--reciter <id>] [--concurrency <n>]
//                                                    [--skip-existing] [--record-qul]
//   reads   tool/recitations.json (reciter definitions), tool/sources/quran-data.xml, and for
//           qul_surah reciters tool/sources/qul-recitations/<qul_id>.json (QUL ayah timings)
//   writes  tool/sources/recitations/<id>.json and its SHA-256 in tool/sources.lock.json
//   --skip-existing  skip reciters whose manifest already matches the lock file
//   --record-qul     record the checksum of QUL timing files not yet in the lock file
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'src/mp3_frames.dart';
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
  final skipExisting = args.contains('--skip-existing');
  final recordQul = args.contains('--record-qul');
  final definitions = loadReciterDefinitions();
  validateReciterDefinitions(definitions);
  final reciters = [
    for (final r in definitions)
      if (only == null || r.id == only) r,
  ];
  if (reciters.isEmpty) {
    stderr.writeln('No reciter "$only" in $reciterDefinitions.');
    exit(64);
  }
  final ayahCounts = [for (final s in TanzilMetadata.load('$sourcesDir/$metadataXml').suras) s.ayas];
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);

  final failedReciters = <String>[];
  for (final r in reciters) {
    if (skipExisting && _manifestIsCurrent(r.id)) {
      stdout.writeln('${r.id}: manifest up to date, skipped');
      continue;
    }
    final ok = r.isSurahFiles
        ? await _buildSurahManifest(client, r, ayahCounts, concurrency, recordQul)
        : await _buildAyahManifest(client, r, ayahCounts, concurrency);
    if (!ok) failedReciters.add(r.id);
  }
  client.close(force: true);
  if (failedReciters.isNotEmpty) {
    stderr.writeln('FAILED: ${failedReciters.join(', ')}. Remove them from $reciterDefinitions '
        'or fix the source, and record why in specs/006 research R0/R1.');
    exit(1);
  }
}

bool _manifestIsCurrent(String id) {
  final path = manifestPath(id);
  if (!File(path).existsSync()) return false;
  final lock = (jsonDecode(File(lockFile).readAsStringSync()) as Map).cast<String, dynamic>();
  return lock[manifestLockKey(id)] == sha256Of(path);
}

/// One file per ayah (EveryAyah, QUL ayah sets): a HEAD request per ayah.
Future<bool> _buildAyahManifest(
    HttpClient client, ReciterDefinition r, List<int> ayahCounts, int concurrency) async {
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
    return false;
  }
  writeManifest(r.id, {
    for (final (s, a) in refs) '$s:$a': sizes[(s, a)]!,
  });
  stdout.writeln('Wrote ${manifestPath(r.id)}');
  return true;
}

/// One file per surah (QUL): each ayah is the byte range from the frame at its cut time to the
/// next ayah's (specs/006 research R18, R19).
Future<bool> _buildSurahManifest(HttpClient client, ReciterDefinition r, List<int> ayahCounts,
    int concurrency, bool recordQul) async {
  final timingsName = 'qul-recitations/${r.qulId}.json';
  checkSources([timingsName], record: recordQul);
  final timings = _loadTimings('$sourcesDir/$timingsName');
  final problems = <String>[];
  for (var s = 1; s <= ayahCounts.length; s++) {
    int? previous;
    for (var a = 1; a <= ayahCounts[s - 1]; a++) {
      final t = timings['$s:$a'];
      if (t == null) {
        problems.add('$s:$a has no timing');
      } else if (previous != null && t.from <= previous) {
        problems.add('$s:$a starts before or with the ayah before it');
      }
      previous = t?.from ?? previous;
    }
  }
  if (problems.isNotEmpty) {
    stderr.writeln('FAIL ${r.id}: ${problems.length} timing problems, first: '
        '${problems.take(5).join('; ')}');
    return false;
  }

  final files = <String, int>{};
  final rangeStart = <String, int>{};
  final fileBytes = <String, int>{};
  final failures = <String>[];
  var next = 1, done = 0;

  Future<void> worker() async {
    while (next <= ayahCounts.length) {
      final s = next++;
      try {
        final (start, sizes, length) = await _surahClips(client, r, s, ayahCounts[s - 1], timings);
        rangeStart['$s'] = start;
        fileBytes['$s'] = length;
        for (var a = 1; a <= sizes.length; a++) {
          files['$s:$a'] = sizes[a - 1];
        }
      } on Object catch (e) {
        failures.add('surah $s: $e');
      }
      stdout.write('\r${r.id}: ${++done}/${ayahCounts.length} surahs');
    }
  }

  await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
  stdout.writeln();
  if (failures.isNotEmpty || files.length != expectedAyahCount) {
    stderr.writeln('FAIL ${r.id}: ${failures.length} surahs failed: ${failures.join('; ')}');
    return false;
  }
  writeManifest(
    r.id,
    {
      for (var s = 1; s <= ayahCounts.length; s++)
        for (var a = 1; a <= ayahCounts[s - 1]; a++) '$s:$a': files['$s:$a']!,
    },
    rangeStart: {for (var s = 1; s <= ayahCounts.length; s++) '$s': rangeStart['$s']!},
    fileBytes: {for (var s = 1; s <= ayahCounts.length; s++) '$s': fileBytes['$s']!},
  );
  stdout.writeln('Wrote ${manifestPath(r.id)}');
  return true;
}

/// QUL ayah timings in either the "Download json" shape (`timestamp_from`/`timestamp_to`) or the
/// preview API's (`time_from`/`time_to`), keyed `S:A`.
Map<String, ({int from, int to})> _loadTimings(String path) {
  final json = (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, dynamic>();
  return {
    for (final MapEntry(:key, :value) in json.entries)
      if (value is Map && key.contains(':'))
        key: (
          from: ((value['timestamp_from'] ?? value['time_from']) as num).toInt(),
          to: ((value['timestamp_to'] ?? value['time_to']) as num).toInt(),
        ),
  };
}

/// The cut time between ayah [a] − 1 and [a]: the middle of the silence between them, or the
/// start of [a] when the two touch or overlap (research R18).
double _cutMs(({int from, int to}) previous, ({int from, int to}) current) =>
    previous.to >= current.from ? current.from.toDouble() : (previous.to + current.from) / 2;

/// The first frame offset of [surah]'s file, the clip size of each ayah, and the file length.
Future<(int, List<int>, int)> _surahClips(HttpClient client, ReciterDefinition r, int surah,
    int ayahCount, Map<String, ({int from, int to})> timings) async {
  final url = r.urlFor(surah, 1);
  final length = await _retry(() => _head(client, url));
  if (length == null) throw 'no file at $url';
  final head = await _retry(() => _range(client, url, 0, headerProbeBytes));
  if (head == null) throw 'could not read the start of $url';
  final audioStart = id3Length(head);
  final cbr = checkCbr(head, audioStart);

  final starts = [audioStart];
  for (var a = 2; a <= ayahCount; a++) {
    final cut = _cutMs(timings['$surah:${a - 1}']!, timings['$surah:$a']!);
    final predicted = cbr.predictOffset(cut);
    // One frame of slack before the prediction: frame offsets drift by a byte with padding.
    final windowStart = (predicted - cbr.averageFrameBytes.ceil()).clamp(0, length);
    if (windowStart >= length) throw '$surah:$a is past the end of the file';
    final window = await _retry(() => _range(client, url, windowStart, frameProbeBytes));
    if (window == null) throw 'could not read around $surah:$a';
    final start = frameStartAtOrAfter(window, windowStart, predicted - 1, cbr);
    if (start <= starts.last) throw '$surah:$a does not start after $surah:${a - 1}';
    starts.add(start);
  }
  final sizes = [
    for (var i = 0; i < starts.length; i++) (i + 1 < starts.length ? starts[i + 1] : length) - starts[i],
  ];
  if (sizes.last <= 0) throw 'the last ayah is empty';
  return (audioStart, sizes, length);
}

Future<T?> _retry<T>(Future<T?> Function() attempt) async {
  for (var i = 0; i <= manifestBackoff.length; i++) {
    final result = await attempt();
    if (result != null) return result;
    if (i < manifestBackoff.length) await Future<void>.delayed(manifestBackoff[i]);
  }
  return null;
}

/// The size of one recording, or null if it is missing after the retries and the mirror.
Future<int?> _sizeOf(HttpClient client, ReciterDefinition r, int surah, int ayah) async {
  for (var attempt = 0; attempt <= manifestBackoff.length; attempt++) {
    final mirror = attempt == manifestBackoff.length;
    if (mirror && r.mirrorUrl == null) return null;
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

/// [count] bytes of [url] from [start], or null. Requires a `206` for that range.
Future<Uint8List?> _range(HttpClient client, String url, int start, int count) async {
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-${start + count - 1}');
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode != HttpStatus.partialContent) {
      await response.drain<void>().catchError((_) {});
      return null;
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(const Duration(seconds: 30))) {
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    return bytes.isEmpty ? null : bytes;
  } on Object {
    return null;
  }
}

/// Writes the manifest and records its checksum, so build_quran_db.dart can verify it. Surah
/// recordings also carry each surah's first frame offset and file length.
void writeManifest(String id, Map<String, int> files,
    {Map<String, int>? rangeStart, Map<String, int>? fileBytes}) {
  final path = manifestPath(id);
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('${jsonEncode({
      'reciter': id,
      'range_start': ?rangeStart,
      'file_bytes': ?fileBytes,
      'files': files,
    })}\n');
  final lock = (jsonDecode(File(lockFile).readAsStringSync()) as Map).cast<String, dynamic>();
  lock[manifestLockKey(id)] = sha256Of(path);
  File(lockFile).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(lock)}\n');
}
