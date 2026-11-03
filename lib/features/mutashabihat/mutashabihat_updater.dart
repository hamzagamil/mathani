import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../platform/api_base.dart';
import '../../platform/file_store.dart';
import '../../shared/reader_state.dart';
import 'mutashabihat_content.dart';
import 'mutashabihat_loader.dart';

/// Fetches newly published Mutashabihat content and uses it without a store release (specs/011
/// research R5, contracts/content-api.md). Runs after the first frame and on resume, at most
/// every [interval]; a download is used only when it is complete, checked and newer.
class MutashabihatUpdater {
  MutashabihatUpdater({
    required this.reader,
    this._client,
    this._store,
    DateTime Function()? now,
    this._base,
  }) : _now = now ?? DateTime.now;

  static const interval = Duration(hours: 6);
  static const timeout = Duration(seconds: 10);

  /// The content format this app understands.
  static const supportedFormat = '1';

  final ReaderController reader;
  final http.Client? _client;
  final FileStore? _store;
  final DateTime Function() _now;
  final Uri? _base;
  bool _running = false;

  FileStore get _files => _store ?? fileStore();

  /// Checks for a newer version, unless one check is running or the last was within [interval].
  /// Never throws: problems are logged and the current content stays.
  Future<void> check() async {
    if (_running) return;
    _running = true;
    try {
      await _check();
    } catch (e) {
      debugPrint('Mutashabihat update check failed: $e');
    } finally {
      _running = false;
    }
  }

  Future<void> _check() async {
    final meta = await _readMeta();
    final last = meta['checkedAt'];
    final now = _now().millisecondsSinceEpoch;
    if (last is int && now - last < interval.inMilliseconds) return;

    final current = reader.similar.version;
    final client = _client ?? http.Client();
    final http.Response response;
    try {
      response = await client
          .get((_base ?? apiBase()).resolve('/api/mutashabihat'),
              headers: {if (current > 0) 'If-None-Match': '"v$current"'})
          .timeout(timeout);
    } finally {
      if (_client == null) client.close();
    }
    // Storage trouble on the server: try again on the next resume.
    if (response.statusCode >= 500) return;

    final next = response.statusCode == 200 ? _accept(response, current) : null;
    if (next != null) {
      await _save(response.bodyBytes, next, response.headers['x-content-sha256']!, now);
      reader.replaceSimilar(next);
    } else {
      await _writeMeta({...meta, 'checkedAt': now});
    }
  }

  /// The downloaded content, or null when any check fails (FR-014).
  Mutashabihat? _accept(http.Response response, int current) {
    final format = response.headers['x-content-format'];
    final version = int.tryParse(response.headers['x-content-version'] ?? '');
    final sha = response.headers['x-content-sha256'];
    if (format != supportedFormat || version == null || version <= current || sha == null) return null;
    if (sha256.convert(response.bodyBytes).toString() != sha) return null;
    final (content, problems) = parseMutashabihat(utf8.decode(response.bodyBytes));
    if (content.version != version || content.groups.isEmpty || problems.any((p) => p.isError)) return null;
    return content;
  }

  /// Writes the file as `.part`, then renames it, so a cut-off write is never read.
  Future<void> _save(List<int> bytes, Mutashabihat content, String sha, int now) async {
    final files = _files;
    final part = downloadedContent.part;
    await files.delete(part);
    await files.append(part, Stream.value(bytes));
    await files.rename(part, downloadedContent);
    await _writeMeta({'version': content.version, 'sha256': sha, 'checkedAt': now});
  }

  Future<Map<String, dynamic>> _readMeta() async {
    try {
      if (await _files.length(downloadedMeta) == null) return {};
      return jsonDecode(await utf8.decoder.bind(_files.read(downloadedMeta)).join()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeMeta(Map<String, dynamic> meta) async {
    final files = _files;
    await files.delete(downloadedMeta);
    await files.append(downloadedMeta, Stream.value(utf8.encode(jsonEncode(meta))));
  }
}
