import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

import '../features/memorization/sherpa_recogniser.dart';
import '../features/memorization/speech_recogniser.dart';
import 'file_store.dart';
import 'speech_host.dart' show UnpackResult;

/// Phones run memorization wherever the device passes its gate.
const speechEngineAvailable = true;

/// sherpa-onnx in a long-lived isolate.
SpeechRecogniser newSpeechRecogniser() => SherpaSpeechRecogniser();

/// Decompresses a checked `.gz` on a background isolate into [kept], checking the result against
/// its pinned size and SHA-256 (specs/007 research R4). [packed] is left for the caller.
Future<UnpackResult> unpackModel(FileStore store, StoreFile packed, StoreFile kept,
    {required String packedSha256, required int keptBytes, required String keptSha256}) async {
  String pathOf(StoreFile f) => f.path.substring(f.dir.length + 1);
  final packedPath = '${await store.locate(packed.root, packed.dir)}/${pathOf(packed)}';
  final keptPath = '${await store.locate(kept.root, kept.dir)}/${pathOf(kept)}';
  return Isolate.run(() => _unpackFile(packedPath, keptPath, packedSha256, keptBytes, keptSha256));
}

/// Runs on a background isolate: checks [packedPath] against [packedSha256], then streams it
/// through gzip into `<keptPath>.part` while hashing, and renames it once it matches.
Future<UnpackResult> _unpackFile(
    String packedPath, String keptPath, String packedSha256, int keptBytes, String keptSha256) async {
  final packed = File(packedPath);
  if ((await sha256.bind(packed.openRead()).first).toString() != packedSha256) {
    return UnpackResult.badDownload;
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
        ? UnpackResult.noSpace
        : UnpackResult.badResult;
  } on FormatException {
    // Not gzip after all: the download is wrong, not the unpack.
    await sink.close().catchError((Object _) {});
    if (await part.exists()) await part.delete();
    return UnpackResult.badDownload;
  }
  hash.close();
  if (written != keptBytes || digest.value.toString() != keptSha256) {
    await part.delete();
    return UnpackResult.badResult;
  }
  await part.rename(keptPath);
  return UnpackResult.done;
}

/// Receives the digest of a chunked SHA-256.
class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
