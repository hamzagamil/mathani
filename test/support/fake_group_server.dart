import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A small stand-in for /api/khatma (specs/014 contracts/group-api.md), enough for the app's
/// tests: start, read with ETag, take, release, read marks, leave, report, delete.
class FakeGroupServer {
  bool offline = false;
  int requests = 0;
  final khatmas = <String, _Khatma>{};
  final keysSeen = <String>[];
  int _next = 0;

  http.Client get client => MockClient((r) async {
        requests++;
        if (offline) throw http.ClientException('offline');
        final key = r.headers['X-Mathani-Key'];
        if (key != null) keysSeen.add(key);
        final path = r.url.path.replaceFirst('/api/khatma', '').split('/').where((s) => s.isNotEmpty).toList();
        final body = r.body.isEmpty ? <String, Object?>{} : (jsonDecode(r.body) as Map).cast<String, Object?>();
        return _handle(r.method, path, body, key, r.headers['If-None-Match']);
      });

  http.Response _json(int status, Object? body) =>
      http.Response(body == null ? '' : jsonEncode(body), status, headers: {'content-type': 'application/json'});

  /// Starts a khatma organised by [key] directly, as another device would.
  String seed({String title = 'Family', int division = 30, String key = 'organiser-key', String name = 'Amina'}) {
    final code = 'ABCD2345EFGH${(6789 + _next++).toString().padLeft(4, '0')}';
    final k = _Khatma(code, title, division, key);
    k.people['p0'] = (name: name, key: key);
    khatmas[code] = k;
    return code;
  }

  /// Takes part [n] for someone else.
  void takeAs(String code, int n, String key, String name) {
    final k = khatmas[code]!;
    final id = k.join(key, name);
    k.holder[n] = id;
    k.version++;
  }

  http.Response _handle(String method, List<String> path, Map<String, Object?> body, String? key, String? etag) {
    if (method == 'POST' && path.isEmpty) {
      final code = seed(title: body['title'] as String, division: body['division'] as int, key: key!, name: body['name'] as String);
      return _json(201, khatmas[code]!.snapshot(key));
    }
    final k = khatmas[path.first];
    if (k == null) return _json(404, {'error': 'gone'});
    if (method == 'GET') {
      if (etag == '"v${k.version}"') return _json(304, null);
      return _json(200, k.snapshot(key));
    }
    if (method == 'DELETE') {
      khatmas.remove(k.code);
      return _json(204, null);
    }
    final action = path.length > 3 ? path[3] : path[1];
    final n = path.length > 3 ? int.parse(path[2]) : 0;
    final me = k.idOf(key);
    switch (action) {
      case 'take':
        final id = me ?? k.join(key!, body['name'] as String? ?? '?');
        if (k.holder[n] != null || k.readAt[n] != null) {
          return _json(409, {'error': 'taken', 'snapshot': k.snapshot(key)});
        }
        k.holder[n] = id;
      case 'release':
        if (k.holder[n] != me && key != k.organiser) return _json(409, {'error': 'notYours', 'snapshot': k.snapshot(key)});
        k.holder[n] = null;
      case 'read':
        if (k.holder[n] != me && key != k.organiser) return _json(409, {'error': 'notYours', 'snapshot': k.snapshot(key)});
        k.readAt[n] = body['read'] == false ? null : 1000;
      case 'leave':
        k.holder.updateAll((_, v) => v == me ? null : v);
        k.people.remove(me);
        k.version++;
        return _json(204, null);
      case 'report':
        return _json(202, null);
      default:
        return _json(404, {'error': 'notFound'});
    }
    k.version++;
    return _json(200, k.snapshot(key));
  }
}

class _Khatma {
  _Khatma(this.code, this.title, this.division, this.organiser);
  final String code;
  final String title;
  final int division;
  final String organiser;
  int version = 1;
  final people = <String, ({String name, String key})>{};
  final holder = <int, String?>{};
  final readAt = <int, int?>{};
  int _ids = 1;

  String? idOf(String? key) {
    for (final e in people.entries) {
      if (e.value.key == key) return e.key;
    }
    return null;
  }

  String join(String key, String name) {
    final existing = idOf(key);
    if (existing != null) return existing;
    final id = 'p${_ids++}';
    people[id] = (name: name, key: key);
    return id;
  }

  Map<String, Object?> snapshot(String? key) {
    final parts = [
      for (var n = 1; n <= division; n++)
        {
          'n': n,
          'state': readAt[n] != null ? 'read' : holder[n] != null ? 'taken' : 'free',
          'holder': holder[n],
          'readAt': readAt[n],
        },
    ];
    final complete = parts.every((p) => p['state'] == 'read');
    return {
      'code': code,
      'title': title,
      'division': division,
      'finishDate': null,
      'version': version,
      'createdAt': 1,
      'completedAt': complete ? 2000 : null,
      'counts': {},
      'organiser': 'p0',
      'parts': parts,
      'participants': [
        for (final e in people.entries) {'id': e.key, 'name': e.value.name, 'typed': false},
      ],
      'you': {
        'id': idOf(key),
        'role': key == organiser ? 'organiser' : idOf(key) != null ? 'participant' : 'viewer',
      },
    };
  }
}
