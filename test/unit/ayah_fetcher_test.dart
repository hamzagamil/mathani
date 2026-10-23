import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/recitation/ayah_fetcher.dart';
import 'package:mathani/features/recitation/recited_item.dart';

import '../support/fake_audio_server.dart';

/// AyahFetcher (specs/004 contracts/audio-storage.md › Resolve, Cache limit), against a
/// localhost server. Never reaches EveryAyah.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioServer server;
  late Directory temp;
  late AyahFetcher fetcher;
  late Reciter reciter;
  var network = 'unmetered';

  setUp(() async {
    HttpOverrides.global = null; // the test binding blocks real HTTP; this server is local
    server = await FakeAudioServer.start();
    temp = Directory.systemTemp.createTempSync('mathani_fetcher');
    reciter = server.reciter();
    network = 'unmetered';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('app.mathani/device'),
      (call) async => switch (call.method) {
        'networkState' => network,
        'freeBytes' => 1 << 40,
        _ => null,
      },
    );
    fetcher = AyahFetcher(
      recordingSize: (r, s, a) async => server.sizeOf(s, a),
      cacheRoot: () async => Directory('${temp.path}/cache'),
      supportRoot: () async => Directory('${temp.path}/support'),
    );
  });

  tearDown(() async {
    fetcher.dispose();
    await server.close();
    temp.deleteSync(recursive: true);
  });

  Future<File> writeSized(File f, int bytes) async {
    await f.parent.create(recursive: true);
    await f.writeAsBytes(Uint8List(bytes));
    return f;
  }

  test('1. a valid downloaded file wins over the cache and the network', () async {
    final downloaded = await writeSized(await fetcher.downloadFile('test', 67, 1), server.sizeOf(67, 1));
    await writeSized(await fetcher.cacheFile('test', 67, 1), server.sizeOf(67, 1));
    final f = await fetcher.resolve(reciter, const RecitedItem.ayah(67, 1));
    expect(f.path, downloaded.path);
    expect(server.requests, isEmpty);
  });

  test('2. a valid cache hit touches its time and makes no request', () async {
    final cached = await writeSized(await fetcher.cacheFile('test', 67, 2), server.sizeOf(67, 2));
    await cached.setLastModified(DateTime(2020));
    final f = await fetcher.resolve(reciter, const RecitedItem.ayah(67, 2));
    expect(f.path, cached.path);
    expect(server.requests, isEmpty);
    expect((await cached.lastModified()).year, greaterThan(2020));
  });

  test('3. a miss downloads through .part and renames', () async {
    final f = await fetcher.resolve(reciter, const RecitedItem.ayah(67, 3));
    expect(await f.length(), server.sizeOf(67, 3));
    expect(f.path, endsWith('067003.mp3'));
    expect(File('${f.path}.part').existsSync(), isFalse);
    expect(server.requests, ['/primary/067003.mp3']);
  });

  test('4. a size mismatch from the primary falls back to the mirror', () async {
    server.truncatePrimary = true;
    final f = await fetcher.resolve(reciter, const RecitedItem.ayah(67, 4));
    expect(await f.length(), server.sizeOf(67, 4));
    expect(server.requests, ['/primary/067004.mp3', '/mirror/067004.mp3']);
  });

  test('5. both hosts failing throws fetchFailed', () async {
    server.failAll = true;
    await expectLater(fetcher.resolve(reciter, const RecitedItem.ayah(67, 5)),
        throwsA(isA<FetchException>().having((e) => e.error, 'error', FetchError.fetchFailed)));
  });

  test('6. offline throws offline without a request', () async {
    network = 'none';
    await expectLater(fetcher.resolve(reciter, const RecitedItem.ayah(67, 6)),
        throwsA(isA<FetchException>().having((e) => e.error, 'error', FetchError.offline)));
    expect(server.requests, isEmpty);
  });

  test('7. two concurrent resolves of one file make one request', () async {
    final results = await Future.wait([
      fetcher.resolve(reciter, const RecitedItem.ayah(67, 7)),
      fetcher.resolve(reciter, const RecitedItem.ayah(67, 7)),
    ]);
    expect(results[0].path, results[1].path);
    expect(server.requests, hasLength(1));
  });

  test('8. the cache is trimmed past 100 MB to 90 MB, oldest first, keeping protected files',
      () async {
    const mb = 1024 * 1024;
    final old = <File>[];
    for (var i = 0; i < 11; i++) {
      final f = await writeSized(File('${temp.path}/cache/recitations/test/900${i}00.mp3'), 10 * mb);
      await f.setLastModified(DateTime(2020, 1, 1 + i));
      old.add(f);
    }
    fetcher.protect([old[0].path]); // the oldest, but in use
    await fetcher.resolve(reciter, const RecitedItem.ayah(67, 8)); // triggers the trim
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(old[0].existsSync(), isTrue);
    expect(old[1].existsSync(), isFalse);
    expect(old[2].existsSync(), isFalse);
    expect(await fetcher.cacheBytes(), lessThanOrEqualTo(cacheTrimToBytes));
  });

  test('9. clearCache keeps protected files and reports the bytes freed', () async {
    final keep = await writeSized(await fetcher.cacheFile('test', 1, 1), 100);
    await writeSized(await fetcher.cacheFile('test', 1, 2), 300);
    fetcher.protect([keep.path]);
    expect(await fetcher.clearCache(), 300);
    expect(keep.existsSync(), isTrue);
    expect(await fetcher.cacheBytes(), 100);
  });

  test('10. init deletes stale .part files', () async {
    final stale = await writeSized(File('${temp.path}/support/recitations/test/067/001.mp3.part'), 5);
    await fetcher.init();
    expect(stale.existsSync(), isFalse);
  });

  test('11. a wrong-size downloaded file is deleted, reported, and not returned', () async {
    final bad = await writeSized(await fetcher.downloadFile('test', 67, 11), 3);
    final damaged = fetcher.onDamaged.first;
    final f = await fetcher.resolve(reciter, const RecitedItem.ayah(67, 11));
    expect(f.path, isNot(bad.path));
    expect(bad.existsSync(), isFalse);
    expect(await damaged, ('test', 67));
  });

  test('12. requests carry no cookies or identifying headers (FR-023)', () async {
    await fetcher.resolve(reciter, const RecitedItem.ayah(67, 12));
    final headers = server.lastHeaders!;
    expect(headers.value(HttpHeaders.cookieHeader), isNull);
    expect(headers.value(HttpHeaders.authorizationHeader), isNull);
    final names = <String>[];
    headers.forEach((name, _) => names.add(name.toLowerCase()));
    expect(names.toSet().difference(
        {'user-agent', 'accept-encoding', 'host', 'content-length'}), isEmpty);
  });

  test('a basmala resolves the reciter\'s 1:1', () async {
    final f = await fetcher.resolve(reciter, const RecitedItem.basmala(67));
    expect(await f.length(), server.sizeOf(1, 1));
    expect(server.requests, ['/primary/001001.mp3']);
  });
}
