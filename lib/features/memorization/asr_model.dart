// The recognition model on the device (specs/006 contracts/memorization-engine.md › AsrModel,
// research R9). The only memorization file that uses the network or writes files: it downloads
// the model and never sees audio (memorization_privacy_test).
import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../shared/device_channel.dart';

/// The GitHub release the files come from; a new export is a new version (tool/README.md).
const asrModelVersion = 'asr-tarteel-tiny-v1';

const asrModelBase =
    'https://github.com/hamzagamil/mathani/releases/download/$asrModelVersion/';

typedef AsrFile = ({String name, int bytes, String sha256});

/// The release's files, pinned (tasks.md › Notes › T029).
const asrModelFiles = <AsrFile>[
  (
    name: 'encoder.int8.onnx',
    bytes: 12926471,
    sha256: '30c1c6f988f395cc212c92795c2c9d7589a65b4909a70c72515667af73501b17',
  ),
  (
    name: 'decoder.int8.onnx',
    bytes: 50015755,
    sha256: '7cbd0e65cd3348c3577280d85d80383798300ce8c0c3dd7953cdab69bbee5538',
  ),
  (
    name: 'tokens.txt',
    bytes: 866987,
    sha256: 'febeed8e568f92d9ca984580bc2e6b605b867dc5ba4486f9646de381b44a8226',
  ),
  (
    name: 'silero_vad.onnx',
    bytes: 643854,
    sha256: '9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6',
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
  int get totalBytes => files.fold(0, (sum, f) => sum + f.bytes);

  Directory? _dir;

  /// Valid only when [state] is ready.
  String get modelDir => _dir!.path;

  HttpClient? _client;
  Future<void>? _download;
  bool _cancelled = false;

  Future<Directory> _root() async => Directory('${(await _supportRoot()).path}/asr');

  Future<Directory> _folder() async => _dir ??= Directory('${(await _root()).path}/$version');

  /// Reads the state from the files: ready when every file is complete; partial when some bytes
  /// are there. Hashes are checked when a file is downloaded, not here.
  Future<void> refresh() async {
    if (_download == null) await _readState();
  }

  Future<void> _readState() async {
    final dir = await _folder();
    var bytes = 0, complete = 0;
    for (final f in files) {
      final file = File('${dir.path}/${f.name}');
      final part = File('${file.path}.part');
      if (await file.exists() && await file.length() == f.bytes) {
        bytes += f.bytes;
        complete++;
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
        final file = File('${dir.path}/${f.name}');
        if (await file.exists() && await file.length() == f.bytes) continue;
        await _fetch(f, file);
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
  Future<void> _deleteOtherVersions() async {
    final root = await _root();
    await for (final entry in root.list()) {
      // Compared by name: list() joins paths with the platform's separator.
      final name = entry.path.substring(root.path.length + 1);
      if (entry is Directory && name != version) await entry.delete(recursive: true);
    }
  }

  void _set(AsrModelState s) {
    _state = s;
    notifyListeners();
  }
}
