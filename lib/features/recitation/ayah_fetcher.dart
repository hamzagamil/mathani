// Gets ayah recordings onto the device (specs/004-ayah-recitations/contracts/audio-storage.md).
// The player only ever plays a local file this class has checked against the catalogue size;
// that is how "never skip an ayah" holds the same on both platforms (research R5).
import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../data/models.dart';
import '../../shared/device_channel.dart';
import 'recited_item.dart';

/// Ayat kept ready ahead of the one playing.
const prefetchAhead = 3;

/// The recent-recitations cache is trimmed when it grows past this…
const cacheLimitBytes = 100 * 1024 * 1024;

/// …down to this.
const cacheTrimToBytes = 90 * 1024 * 1024;

/// Connect and idle timeout of one request.
const fetchTimeout = Duration(seconds: 15);

/// At most this many requests run at once, prefetch first (research R6, R7).
const maxConcurrentRequests = 2;

enum FetchError { offline, fetchFailed }

class FetchException implements Exception {
  const FetchException(this.error);
  final FetchError error;

  @override
  String toString() => 'FetchException(${error.name})';
}

/// Size of a recording in the catalogue: `quran.recordingBytes(reciter, surah)[ayah - 1]`.
typedef RecordingSize = Future<int> Function(String reciter, int surah, int ayah);

/// Where an ayah's clip sits in its surah file, `[start, end)` of a file of `total` bytes, for
/// reciters recorded one surah per file (specs/006 research R18); null for one file per ayah.
typedef ClipRange = Future<({int start, int end, int total})?> Function(
    String reciter, int surah, int ayah);

Future<({int start, int end, int total})?> _noClips(String reciter, int surah, int ayah) async =>
    null;

class AyahFetcher {
  AyahFetcher({
    required this.recordingSize,
    this.clipRange = _noClips,
    this.device = const DeviceChannel(),
    Future<Directory> Function()? cacheRoot,
    Future<Directory> Function()? supportRoot,
    HttpClient Function()? httpClient,
  })  : _cacheRoot = cacheRoot ?? getApplicationCacheDirectory,
        _supportRoot = supportRoot ?? getApplicationSupportDirectory,
        _newClient = httpClient ?? HttpClient.new;

  final RecordingSize recordingSize;
  final ClipRange clipRange;
  final DeviceChannel device;
  final Future<Directory> Function() _cacheRoot;
  final Future<Directory> Function() _supportRoot;
  final HttpClient Function() _newClient;

  /// Created on first use: none exists before the first play (and none in the web preview).
  late final HttpClient _client = _newClient()
    ..connectionTimeout = fetchTimeout
    ..idleTimeout = fetchTimeout;
  bool _clientUsed = false;

  final _inFlight = <String, Future<File>>{};
  final _protected = <String>{};
  final _gate = _RequestGate(maxConcurrentRequests);
  final _damaged = StreamController<(String, int)>.broadcast();
  int _prefetchGeneration = 0;
  Future<void>? _ready;

  /// A downloaded file failed its size check and was deleted: (reciter, surah).
  Stream<(String, int)> get onDamaged => _damaged.stream;

  /// Creates the directories and deletes stale `.part` files. Runs on first use.
  Future<void> init() => _ready ??= () async {
        final support = await _dir(_supportRoot, create: true);
        await device.excludeFromBackup(support.path);
        for (final root in [await _dir(_cacheRoot, create: true), support]) {
          await for (final f in root.list(recursive: true)) {
            if (f is File && f.path.endsWith('.part')) {
              try {
                await f.delete();
              } on FileSystemException {
                // In use by another isolate: it is cleaned up next launch.
              }
            }
          }
        }
      }();

  // --- Paths ---------------------------------------------------------------------------------

  Future<Directory> _dir(Future<Directory> Function() root, {bool create = false}) async {
    final d = Directory('${(await root()).path}${Platform.pathSeparator}recitations');
    if (create) await d.create(recursive: true);
    return d;
  }

  Future<File> cacheFile(String reciter, int surah, int ayah) async => File(
      '${(await _dir(_cacheRoot)).path}/$reciter/${pad3(surah)}${pad3(ayah)}.mp3');

  Future<File> downloadFile(String reciter, int surah, int ayah) async =>
      File('${await downloadDir(reciter, surah)}/${pad3(ayah)}.mp3');

  Future<String> downloadDir(String reciter, int surah) async =>
      '${(await _dir(_supportRoot)).path}/$reciter/${pad3(surah)}';

