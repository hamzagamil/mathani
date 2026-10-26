// The recognition model on the device (specs/006 contracts/memorization-engine.md › AsrModel,
// research R9; specs/007 contracts/live-recognition.md › AsrModel, research R4, R7). The only
// memorization file that uses the network or writes files: it downloads the model and never sees
// audio (memorization_privacy_test).
import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../platform/device.dart';
import '../../platform/file_store.dart';
import '../../platform/speech_host.dart';

/// The GitHub release the files come from; a new export is a new version (tool/README.md).
const asrModelVersion = 'asr-khatma-v1';

const asrModelBase = kIsWeb
    ? asrModelBaseWeb
    : 'https://github.com/hamzagamil/mathani/releases/download/$asrModelVersion/';

/// Browsers cannot read GitHub release files (no CORS), so the web app downloads the same files
/// from a Hugging Face mirror (specs/008 research R6), pinned to the commit that uploaded them
/// (2026-10-26). A new model version is a new upload and a new commit here (tool/README.md).
const asrModelBaseWeb = 'https://huggingface.co/hamzagamil/mathani-asr/resolve/'
    'dd396c6691bc98b73ba2076078d3ed9caa0313b6/$asrModelVersion/';

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

/// The model's files in `asr/<version>/` of the support root, protected (out of backups on iOS,
/// persistent in browsers). The state is derived from the files: call [refresh] once before
/// reading it.
class AsrModel extends ChangeNotifier {
  AsrModel({
    this.device = const DeviceChannel(),
    this.version = asrModelVersion,
    this.files = asrModelFiles,
    Uri? base,
    FileStore? store,
    http.Client Function()? httpClient,
  })  : base = base ?? Uri.parse(asrModelBase),
        store = store ?? fileStore(),
        _newClient = httpClient ?? http.Client.new;

  final DeviceChannel device;
  final String version;
  final List<AsrFile> files;
  final Uri base;
  final FileStore store;
  final http.Client Function() _newClient;

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

  static const _root = 'asr';
  String get _folder => '$_root/$version';
  StoreFile _file(String name) => StoreFile(StoreRoot.support, '$_folder/$name');

  String? _modelDir;

  /// Where the recogniser loads the model from (FileStore.locate). Valid only when [state] is
  /// ready.
  String get modelDir => _modelDir!;

  http.Client? _client;
  Future<void>? _download;
  bool _cancelled = false;

  /// Reads the state from the files: ready when every kept file is complete; partial when some
  /// bytes are there. Hashes are checked when a file is downloaded or unpacked, not here.
  Future<void> refresh() async {
    if (_download == null) await _readState();
  }

  Future<void> _readState() async {
    var bytes = 0, complete = 0;
    for (final f in files) {
      final kept = await store.length(_file(f.kept));
      final download = await store.length(_file(f.name));
      final part = await store.length(_file(f.name).part);
      if (kept == f.keptBytes) {
        bytes += f.bytes; // progress counts downloads, so it stays within totalBytes
        complete++;
      } else if (f.packed && download == f.bytes) {
        bytes += f.bytes; // downloaded, not yet unpacked
      } else if (part != null) {
        bytes += part;
      }
    }
    _downloadedBytes = bytes;
    if (complete == files.length) _modelDir = await store.locate(StoreRoot.support, _folder);
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
    await store.protect(StoreRoot.support, _root);
    await _deleteOtherVersions();
    await _readState();
    _set(AsrModelState.downloading);
    try {
      for (final f in files) {
        if (_cancelled) break;
        final kept = _file(f.kept);
        if (await store.length(kept) == f.keptBytes) continue;
        final file = _file(f.name);
        if (await store.length(file) != f.bytes) await _fetch(f, file);
        if (_cancelled) break;
        if (f.packed) await _unpack(f, file, kept);
      }
    } finally {
      _client?.close();
      _client = null;
      await _readState();
    }
  }

