// Gets ayah recordings onto the device (specs/004-ayah-recitations/contracts/audio-storage.md).
// The player only ever plays a local file this class has checked against the catalogue size;
// that is how "never skip an ayah" holds the same on both platforms (research R5). Files go
// through FileStore and requests through package:http, so the same rules hold in browsers
// (specs/008 research R7, R18a).
import 'dart:async';
import 'dart:collection';

import 'package:http/http.dart' as http;

import '../../data/models.dart';
import '../../platform/device.dart';
import '../../platform/file_store.dart';
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
    FileStore? store,
    http.Client Function()? httpClient,
  })  : store = store ?? fileStore(),
        _newClient = httpClient ?? http.Client.new;

  final RecordingSize recordingSize;
  final ClipRange clipRange;
  final DeviceChannel device;
  final FileStore store;
  final http.Client Function() _newClient;

  /// Created on first use: none exists before the first play.
  late final http.Client _client = _newClient();
  bool _clientUsed = false;

  final _inFlight = <StoreFile, Future<StoreFile>>{};
  final _protected = <StoreFile>{};
  final _gate = _RequestGate(maxConcurrentRequests);
  final _damaged = StreamController<(String, int)>.broadcast();
  int _prefetchGeneration = 0;
  Future<void>? _ready;

  /// A downloaded file failed its size check and was deleted: (reciter, surah).
  Stream<(String, int)> get onDamaged => _damaged.stream;

  /// Deletes stale `.part` files. Runs on first use.
  Future<void> init() => _ready ??= () async {
        for (final root in StoreRoot.values) {
          for (final e in await store.list(root, _dirName, recursive: true)) {
            // One still being written by another isolate fails to delete: it goes next launch.
            if (!e.isDir && e.path.endsWith('.part')) await store.delete(StoreFile(root, e.path));
          }
        }
      }();

  // --- Paths ---------------------------------------------------------------------------------

  static const _dirName = 'recitations';

  Future<StoreFile> cacheFile(String reciter, int surah, int ayah) async =>
      StoreFile(StoreRoot.cache, '$_dirName/$reciter/${pad3(surah)}${pad3(ayah)}.mp3');

  Future<StoreFile> downloadFile(String reciter, int surah, int ayah) async =>
      StoreFile(StoreRoot.support, '${await downloadDir(reciter, surah)}/${pad3(ayah)}.mp3');

  /// A surah's downloads, relative to the support root.
  Future<String> downloadDir(String reciter, int surah) async =>
      '${await reciterDownloads(reciter)}/${pad3(surah)}';

  Future<StoreFile> basmalaFile(String reciter) async =>
      StoreFile(StoreRoot.support, '${await reciterDownloads(reciter)}/basmala.mp3');

  /// A reciter's downloads, relative to the support root.
  Future<String> reciterDownloads(String reciter) async => '$_dirName/$reciter';

  /// Root of all downloads, relative to the support root, for the downloads scan.
  String get downloadsRoot => _dirName;

  /// Whether [file] exists with exactly [bytes] bytes.
  Future<bool> isValid(StoreFile file, int bytes) async => await store.length(file) == bytes;

  // --- Resolve -------------------------------------------------------------------------------

  /// A checked local file for [item]: the download, else the recent cache, else the network
  /// (primary, then mirror). Throws [FetchException].
  Future<StoreFile> resolve(Reciter r, RecitedItem item, {bool priority = true}) async {
    await init();
    final (s, a) = item.isBasmala ? (1, 1) : (item.surah, item.ayah);
    final bytes = await recordingSize(r.id, s, a);

    final downloaded = [
      if (item.isBasmala) await basmalaFile(r.id),
      await downloadFile(r.id, s, a),
    ];
    for (final f in downloaded) {
      final length = await store.length(f);
      if (length != null) {
        if (length == bytes) return f;
        await store.delete(f);
        _damaged.add((r.id, item.isBasmala ? item.surah : s));
      }
    }

    final cached = await cacheFile(r.id, s, a);
    final length = await store.length(cached);
    if (length != null) {
      if (length == bytes) {
        await store.touch(cached);
        return cached;
      }
      await store.delete(cached);
    }

    final file = await fetch(r, s, a, cached, bytes: bytes, priority: priority);
    unawaited(_trimCache());
    return file;
  }

  /// Downloads `<SSS><AAA>.mp3` of [r] into [target] (via `.part`), checked against [bytes].
  /// Tries the primary host, then the mirror once if [r] has one. For a reciter recorded one
  /// surah per file, the ayah is its byte range of the surah file. Shares one request per target.
  /// Throws [FetchException], or [NoSpaceException] when storage is full.
  Future<StoreFile> fetch(Reciter r, int surah, int ayah, StoreFile target,
      {required int bytes, bool priority = false}) {
    return _inFlight[target] ??= () async {
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
        unawaited(_inFlight.remove(target));
      }
    }();
  }

  Future<bool> _get(Uri url, StoreFile target, int bytes,
      {({int start, int end, int total})? clip}) async {
    final part = target.part;
    try {
      await store.delete(part);
      _clientUsed = true;
      final request = http.Request('GET', url);
      if (clip != null) request.headers['range'] = 'bytes=${clip.start}-${clip.end - 1}';
      final response = await _client.send(request).timeout(fetchTimeout);
      if (!_accepted(response, clip)) {
        await response.stream.drain<void>();
        return false;
      }
      await store.append(part, response.stream.timeout(fetchTimeout));
      if (!await isValid(part, bytes)) {
        await store.delete(part);
        return false;
      }
      await store.rename(part, target);
      return true;
    } on NoSpaceException {
      await store.delete(part);
      rethrow;
    } on Object {
      await store.delete(part);
      return false;
    }
  }

  /// A clip needs exactly its range of the file the catalogue measured: a whole file (range
  /// ignored), another range or a replaced file is a failure, never a partial accept. Browsers
  /// hide Content-Range from hosts that do not expose it (everyayah.com, quranicaudio.com); then
  /// the range's length must match (specs/008 research R18a).
  static bool _accepted(http.StreamedResponse response, ({int start, int end, int total})? clip) {
    if (clip == null) return response.statusCode == 200;
    if (response.statusCode != 206) return false;
    final range = response.headers['content-range'];
    if (range != null) return range == 'bytes ${clip.start}-${clip.end - 1}/${clip.total}';
    return response.contentLength == clip.end - clip.start;
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

  /// Files the cache trim must keep: the current and next items.
  void protect(Iterable<StoreFile> files) {
    _protected
      ..clear()
      ..addAll(files);
  }

  // --- Cache ---------------------------------------------------------------------------------

  Future<List<StoreEntry>> _cacheFiles() async => [
        for (final e in await store.list(StoreRoot.cache, _dirName, recursive: true))
          if (!e.isDir && e.path.endsWith('.mp3')) e,
      ];

  Future<int> cacheBytes() async =>
      (await _cacheFiles()).fold<int>(0, (total, e) => total + e.bytes);

  /// Deletes the cache except protected files; returns the bytes freed. Never touches downloads.
  Future<int> clearCache() async {
    var freed = 0;
    for (final e in await _cacheFiles()) {
      final f = StoreFile(StoreRoot.cache, e.path);
      if (_protected.contains(f)) continue;
      if (await store.delete(f)) freed += e.bytes;
    }
    return freed;
  }

  Future<void> _trimCache() async {
    final files = await _cacheFiles();
    var total = files.fold<int>(0, (t, e) => t + e.bytes);
    if (total <= cacheLimitBytes) return;
    files.sort((a, b) => a.modified.compareTo(b.modified));
    for (final e in files) {
      if (total <= cacheTrimToBytes) break;
      final f = StoreFile(StoreRoot.cache, e.path);
      if (_protected.contains(f)) continue;
      if (await store.delete(f)) total -= e.bytes;
    }
  }

  void dispose() {
    cancelPrefetch();
    if (_clientUsed) _client.close();
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