  Future<File> basmalaFile(String reciter) async =>
      File('${(await _dir(_supportRoot)).path}/$reciter/basmala.mp3');

  Future<Directory> reciterDownloads(String reciter) async =>
      Directory('${(await _dir(_supportRoot)).path}/$reciter');

  /// Root of all downloads, for the downloads scan.
  Future<Directory> downloadsRoot() => _dir(_supportRoot, create: true);

  /// Whether [file] exists with exactly [bytes] bytes.
  static Future<bool> isValid(File file, int bytes) async {
    try {
      return await file.length() == bytes;
    } on FileSystemException {
      return false;
    }
  }

  // --- Resolve -------------------------------------------------------------------------------

  /// A checked local file for [item]: the download, else the recent cache, else the network
  /// (primary, then mirror). Throws [FetchException].
  Future<File> resolve(Reciter r, RecitedItem item, {bool priority = true}) async {
    await init();
    final (s, a) = item.isBasmala ? (1, 1) : (item.surah, item.ayah);
    final bytes = await recordingSize(r.id, s, a);

    final downloaded = [
      if (item.isBasmala) await basmalaFile(r.id),
      await downloadFile(r.id, s, a),
    ];
    for (final f in downloaded) {
      if (await f.exists()) {
        if (await isValid(f, bytes)) return f;
        await _deleteQuietly(f);
        _damaged.add((r.id, item.isBasmala ? item.surah : s));
      }
    }

    final cached = await cacheFile(r.id, s, a);
    if (await cached.exists()) {
      if (await isValid(cached, bytes)) {
        await _touch(cached);
        return cached;
      }
      await _deleteQuietly(cached);
    }

    final file = await fetch(r, s, a, cached, bytes: bytes, priority: priority);
    unawaited(_trimCache());
    return file;
  }

  /// Downloads `<SSS><AAA>.mp3` of [r] into [target] (via `.part`), checked against [bytes].
  /// Tries the primary host, then the mirror once if [r] has one. For a reciter recorded one
  /// surah per file, the ayah is its byte range of the surah file. Shares one request per target
  /// path.
  Future<File> fetch(Reciter r, int surah, int ayah, File target,
      {required int bytes, bool priority = false}) {
    return _inFlight[target.path] ??= () async {
      try {
        if (await device.networkState() == NetworkState.none) {
          throw const FetchException(FetchError.offline);
        }
        final clip = r.source == RecitationSource.qulSurah
            ? await clipRange(r.id, surah, ayah)
            : null;
        if (r.source == RecitationSource.qulSurah && clip == null) {
          throw const FetchException(FetchError.fetchFailed);
        }
        for (final mirror in [false, if (r.mirrorUrl != null) true]) {
          final ok = await _gate.run(
            () => _get(Uri.parse(r.urlFor(surah, ayah, mirror: mirror)), target, bytes,
                clip: clip),
            priority: priority,
          );
          if (ok) return target;
        }
        throw const FetchException(FetchError.fetchFailed);
      } finally {
        unawaited(_inFlight.remove(target.path));
      }
    }();
  }

