import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/recitation/ayah_fetcher.dart';
import 'package:mathani/features/recitation/recited_item.dart';

import '../support/fake_audio_server.dart';
import '../support/temp_store.dart';

/// Ayah clips of reciters recorded one surah per file (specs/006 T012, research R18): each ayah is
/// fetched as an exact byte range of its surah file, and anything but that range is refused.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAudioServer server;
  late Directory temp;
  late TempStore files;
  late AyahFetcher fetcher;
  late Reciter reciter;

  /// Al-Ikhlas (4 ayat) split after a 100-byte tag: the clips cover the rest of the file.
  const rangeStart = 100;
  List<int> sizes(int total) {
    final rest = total - rangeStart;
    return [rest ~/ 4, rest ~/ 4, rest ~/ 4, rest - 3 * (rest ~/ 4)];
  }

  setUp(() async {
    HttpOverrides.global = null;
    server = await FakeAudioServer.start();
    temp = Directory.systemTemp.createTempSync('mathani_fetcher_range');
    reciter = server.surahReciter();
    files = TempStore(temp);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('app.mathani/device'),
      (call) async => switch (call.method) {
        'networkState' => 'unmetered',
        'freeBytes' => 1 << 40,
        _ => null,
      },
    );
    fetcher = AyahFetcher(
      recordingSize: (r, s, a) async => sizes(server.surahFileBytes(s))[a - 1],
      clipRange: (r, s, a) async {
        final total = server.surahFileBytes(s);
        final list = sizes(total);
        var start = rangeStart;
        for (var i = 1; i < a; i++) {
          start += list[i - 1];
        }
        return (start: start, end: start + list[a - 1], total: total);
      },
      store: files.store,
    );
  });

  tearDown(() async {
    fetcher.dispose();
    await server.close();
    temp.deleteSync(recursive: true);
  });

  test('an ayah is the exact byte range of its surah file', () async {
    final total = server.surahFileBytes(112);
    final list = sizes(total);
    final f = files.file(await fetcher.resolve(reciter, const RecitedItem.ayah(112, 3)));
    final start = rangeStart + list[0] + list[1];
    expect(f.path, endsWith('surahs/112003.mp3'));
    final bytes = await f.readAsBytes();
    expect(bytes.length, list[2]);
    expect(bytes.first, start % 251, reason: 'the clip starts at its offset in the file');
    expect(bytes.last, (start + list[2] - 1) % 251);
    expect(server.requests, ['/surah/112.mp3']);
    expect(server.lastHeaders!.value(HttpHeaders.rangeHeader),
        'bytes=$start-${start + list[2] - 1}');
  });

  test('a 200 with the whole file is refused, and never saved', () async {
    server.ignoreRange = true;
    await expectLater(fetcher.resolve(reciter, const RecitedItem.ayah(112, 2)),
        throwsA(isA<FetchException>()));
    expect(files.file(await fetcher.cacheFile(reciter.id, 112, 2)).existsSync(), isFalse);
    expect(server.requests.every((p) => p == '/surah/112.mp3'), isTrue,
        reason: 'no mirror is tried for a reciter without one');
  });

  test('a shifted range or a different file length is refused', () async {
    server.shiftRange = 1;
    await expectLater(fetcher.resolve(reciter, const RecitedItem.ayah(112, 2)),
        throwsA(isA<FetchException>()));
    server
      ..shiftRange = 0
      ..wrongTotal = 1;
    await expectLater(fetcher.resolve(reciter, const RecitedItem.ayah(112, 2)),
        throwsA(isA<FetchException>()));
    expect(files.file(await fetcher.cacheFile(reciter.id, 112, 2)).existsSync(), isFalse);
    server.wrongTotal = null;
    final f = files.file(await fetcher.resolve(reciter, const RecitedItem.ayah(112, 2)));
    expect(await f.length(), sizes(server.surahFileBytes(112))[1]);
  });

  // Browsers hide Content-Range from everyayah.com and quranicaudio.com (specs/008 R18a).
  test('without Content-Range, a clip of exactly the range length is accepted', () async {
    server.hideContentRange = true;
    final f = files.file(await fetcher.resolve(reciter, const RecitedItem.ayah(112, 1)));
    expect(await f.length(), sizes(server.surahFileBytes(112))[0]);
  });

  test('without Content-Range, a clip of another length is refused', () async {
    server
      ..hideContentRange = true
      ..extraBytes = 1;
    await expectLater(fetcher.resolve(reciter, const RecitedItem.ayah(112, 1)),
        throwsA(isA<FetchException>()));
    expect(files.file(await fetcher.cacheFile(reciter.id, 112, 1)).existsSync(), isFalse);
  });
}
