// The recognition model on the device (specs/006 contracts/memorization-engine.md › AsrModel,
// research R9; specs/007 contracts/live-recognition.md › AsrModel, research R4, R7). The only
// memorization file that uses the network or writes files: it downloads the model and never sees
// audio (memorization_privacy_test).
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../shared/device_channel.dart';

/// The GitHub release the files come from; a new export is a new version (tool/README.md).
const asrModelVersion = 'asr-khatma-v1';

const asrModelBase =
    'https://github.com/hamzagamil/mathani/releases/download/$asrModelVersion/';

/// One file of the release. A name ending in `.gz` is unpacked on the device and kept without
/// the suffix; [unpackedBytes] and [unpackedSha256] pin what is kept.
class AsrFile {
  const AsrFile(this.name, this.bytes, this.sha256, {this.unpackedBytes, this.unpackedSha256})
      : assert((unpackedBytes == null) == (unpackedSha256 == null));

  final String name;
  final int bytes;
  final String sha256;
  final int? unpackedBytes;
  final String? unpackedSha256;

  bool get packed => unpackedBytes != null;

  /// The name of the file kept on the device.
  String get kept => packed ? name.substring(0, name.length - '.gz'.length) : name;

  int get keptBytes => unpackedBytes ?? bytes;
}

/// The release's files, pinned from tool/export_khatma_model.py (specs/007 T001, research R4).
const asrModelFiles = <AsrFile>[
  AsrFile(
    'model.int8.onnx.gz',
    107497463,
    '40c4f1730d8d94df0fd6076eb1922686125d29cbc982d35e868c3c00136a9c27',
    unpackedBytes: 133342218,
    unpackedSha256: '2f7be8307d3921cf05ad0bb3635222ad057fbe9bde77d1c907d23f83b488bc88',
  ),
  AsrFile(
    'tokens.txt',
    12858,
    '9b938381a19a69bb279cdcfc299419f25a049ea1de192e0d10317274a0f20074',
  ),
  AsrFile(
    'silero_vad.onnx',
    643854,
    '9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6',
  ),
];

/// Connect and idle timeout of one request, as for recordings.
const asrFetchTimeout = Duration(seconds: 15);

enum AsrModelState { absent, partial, downloading, ready }

enum AsrModelError { failed, damaged, noSpace }

class AsrModelException implements Exception {
  const AsrModelException(this.error);
  final AsrModelError error;

  @override
  String toString() => 'AsrModelException(${error.name})';
}

/// The model's files in `<app support>/asr/<version>/`, excluded from backup. The state is
/// derived from the files: call [refresh] once before reading it.
class AsrModel extends ChangeNotifier {
  AsrModel({
    this.device = const DeviceChannel(),
    this.version = asrModelVersion,
    this.files = asrModelFiles,
    Uri? base,
    Future<Directory> Function()? supportRoot,
    HttpClient Function()? httpClient,
  })  : base = base ?? Uri.parse(asrModelBase),
        _supportRoot = supportRoot ?? getApplicationSupportDirectory,
        _newClient = httpClient ?? HttpClient.new;

  final DeviceChannel device;
  final String version;
  final List<AsrFile> files;
  final Uri base;
  final Future<Directory> Function() _supportRoot;
  final HttpClient Function() _newClient;

  AsrModelState _state = AsrModelState.absent;
  AsrModelState get state => _state;

  int _downloadedBytes = 0;
  int get downloadedBytes => _downloadedBytes;

  /// The download size, shown before downloading.
  int get totalBytes => files.fold(0, (sum, f) => sum + f.bytes);

  /// The space the model takes once ready (Settings › Downloads).
  int get diskBytes => files.fold(0, (sum, f) => sum + f.keptBytes);

  /// Free space needed to download and unpack: a packed file and what it unpacks to are both on
  /// disk until the unpack is checked.
  int get requiredBytes => totalBytes + files.fold(0, (sum, f) => sum + (f.unpackedBytes ?? 0));

  Directory? _dir;

  /// Valid only when [state] is ready.
  String get modelDir => _dir!.path;

  HttpClient? _client;
  Future<void>? _download;
  bool _cancelled = false;

  Future<Directory> _root() async => Directory('${(await _supportRoot()).path}/asr');

  Future<Directory> _folder() async => _dir ??= Directory('${(await _root()).path}/$version');