  Future<bool> _get(Uri url, File target, int bytes,
      {({int start, int end, int total})? clip}) async {
    final part = File('${target.path}.part');
    try {
      await target.parent.create(recursive: true);
      _clientUsed = true;
      final request = await _client.getUrl(url);
      if (clip != null) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=${clip.start}-${clip.end - 1}');
      }
      final response = await request.close().timeout(fetchTimeout);
      // A clip needs exactly its range of the file the catalogue measured: a whole file (range
      // ignored), another range or a replaced file is a failure, never a partial accept.
      final expected = clip == null
          ? null
          : 'bytes ${clip.start}-${clip.end - 1}/${clip.total}';
      final accepted = clip == null
          ? response.statusCode == HttpStatus.ok
          : response.statusCode == HttpStatus.partialContent &&
              response.headers.value(HttpHeaders.contentRangeHeader) == expected;
      if (!accepted) {
        await response.drain<void>();
        return false;
      }
      final sink = part.openWrite();
      try {
        await sink.addStream(response.timeout(fetchTimeout));
      } finally {
        await sink.close();
      }
      if (!await isValid(part, bytes)) {
        await _deleteQuietly(part);
        return false;
      }
      await part.rename(target.path);
      return true;
    } on FileSystemException catch (e) {
      await _deleteQuietly(part);
      if (_isNoSpace(e)) rethrow;
      return false;
    } on Object {
      await _deleteQuietly(part);
      return false;
    }
  }

  static bool _isNoSpace(FileSystemException e) {
    final code = e.osError?.errorCode;
    return code == 28 /* ENOSPC */ || code == 112 /* ERROR_DISK_FULL */;
  }

  // --- Prefetch ------------------------------------------------------------------------------

  /// Resolves [items] in order in the background. A later call, or [cancelPrefetch], abandons
  /// the remaining ones.
  void prefetch(Reciter r, List<RecitedItem> items) {
    final generation = ++_prefetchGeneration;
    unawaited(() async {
      for (final item in items) {
        if (generation != _prefetchGeneration) return;
        try {
          await resolve(r, item);
        } on Object {
          return; // the controller resolves it again when it is needed, and shows the error
        }
      }
    }());
  }

  void cancelPrefetch() => _prefetchGeneration++;

  /// Paths the cache trim must keep: the current and next items.
  void protect(Iterable<String> paths) {
    _protected
      ..clear()
      ..addAll(paths.map(_key));
  }

  /// One spelling per path, so paths built here match those listed from disk on Windows.
  static String _key(String path) => Platform.isWindows ? path.replaceAll('/', r'\') : path;

  // --- Cache ---------------------------------------------------------------------------------

  Future<List<File>> _cacheFiles() async {
    final root = await _dir(_cacheRoot);
    final files = <File>[];
    try {
      if (!await root.exists()) return files;
      await for (final f in root.list(recursive: true)) {
        if (f is File && f.path.endsWith('.mp3')) files.add(f);
      }
    } on FileSystemException {
      // The cache was cleared (by the reader or the OS) while listing: use what was found.
    }
    return files;
  }

  Future<int> cacheBytes() async {
    var total = 0;
    for (final f in await _cacheFiles()) {
      total += await _lengthOrZero(f);
    }
    return total;
  }

  /// Deletes the cache except protected files; returns the bytes freed. Never touches downloads.
  Future<int> clearCache() async {
    var freed = 0;
    for (final f in await _cacheFiles()) {
      if (_protected.contains(_key(f.path))) continue;
      final length = await _lengthOrZero(f);
      if (await _deleteQuietly(f)) freed += length;
    }
    return freed;
  }

  Future<void> _trimCache() async {
    final files = await _cacheFiles();
    final stats = <(File, int, DateTime)>[];
    var total = 0;
    for (final f in files) {
      try {
        final s = await f.stat();
        stats.add((f, s.size, s.modified));
        total += s.size;
      } on FileSystemException {
        // Deleted meanwhile.
      }
    }
    if (total <= cacheLimitBytes) return;
    stats.sort((a, b) => a.$3.compareTo(b.$3));
    for (final (f, size, _) in stats) {
      if (total <= cacheTrimToBytes) break;
      if (_protected.contains(_key(f.path))) continue;
      if (await _deleteQuietly(f)) total -= size;
    }
  }

  static Future<void> _touch(File f) async {
    try {
      await f.setLastModified(DateTime.now());
    } on FileSystemException {
      // Best effort: LRU order only.
    }
  }

  static Future<int> _lengthOrZero(File f) async {
    try {
      return await f.length();
    } on FileSystemException {
      return 0;
    }
  }

  static Future<bool> _deleteQuietly(File f) async {
    try {
      await f.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  void dispose() {
    cancelPrefetch();
    if (_clientUsed) _client.close(force: true);
    unawaited(_damaged.close());
  }
}

/// Limits concurrent requests; priority callers (the recitation being heard) go first.
class _RequestGate {
  _RequestGate(this.capacity);

  final int capacity;
  int _running = 0;
  final _waiting = ListQueue<Completer<void>>();
  final _waitingPriority = ListQueue<Completer<void>>();

  Future<T> run<T>(Future<T> Function() task, {bool priority = false}) async {
    if (_running >= capacity) {
      final turn = Completer<void>();
      (priority ? _waitingPriority : _waiting).add(turn);
      await turn.future;
    } else {
      _running++;
    }
    try {
      return await task();
    } finally {
      final next = _waitingPriority.isNotEmpty
          ? _waitingPriority.removeFirst()
          : (_waiting.isNotEmpty ? _waiting.removeFirst() : null);
      if (next != null) {
        next.complete(); // the slot passes straight to the next caller
      } else {
        _running--;
      }
    }
  }
}
