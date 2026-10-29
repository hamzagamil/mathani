import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../platform/file_store.dart';
import 'prayer_models.dart';
import 'prayer_services.dart';

void validateAthanDownload(AthanRecording recording) {
  final uri = Uri.tryParse(recording.fullAssetUrl);
  if (!recording.completeRecordingReviewed ||
      !RegExp(r'^[a-z][a-z0-9-]{0,63}$').hasMatch(recording.id) ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(recording.sha256) ||
      recording.expectedBytes <= 0 ||
      recording.expectedBytes > 16 * 1024 * 1024 ||
      recording.durationMs <= 0 ||
      recording.durationMs > 600000 ||
      recording.encoding != 'aac-lc/m4a' ||
      uri == null ||
      uri.scheme != 'https' ||
      !{'get.mthani.app', 'read.mthani.app'}.contains(uri.host) ||
      (uri.hasPort && uri.port != 443) ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      !RegExp(r'^/athan/v[0-9]+/[a-z0-9_-]+\.m4a$').hasMatch(uri.path)) {
    throw const FormatException('Invalid or unreviewed athan download');
  }
}

class AthanCatalogue {
  AthanCatalogue._(List<AthanRecording> recordings)
    : recordings = List.unmodifiable(recordings);
  final List<AthanRecording> recordings;
  factory AthanCatalogue.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 || json['recordings'] is! List) {
      throw const FormatException('Unsupported athan catalogue');
    }
    final recordings = <AthanRecording>[];
    final ids = <String>{};
    for (final raw in json['recordings'] as List) {
      if (raw is! Map) throw const FormatException('Invalid athan entry');
      if (raw['completeRecordingReviewed'] != true ||
          raw['fourTakbirsReviewed'] != true) {
        continue;
      }
      try {
        final variants = raw['openingVariants'] as Map;
        final hashes = <String, String>{}, encodings = <String, String>{};
        for (final variant in {'ios': 'caf', 'android': 'ogg'}.entries) {
          final data = variants[variant.value] as Map;
          final hash = data['sha256'] as String;
          if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
              (data['expectedBytes'] as int) <= 0) {
            throw const FormatException('Invalid opening integrity');
          }
          hashes[variant.key] = hash;
          encodings[variant.key] = data['encoding'] as String;
        }
        final recording = AthanRecording(
          id: raw['id'] as String,
          titleAr: raw['titleAr'] as String,
          titleEn: raw['titleEn'] as String,
          creditedRecorder: raw['creditedRecorder'] as String,
          sourceUrl: raw['sourceUrl'] as String,
          sourceRevision: raw['sourceRevision'] as String,
          licenseId: raw['licenseId'] as String,
          licenseUrl: raw['licenseUrl'] as String,
          changeNotice: raw['changeNotice'] as String,
          fullAssetUrl: raw['fullAssetUrl'] as String,
          sha256: raw['sha256'] as String,
          expectedBytes: raw['expectedBytes'] as int,
          durationMs: raw['durationMs'] as int,
          encoding: raw['encoding'] as String,
          openingAssetId: raw['openingAssetId'] as String,
          openingStartMs: raw['openingStartMs'] as int? ?? 0,
          openingEndMs: raw['openingEndMs'] as int,
          openingDurationMs: raw['openingDurationMs'] as int,
          platformClipHashes: Map.unmodifiable(hashes),
          platformClipEncodings: Map.unmodifiable(encodings),
          completeRecordingReviewed: true,
          fourTakbirsReviewed: true,
        );
        validateAthanDownload(recording);
        if (!ids.add(recording.id) ||
            recording.titleAr.trim().isEmpty ||
            recording.titleEn.trim().isEmpty ||
            recording.creditedRecorder.trim().isEmpty ||
            !{'CC0-1.0', 'CC-BY-3.0'}.contains(recording.licenseId) ||
            !recording.sourceUrl.startsWith('https://') ||
            !recording.sourceRevision.startsWith('https://') ||
            !recording.licenseUrl.startsWith('https://creativecommons.org/') ||
            recording.openingStartMs < 0 ||
            recording.openingEndMs <= recording.openingStartMs ||
            recording.openingEndMs > recording.durationMs ||
            recording.openingDurationMs <= 0 ||
            (recording.openingDurationMs -
                        (recording.openingEndMs - recording.openingStartMs))
                    .abs() >
                100 ||
            !RegExp(r'^[a-z][a-z0-9_]{0,63}$')
                .hasMatch(recording.openingAssetId)) {
          throw const FormatException('Invalid reviewed athan metadata');
        }
        recordings.add(recording);
      } on FormatException {
        rethrow;
      } on Object {
        throw const FormatException('Invalid athan catalogue fields');
      }
    }
    return AthanCatalogue._(recordings);
  }
}

