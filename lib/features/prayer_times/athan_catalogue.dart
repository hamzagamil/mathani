import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../../platform/file_store.dart';
import 'prayer_models.dart';
import 'prayer_services.dart';

/// The recitations shipped with the app (`assets/prayer/athan_catalogue.json`). Empty until the
/// recordings' redistribution rights are cleared (research R10).
class AthanCatalogue {
  AthanCatalogue(List<AthanRecording> recordings)
    : recordings = List.unmodifiable(recordings);
  final List<AthanRecording> recordings;

  static Future<AthanCatalogue> load() async => AthanCatalogue.fromJson(
    Map<String, dynamic>.from(
      jsonDecode(
        await rootBundle.loadString('assets/prayer/athan_catalogue.json'),
      ) as Map,
    ),
  );

  factory AthanCatalogue.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 || json['recordings'] is! List) {
      throw const FormatException('Unsupported athan catalogue');
    }
    final recordings = [
      for (final raw in json['recordings'] as List)
        AthanRecording.fromJson(Map<String, dynamic>.from(raw as Map)),
    ];
    if (recordings.map((r) => r.id).toSet().length != recordings.length) {
      throw const FormatException('Duplicate athan recording');
    }
    return AthanCatalogue(recordings);
  }

  AthanRecording? byId(String id) =>
      recordings.where((r) => r.id == id).firstOrNull;

  /// The sound list: recitations, then the simple tone and silent (FR-019).
  List<String> get soundChoices => [
    for (final r in recordings) r.id,
    toneSound,
    silentSound,
  ];
}

/// Full recordings, downloaded on demand and checked by size and SHA-256 before use (FR-023).
class AthanDownloads extends ChangeNotifier {
  AthanDownloads({
    FileStore? files,
    http.Client? client,
    this.timeout = const Duration(seconds: 90),
  }) : files = files ?? fileStore(),
       _client = client,
       _ownsClient = client == null;
  final FileStore files;
  final Duration timeout;
  http.Client? _client;
  final bool _ownsClient;
  final _status = <String, DownloadStatus>{};
  final _progress = <String, double>{};
  final _pending = <String, Future<StoreFile>>{};
  bool _disposed = false;

  static const _dir = 'athan/v1';

  StoreFile fullFile(AthanRecording r) =>
      StoreFile(StoreRoot.support, '$_dir/${r.id}-${r.fullSha256}.m4a');

  DownloadStatus status(AthanRecording r) =>
      _status[r.id] ?? DownloadStatus.absent;

  /// 0..1 while downloading.
  double? progress(AthanRecording r) => _progress[r.id];

  void _set(AthanRecording r, DownloadStatus status, [double? progress]) {
    _status[r.id] = status;
    if (progress == null) {
      _progress.remove(r.id);
    } else {
      _progress[r.id] = progress;
    }
    if (!_disposed) notifyListeners();
  }

  Future<bool> _matches(AthanRecording r, StoreFile file) async =>
      await files.length(file) == r.fullBytes &&
      (await sha256.bind(files.read(file)).first).toString() == r.fullSha256;

  /// Checks a previous download without fetching anything.
  Future<bool> verify(AthanRecording r) async {
    if (_pending.containsKey(r.id)) return false;
    try {
      final ok = await _matches(r, fullFile(r));
      _set(r, ok ? DownloadStatus.ready : DownloadStatus.absent);
      return ok;
    } on Object {
      _set(r, DownloadStatus.absent);
      return false;
    }
  }

  /// The downloaded file's absolute path on phones, for the Android athan service.
  Future<String> localPath(AthanRecording r) async =>
      '${await files.locate(StoreRoot.support, _dir)}/'
      '${fullFile(r).path.substring(_dir.length + 1)}';

  Future<StoreFile> download(AthanRecording r) =>
      _pending[r.id] ??= _download(r).whenComplete(() => _pending.remove(r.id));

  Future<StoreFile> _download(AthanRecording r) async {
    final file = fullFile(r);
    try {
      if (await _matches(r, file)) {
        _set(r, DownloadStatus.ready);
        return file;
      }
      _set(r, DownloadStatus.downloading, 0);
      await files.protect(StoreRoot.support, _dir);
      await files.delete(file.part);
      final request = http.Request('GET', Uri.parse(r.fullUrl))
        ..followRedirects = false;
      final response = await (_client ??= http.Client())
          .send(request)
          .timeout(timeout);
      if (response.statusCode != 200 ||
          (response.contentLength != null &&
              response.contentLength != r.fullBytes)) {
        throw const FormatException('Audio response unavailable');
      }
      var received = 0;
      Stream<List<int>> bounded() async* {
        await for (final chunk in response.stream.timeout(timeout)) {
          if (_disposed) throw StateError('cancelled');
          received += chunk.length;
          if (received > r.fullBytes) {
            throw const FormatException('Audio size mismatch');
          }
          _set(r, DownloadStatus.downloading, received / r.fullBytes);
          yield chunk;
        }
      }

      await files.append(file.part, bounded());
      if (!await _matches(r, file.part)) {
        throw const FormatException('Audio integrity mismatch');
      }
      await files.rename(file.part, file);
      _set(r, DownloadStatus.ready);
      return file;
    } on Object {
      _set(r, DownloadStatus.failed);
      try {
        await files.delete(file.part);
      } on Object {
        /* a retry cleans it */
      }
      throw const PrayerException(PrayerFailure.audioUnavailable);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_ownsClient) _client?.close();
    super.dispose();
  }
}
