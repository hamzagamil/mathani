// The group khatma client with a fake HTTP client (specs/014 contracts/group-api.md).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mathani/features/khatma/group/group_client.dart';
import 'package:mathani/features/khatma/group/group_key.dart';
import 'package:mathani/features/khatma/group/group_models.dart';

Map<String, Object?> snapshotJson({int version = 3, String? holder}) => {
      'code': 'ABCD2345EFGH6789',
      'title': 'Family',
      'division': 30,
      'finishDate': null,
      'version': version,
      'createdAt': 1,
      'completedAt': null,
      'counts': {'free': 29, 'taken': holder == null ? 0 : 1, 'read': 0},
      'organiser': 'p1',
      'parts': [
        for (var n = 1; n <= 30; n++)
          {'n': n, 'state': n == 7 && holder != null ? 'taken' : 'free', 'holder': n == 7 ? holder : null, 'readAt': null},
      ],
      'participants': [
        {'id': 'p1', 'name': 'Amina', 'typed': false},
        if (holder != null) {'id': holder, 'name': 'Maryam', 'typed': false},
      ],
      'you': {'id': holder, 'role': holder == null ? 'viewer' : 'participant'},
    };

void main() {
  late List<http.Request> sent;
  late KeyStore keys;

  GroupClient client(http.Response Function(http.Request) answer) {
    sent = [];
    keys = MemoryKeyStore();
    return GroupClient(
      base: Uri.parse('https://get.mthani.app'),
      keys: keys,
      client: MockClient((r) async {
        sent.add(r);
        return answer(r);
      }),
    );
  }

  test('a read sends no key before one exists, and its version when it has one', () async {
    final c = client((_) => http.Response(jsonEncode(snapshotJson()), 200));
    final s = await c.read('ABCD2345EFGH6789', version: 2);
    expect(s.title, 'Family');
    expect(s.parts, hasLength(30));
    expect(sent.single.url.path, '/api/khatma/ABCD2345EFGH6789');
    expect(sent.single.headers['If-None-Match'], '"v2"');
    expect(sent.single.headers.containsKey('X-Mathani-Key'), isFalse, reason: 'FR-065');
    expect(await keys.read(), isNull);
  });

  test('304 is notModified', () async {
    final c = client((_) => http.Response('', 304));
    expect(() => c.read('ABCD2345EFGH6789', version: 3),
        throwsA(isA<GroupFailure>().having((f) => f.kind, 'kind', GroupFailureKind.notModified)));
  });

  test('a take makes the key and sends it, with the name and terms', () async {
    final c = client((_) => http.Response(jsonEncode(snapshotJson(holder: 'p2')), 200));
    final s = await c.take('ABCD2345EFGH6789', 7, name: 'Maryam', terms: 1);
    expect(s.mine.single.n, 7);
    final r = sent.single;
    expect(r.method, 'POST');
    expect(r.url.path, '/api/khatma/ABCD2345EFGH6789/parts/7/take');
    expect(r.headers['X-Mathani-Key'], await keys.read());
    expect(jsonDecode(r.body), {'name': 'Maryam', 'terms': 1});
  });

  test('409 taken comes with the fresh snapshot', () async {
    final c = client((_) => http.Response(
        jsonEncode({'error': 'taken', 'snapshot': snapshotJson(holder: 'p9')}), 409));
    try {
      await c.take('ABCD2345EFGH6789', 7);
      fail('no failure');
    } on GroupFailure catch (f) {
      expect(f.kind, GroupFailureKind.taken);
      expect(f.snapshot!.parts[6].state, PartState.taken);
    }
  });

  test('errors map to kinds: gone, blocked, invalid, limit, terms', () async {
    Future<GroupFailure> failure(int status, Map<String, Object?> body) async {
      final c = client((_) => http.Response(jsonEncode(body), status));
      try {
        await c.start(title: 'T', name: 'N', division: 30, terms: 1);
      } on GroupFailure catch (f) {
        return f;
      }
      throw StateError('no failure');
    }

    expect((await failure(404, {'error': 'gone'})).kind, GroupFailureKind.gone);
    expect((await failure(403, {'error': 'blocked'})).kind, GroupFailureKind.blocked);
    final invalid = await failure(422, {'error': 'invalid', 'problem': {'field': 'name', 'kind': 'word'}});
    expect((invalid.kind, invalid.problem!.kind), (GroupFailureKind.invalid, 'word'));
    final limit = await failure(429, {'error': 'limit', 'which': 'organised'});
    expect((limit.kind, limit.which), (GroupFailureKind.limit, 'organised'));
    final terms = await failure(422, {'error': 'terms', 'current': 2});
    expect((terms.kind, terms.terms), (GroupFailureKind.terms, 2));
  });

  test('no connection is offline', () async {
    final c = GroupClient(
      base: Uri.parse('https://get.mthani.app'),
      keys: MemoryKeyStore(),
      client: MockClient((_) async => throw http.ClientException('no network')),
    );
    expect(() => c.read('ABCD2345EFGH6789'),
        throwsA(isA<GroupFailure>().having((f) => f.kind, 'kind', GroupFailureKind.offline)));
  });
}