/// Downloads are content-addressed and never replace another recording/revision.
/// Only a matching complete file is promoted out of .part and marked ready.
class AthanDownloads {
  AthanDownloads({
    required this.files,
    http.Client? client,
    this.timeout = const Duration(seconds: 90),
  }) : _client = client,
       _ownsClient = client == null;
  final FileStore files;
  final Duration timeout;
  http.Client? _client;
  final bool _ownsClient;
  final _availability = <StoreFile, AudioAvailability>{};
  final _pending = <StoreFile, Future<StoreFile>>{};
  final _aborts = <StoreFile, Completer<void>>{};
  bool _disposed = false;
  StoreFile fullFile(AthanRecording recording) {
    if (!RegExp(r'^[a-z][a-z0-9-]{0,63}$').hasMatch(recording.id) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(recording.sha256)) {
      throw const FormatException('Unsafe athan cache identity');
    }
    return StoreFile(
      StoreRoot.support,
      'athan/v1/${recording.id}/${recording.sha256}.m4a',
    );
  }

  AudioAvailability availabilityOf(AthanRecording recording) =>
      _availability[fullFile(recording)] ?? AudioAvailability.absent;
  Future<bool> _matches(AthanRecording recording, StoreFile file) async =>
      await files.length(file) == recording.expectedBytes &&
      (await sha256.bind(files.read(file)).first).toString() ==
          recording.sha256;
  Future<bool> verifyFull(AthanRecording recording) async {
    final file = fullFile(recording);
    if (_pending.containsKey(file)) return false;
    try {
      validateAthanDownload(recording);
      final valid = await _matches(recording, file);
      _availability[file] = valid
          ? AudioAvailability.verified
          : await files.length(file) == null
          ? AudioAvailability.absent
          : AudioAvailability.failed;
      return valid;
    } on Object {
      _availability[file] = AudioAvailability.failed;
      return false;
    }
  }

  Future<StoreFile> prepareFull(AthanRecording recording) {
    try {
      validateAthanDownload(recording);
    } on Object {
      return Future.error(
        const PrayerException(PrayerFailure.audioUnavailable),
      );
    }
    final file = fullFile(recording);
    final current = _pending[file];
    if (current != null) return current;
    final future = _prepare(recording, file);
    _pending[file] = future;
    return future.whenComplete(() => _pending.remove(file));
  }

  Future<StoreFile> _prepare(AthanRecording recording, StoreFile file) async {
    final abort = Completer<void>();
    Timer? deadline;
    try {
      if (_disposed) throw StateError('disposed');
      validateAthanDownload(recording);
      if (await _matches(recording, file)) {
        _availability[file] = AudioAvailability.verified;
        return file;
      }
      _availability[file] = AudioAvailability.downloading;
      await files.protect(StoreRoot.support, 'athan');
      await files.delete(file.part);
      _aborts[file] = abort;
      deadline = Timer(timeout, () {
        if (!abort.isCompleted) abort.complete();
      });
      final request = http.AbortableRequest(
        'GET',
        Uri.parse(recording.fullAssetUrl),
        abortTrigger: abort.future,
      )..followRedirects = false;
      final response = await (_client ??= http.Client())
          .send(request)
          .timeout(timeout);
      if (response.statusCode != 200 ||
          abort.isCompleted ||
          _disposed ||
          (response.contentLength != null &&
              response.contentLength != recording.expectedBytes)) {
        throw const FormatException('Audio response unavailable');
      }
      var received = 0;
      Stream<List<int>> bounded() async* {
        await for (final chunk in response.stream.timeout(timeout)) {
          if (abort.isCompleted || _disposed) throw StateError('cancelled');
          received += chunk.length;
          if (received > recording.expectedBytes) {
            throw const FormatException('Audio size mismatch');
          }
          yield chunk;
        }
      }

      await files.append(file.part, bounded());
      if (abort.isCompleted ||
          _disposed ||
          received != recording.expectedBytes ||
          !await _matches(recording, file.part)) {
        throw const FormatException('Audio integrity mismatch');
      }
      await files.rename(file.part, file);
      if (abort.isCompleted || _disposed || !await _matches(recording, file)) {
        throw StateError('Audio promotion unavailable');
      }
      _availability[file] = AudioAvailability.verified;
      return file;
    } on Object {
      _availability[file] = AudioAvailability.failed;
      try {
        await files.delete(file.part);
      } on Object {
        /* retry can clean this cache fragment */
      }
      throw const PrayerException(PrayerFailure.audioUnavailable);
    } finally {
      deadline?.cancel();
      if (!abort.isCompleted) abort.complete();
      _aborts.remove(file);
    }
  }

  void cancel(AthanRecording recording) {
    final abort = _aborts[fullFile(recording)];
    if (abort != null && !abort.isCompleted) abort.complete();
  }

  void dispose() {
    _disposed = true;
    for (final abort in _aborts.values) {
      if (!abort.isCompleted) abort.complete();
    }
    if (_ownsClient) _client?.close();
  }
}
