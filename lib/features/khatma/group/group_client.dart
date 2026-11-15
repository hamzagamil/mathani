import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'group_key.dart';
import 'group_models.dart';

/// Why a call did not give a snapshot (contracts/group-api.md › Every request, Endpoints).
enum GroupFailureKind {
  /// No connection, or the server could not be reached.
  offline,
  notModified,
  gone,
  blocked,
  organiser,
  removed,
  taken,
  notYours,
  read,
  complete,
  invalid,
  terms,
  limit,
  key,
  origin,
  other,
}

class GroupFailure implements Exception {
  const GroupFailure(this.kind, {this.snapshot, this.problem, this.which, this.terms});
  final GroupFailureKind kind;

  /// The fresh state sent with a 409.
  final Snapshot? snapshot;
  final Problem? problem;

  /// For a limit: organised, started, busy or reports.
  final String? which;

  /// For terms: the current version.
  final int? terms;

  @override
  String toString() => 'GroupFailure(${kind.name})';
}

/// The group khatma API (specs/014 contracts/group-api.md): one method per endpoint, returning a
/// snapshot or throwing a [GroupFailure]. It sends the key on writes, and on reads once a key
/// exists. The HTTP client is a parameter, so tests pass a fake.
class GroupClient {
  GroupClient({required this.base, required this.keys, http.Client? client, this.timeout = const Duration(seconds: 10)})
      : _http = client ?? http.Client();

  final Uri base;
  final KeyStore keys;
  final http.Client _http;
  final Duration timeout;

  Uri _uri(String path) => base.replace(path: '/api/khatma$path');

  Future<Map<String, String>> _headers({required bool write}) async {
    final key = write ? await keys.create() : await keys.read();
    return {
      'X-Mathani-Key': ?key,
      if (write) 'Content-Type': 'application/json',
    };
  }

  Future<http.Response> _send(String method, String path, {Object? body, Map<String, String>? extra}) async {
    final write = method != 'GET';
    final headers = {...await _headers(write: write), ...?extra};
    final request = http.Request(method, _uri(path))..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    try {
      return await http.Response.fromStream(await _http.send(request).timeout(timeout));
    } on TimeoutException {
      throw const GroupFailure(GroupFailureKind.offline);
    } on http.ClientException {
      throw const GroupFailure(GroupFailureKind.offline);
    } on Exception catch (e) {
      // SocketException and HandshakeException on phones; no dart:io here for the web.
      if ('$e'.contains('Socket') || '$e'.contains('Handshake') || '$e'.contains('XMLHttpRequest')) {
        throw const GroupFailure(GroupFailureKind.offline);
      }
      rethrow;
    }
  }

  Snapshot? _snapshotIn(Object? json) =>
      json is Map && json['snapshot'] is Map ? Snapshot.fromJson((json['snapshot'] as Map).cast()) : null;

  Never _fail(http.Response r) {
    Object? json;
    try {
      json = r.body.isEmpty ? null : jsonDecode(r.body);
    } on FormatException {
      json = null;
    }
    final error = json is Map ? json['error'] as String? : null;
    final kind = switch ((r.statusCode, error)) {
      (304, _) => GroupFailureKind.notModified,
      (404, 'gone') => GroupFailureKind.gone,
      (401, _) => GroupFailureKind.key,
      (403, 'blocked') => GroupFailureKind.blocked,
      (403, 'organiser') => GroupFailureKind.organiser,
      (403, 'removed') => GroupFailureKind.removed,
      (403, 'origin') => GroupFailureKind.origin,
      (409, 'taken') => GroupFailureKind.taken,
      (409, 'notYours') => GroupFailureKind.notYours,
      (409, 'read') => GroupFailureKind.read,
      (409, 'complete') => GroupFailureKind.complete,
      (409, 'organiser') => GroupFailureKind.organiser,
      (422, 'terms') => GroupFailureKind.terms,
      (422, _) => GroupFailureKind.invalid,
      (429, _) => GroupFailureKind.limit,
      (>= 500, _) => GroupFailureKind.offline,
      _ => GroupFailureKind.other,
    };
    final problem = json is Map && json['problem'] is Map
        ? Problem('${(json['problem'] as Map)['field']}', '${(json['problem'] as Map)['kind']}')
        : null;
    throw GroupFailure(
      kind,
      snapshot: _snapshotIn(json),
      problem: problem,
      which: json is Map ? json['which'] as String? : null,
      terms: json is Map ? json['current'] as int? : null,
    );
  }

  Snapshot _snapshot(http.Response r, {int ok = 200}) {
    if (r.statusCode != ok) _fail(r);
    return Snapshot.fromJson((jsonDecode(r.body) as Map).cast());
  }

  Future<Snapshot> start({
    required String title,
    required String name,
    required int division,
    String? finishDate,
    required int terms,
  }) async =>
      _snapshot(
          await _send('POST', '', body: {
            'title': title,
            'name': name,
            'division': division,
            'finishDate': finishDate,
            'terms': terms,
          }),
          ok: 201);

  /// The khatma's state; throws [GroupFailureKind.notModified] when it is still [version].
  Future<Snapshot> read(String code, {int? version}) async => _snapshot(await _send('GET', '/$code',
      extra: version == null ? null : {'If-None-Match': '"v$version"'}));

  Future<Snapshot> take(String code, int n, {String? name, int? terms}) async =>
      _snapshot(await _send('POST', '/$code/parts/$n/take', body: {'name': ?name, 'terms': ?terms}));

  Future<Snapshot> release(String code, int n) async =>
      _snapshot(await _send('POST', '/$code/parts/$n/release'));

  Future<Snapshot> markRead(String code, int n, {required bool read}) async =>
      _snapshot(await _send('POST', '/$code/parts/$n/read', body: {'read': read}));

  Future<Snapshot> assign(String code, int n, String name) async =>
      _snapshot(await _send('POST', '/$code/parts/$n/assign', body: {'name': name}));

  Future<void> leave(String code) async {
    final r = await _send('POST', '/$code/leave');
    if (r.statusCode != 204) _fail(r);
  }

  Future<Snapshot> removeParticipant(String code, String id) async =>
      _snapshot(await _send('POST', '/$code/participants/$id/remove'));

  Future<Snapshot> edit(String code, {String? title, String? Function()? finishDate}) async =>
      _snapshot(await _send('PATCH', '/$code', body: {
        'title': ?title,
        if (finishDate != null) 'finishDate': finishDate(),
      }));

  Future<void> delete(String code) async {
    final r = await _send('DELETE', '/$code');
    if (r.statusCode != 204) _fail(r);
  }

  /// Reports a participant's name, or the whole khatma when [participant] is null (FR-061).
  Future<void> report(String code, {String? participant}) async {
    final r = await _send('POST', '/$code/report', body: {'participant': ?participant});
    if (r.statusCode != 202) _fail(r);
  }
}