  /// Reads the state from the files: ready when every kept file is complete; partial when some
  /// bytes are there. Hashes are checked when a file is downloaded or unpacked, not here.
  Future<void> refresh() async {
    if (_download == null) await _readState();
  }

  Future<void> _readState() async {
    final dir = await _folder();
    var bytes = 0, complete = 0;
    for (final f in files) {
      final kept = File('${dir.path}/${f.kept}');
      final download = File('${dir.path}/${f.name}');
      final part = File('${download.path}.part');
      if (await kept.exists() && await kept.length() == f.keptBytes) {
        bytes += f.bytes; // progress counts downloads, so it stays within totalBytes
        complete++;
      } else if (f.packed && await download.exists() && await download.length() == f.bytes) {
        bytes += f.bytes; // downloaded, not yet unpacked
      } else if (await part.exists()) {
        bytes += await part.length();
      }
    }
    _downloadedBytes = bytes;
    _set(complete == files.length
        ? AsrModelState.ready
        : bytes > 0
            ? AsrModelState.partial
            : AsrModelState.absent);
  }

  /// Downloads what is missing, one file at a time, resuming from `.part` with `Range`. Throws
  /// [AsrModelException] on failure, keeping what was verified; returns quietly after [cancel].
  Future<void> download() => _download ??= _run().whenComplete(() => _download = null);

  Future<void> _run() async {
    _cancelled = false;
    final dir = await _folder();
    await dir.create(recursive: true);
    await device.excludeFromBackup((await _root()).path);
    await _deleteOtherVersions();
    await _readState();
    _set(AsrModelState.downloading);
    try {
      for (final f in files) {
        if (_cancelled) break;
        final kept = File('${dir.path}/${f.kept}');
        if (await kept.exists() && await kept.length() == f.keptBytes) continue;
        final file = File('${dir.path}/${f.name}');
        if (!(await file.exists() && await file.length() == f.bytes)) await _fetch(f, file);
        if (_cancelled) break;
        if (f.packed) await _unpack(f, file, kept);
      }
    } finally {
      _client?.close(force: true);
      _client = null;
      await _readState();
    }
  }

  Future<void> _fetch(AsrFile f, File file) async {
    final part = File('${file.path}.part');
    var have = await part.exists() ? await part.length() : 0;
    if (have > f.bytes) {
      await part.delete();
      _downloadedBytes -= have;
      have = 0;
    }
    try {
      if (have < f.bytes) {
        final client = _client ??= _newClient()
          ..connectionTimeout = asrFetchTimeout
          ..idleTimeout = asrFetchTimeout;
        final request = await client.getUrl(base.resolve(f.name));
        if (have > 0) request.headers.set(HttpHeaders.rangeHeader, 'bytes=$have-');
        final response = await request.close().timeout(asrFetchTimeout);
        final resumed = have > 0 &&
            response.statusCode == HttpStatus.partialContent &&
            response.headers.value(HttpHeaders.contentRangeHeader) ==
                'bytes $have-${f.bytes - 1}/${f.bytes}';
        if (!resumed && response.statusCode != HttpStatus.ok) {
          await response.drain<void>();
          throw const AsrModelException(AsrModelError.failed);
        }
        if (!resumed) {
          _downloadedBytes -= have; // the whole file came back: start the part again
          have = 0;
        }
        final sink = part.openWrite(mode: resumed ? FileMode.append : FileMode.write);
        final progress = Stopwatch()..start();
        try {
          await for (final chunk in response.timeout(asrFetchTimeout)) {
            if (_cancelled) break;
            sink.add(chunk);
            _downloadedBytes += chunk.length;
            if (progress.elapsedMilliseconds >= 100) {
              progress.reset();
              notifyListeners();
            }
          }
        } finally {
          await sink.close();
        }
        if (_cancelled) return;
      }
      if (await part.length() != f.bytes ||
          (await sha256.bind(part.openRead()).first).toString() != f.sha256) {
        await part.delete();
        throw const AsrModelException(AsrModelError.damaged);
      }
      await part.rename(file.path);
    } on AsrModelException {
      rethrow;
    } on FileSystemException catch (e) {
      final code = e.osError?.errorCode;
      throw AsrModelException(code == 28 /* ENOSPC */ || code == 112 /* ERROR_DISK_FULL */
          ? AsrModelError.noSpace
          : AsrModelError.failed);
    } on Object {
      if (_cancelled) return; // the connection was closed by cancel()
      throw const AsrModelException(AsrModelError.failed);
    }
  }