  Future<void> _fetch(AsrFile f, StoreFile file) async {
    final part = file.part;
    var have = await store.length(part) ?? 0;
    if (have > f.bytes) {
      await store.delete(part);
      _downloadedBytes -= have;
      have = 0;
    }
    try {
      if (have < f.bytes) {
        final client = _client ??= _newClient();
        final request = http.Request('GET', base.resolve(f.name));
        if (have > 0) request.headers['range'] = 'bytes=$have-';
        final response = await client.send(request).timeout(asrFetchTimeout);
        final resumed = have > 0 &&
            response.statusCode == 206 &&
            _resumesAt(response, have, f.bytes);
        if (!resumed && response.statusCode != 200) {
          await response.stream.drain<void>();
          throw const AsrModelException(AsrModelError.failed);
        }
        if (!resumed) {
          await store.delete(part); // the whole file came back: start the part again
          _downloadedBytes -= have;
          have = 0;
        }
        final progress = Stopwatch()..start();
        await store.append(
            part,
            response.stream.timeout(asrFetchTimeout).takeWhile((_) => !_cancelled).map((chunk) {
              _downloadedBytes += chunk.length;
              if (progress.elapsedMilliseconds >= 100) {
                progress.reset();
                notifyListeners();
              }
              return chunk;
            }));
        if (_cancelled) return;
      }
      if (await store.length(part) != f.bytes ||
          (await sha256.bind(store.read(part)).first).toString() != f.sha256) {
        await store.delete(part);
        throw const AsrModelException(AsrModelError.damaged);
      }
      await store.rename(part, file);
    } on AsrModelException {
      rethrow;
    } on NoSpaceException {
      throw const AsrModelException(AsrModelError.noSpace);
    } on Object {
      if (_cancelled) return; // the connection was closed by cancel()
      throw const AsrModelException(AsrModelError.failed);
    }
  }

  /// Whether a `206` continues at [have]. Browsers hide Content-Range from hosts that do not
  /// expose it; then the remaining length must match (specs/008 research R18a).
  static bool _resumesAt(http.StreamedResponse response, int have, int bytes) {
    final range = response.headers['content-range'];
    if (range != null) return range == 'bytes $have-${bytes - 1}/$bytes';
    return response.contentLength == bytes - have;
  }

  /// Decompresses a checked `.gz` into [kept] off the UI thread, checking the result against its
  /// pinned size and SHA-256, then deletes the `.gz` (research R4). A `.gz` left from a closed app
  /// is checked again first, so it is never fetched twice.
  Future<void> _unpack(AsrFile f, StoreFile packed, StoreFile kept) async {
    final outcome = await unpackModel(store, packed, kept,
        packedSha256: f.sha256, keptBytes: f.unpackedBytes!, keptSha256: f.unpackedSha256!);
    switch (outcome) {
      case UnpackResult.done:
        await store.delete(packed);
      case UnpackResult.badDownload:
        await store.delete(packed);
        throw const AsrModelException(AsrModelError.damaged);
      case UnpackResult.badResult:
        throw const AsrModelException(AsrModelError.damaged);
      case UnpackResult.noSpace:
        throw const AsrModelException(AsrModelError.noSpace);
    }
  }

  /// Stops the download; what was saved is kept for the next [download].
  void cancel() {
    if (_download == null) return;
    _cancelled = true;
    _client?.close();
  }

  /// Frees the model's files at once.
  Future<void> delete() async {
    cancel();
    await _download?.catchError((Object _) {});
    await store.deleteDir(StoreRoot.support, _root);
    _downloadedBytes = 0;
    _set(AsrModelState.absent);
  }

  /// A new model version replaces the old one: its folder is deleted when the new one starts.
  Future<void> _deleteOtherVersions() => removeOtherVersions(store: store, version: version);

  /// Deletes every model version but [version] (specs/007 FR-004, research R7). Called after the
  /// first frame of each launch, so updating frees the previous model's space without opening
  /// memorization. Never throws: what fails is tried again on the next launch.
  static Future<void> removeOtherVersions({FileStore? store, String version = asrModelVersion}) async {
    try {
      final s = store ?? fileStore();
      for (final entry in await s.list(StoreRoot.support, _root)) {
        if (entry.isDir && entry.path != '$_root/$version') {
          try {
            await s.deleteDir(StoreRoot.support, entry.path);
          } on Object {
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