  /// Decompresses a checked `.gz` on a background isolate into [kept], checking the result
  /// against its pinned size and SHA-256, then deletes the `.gz` (research R4). A `.gz` left from
  /// a closed app is checked again first, so it is never fetched twice.
  Future<void> _unpack(AsrFile f, File packed, File kept) async {
    final packedPath = packed.path, keptPath = kept.path;
    final packedSha = f.sha256, keptBytes = f.unpackedBytes!, keptSha = f.unpackedSha256!;
    final outcome =
        await Isolate.run(() => _unpackFile(packedPath, keptPath, packedSha, keptBytes, keptSha));
    switch (outcome) {
      case _Unpack.done:
        await packed.delete();
      case _Unpack.badDownload:
        if (await packed.exists()) await packed.delete();
        throw const AsrModelException(AsrModelError.damaged);
      case _Unpack.badResult:
        throw const AsrModelException(AsrModelError.damaged);
      case _Unpack.noSpace:
        throw const AsrModelException(AsrModelError.noSpace);
    }
  }

  /// Stops the download; what was saved is kept for the next [download].
  void cancel() {
    if (_download == null) return;
    _cancelled = true;
    _client?.close(force: true);
  }

  /// Frees the model's files at once.
  Future<void> delete() async {
    cancel();
    await _download?.catchError((Object _) {});
    final root = await _root();
    if (await root.exists()) await root.delete(recursive: true);
    _downloadedBytes = 0;
    _set(AsrModelState.absent);
  }

  /// A new model version replaces the old one: its folder is deleted when the new one starts.
  Future<void> _deleteOtherVersions() =>
      removeOtherVersions(supportRoot: _supportRoot, version: version);

  /// Deletes every model version but [version] (specs/007 FR-004, research R7). Called after the
  /// first frame of each launch, so updating frees the previous model's space without opening
  /// memorization. Never throws: what fails is tried again on the next launch.
  static Future<void> removeOtherVersions(
      {Future<Directory> Function()? supportRoot, String version = asrModelVersion}) async {
    try {
      final root =
          Directory('${(await (supportRoot ?? getApplicationSupportDirectory)()).path}/asr');
      if (!await root.exists()) return;
      await for (final entry in root.list()) {
        // Compared by name: list() joins paths with the platform's separator.
        final name = entry.path.substring(root.path.length + 1);
        if (entry is Directory && name != version) {
          try {
            await entry.delete(recursive: true);
          } on FileSystemException {
            // Kept for the next launch.
          }
        }
      }
    } on Object {
      // No support directory, or it cannot be listed: nothing to free now.
    }
  }

  void _set(AsrModelState s) {
    _state = s;
    notifyListeners();
  }
}

enum _Unpack { done, badDownload, badResult, noSpace }

/// Runs on a background isolate: checks [packedPath] against [packedSha256], then streams it
/// through gzip into `<keptPath>.part` while hashing, and renames it once it matches.
Future<_Unpack> _unpackFile(
    String packedPath, String keptPath, String packedSha256, int keptBytes, String keptSha256) async {
  final packed = File(packedPath);
  if ((await sha256.bind(packed.openRead()).first).toString() != packedSha256) {
    return _Unpack.badDownload;
  }
  final part = File('$keptPath.part');
  final digest = _DigestSink();
  final hash = sha256.startChunkedConversion(digest);
  final sink = part.openWrite();
  var written = 0;
  try {
    await for (final chunk in packed.openRead().transform(gzip.decoder)) {
      sink.add(chunk);
      hash.add(chunk);
      written += chunk.length;
    }
    await sink.close();
  } on FileSystemException catch (e) {
    await sink.close().catchError((Object _) {});
    if (await part.exists()) await part.delete();
    final code = e.osError?.errorCode;
    return code == 28 /* ENOSPC */ || code == 112 /* ERROR_DISK_FULL */
        ? _Unpack.noSpace
        : _Unpack.badResult;
  } on FormatException {
    // Not gzip after all: the download is wrong, not the unpack.
    await sink.close().catchError((Object _) {});
    if (await part.exists()) await part.delete();
    return _Unpack.badDownload;
  }
  hash.close();
  if (written != keptBytes || digest.value.toString() != keptSha256) {
    await part.delete();
    return _Unpack.badResult;
  }
  await part.rename(keptPath);
  return _Unpack.done;
}

/// Receives the digest of a chunked SHA-256.
class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
