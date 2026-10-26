import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/quran_repository.dart';
import 'package:mathani/features/recitation/ayah_fetcher.dart';
import 'package:mathani/platform/file_store.dart';
import 'package:mathani/features/recitation/download_queue.dart';
import 'package:mathani/features/recitation/recited_item.dart';

import '../support/fake_audio_server.dart';
import '../support/harness.dart';
import '../support/memory_file_store.dart';
import '../support/temp_store.dart';

/// Per-surah downloads (specs/004 contracts/audio-storage.md › Downloads), against a local
/// server serving the real catalogue sizes. Never reaches EveryAyah.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late QuranRepository quran;
  late FakeAudioServer server;
  late Directory temp;
  var network = 'unmetered';

  AyahFetcher newFetcher() => AyahFetcher(
        recordingSize: (r, s, a) async => (await quran.recordingBytes(r, s))[a - 1],
        store: TempStore(temp).store,
      );

  DownloadQueue newQueue(AyahFetcher fetcher) => DownloadQueue(
        quran: quran,
        fetcher: fetcher,
        reciter: (id) => quran.reciter(id) == null ? null : server.reciter(id: id),
      );

  setUpAll(() async {
    quran = (await openTestReader()).quran;
  });

  setUp(() async {
    HttpOverrides.global = null; // the test binding blocks real HTTP; this server is local
    server = await FakeAudioServer.start();
    final sizes = <int, List<int>>{};
    for (var s = 1; s <= 114; s++) {
      sizes[s] = await quran.recordingBytes('husary', s);
    }
    server.sizes = (s, a) => sizes[s]![a - 1];
    temp = Directory.systemTemp.createTempSync('mathani_downloads');
    network = 'unmetered';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('app.mathani/device'),
      (call) async => switch (call.method) {
        'networkState' => network,
        'freeBytes' => 1 << 40,
        _ => null,
      },
    );
  });

  tearDown(() async {
    await server.close();
    temp.deleteSync(recursive: true);
  });

  Future<void> writeValid(StoreFile target, int bytes) async {
    final f = TempStore(temp).file(target);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(Uint8List(bytes));
  }

  /// Waits until [queue] has nothing queued or downloading.
  Future<void> idle(DownloadQueue queue) async {
    for (var i = 0; i < 400; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      final busy = queue.states.value.values.any(
          (d) => d.state == DownloadState.queued || d.state == DownloadState.downloading);
      if (!busy) return;
    }
    fail('the queue did not settle');
  }

  test('state from disk: absent, stopped (partial) and complete; the basmala counts', () async {
    final fetcher = newFetcher();
    final kawthar = await quran.recordingBytes('husary', 108);
    final basmala = (await quran.recordingBytes('husary', 1)).first;
    // Al-Kawthar: all ayat and the basmala → complete.
    for (var a = 1; a <= kawthar.length; a++) {
      await writeValid(await fetcher.downloadFile('husary', 108, a), kawthar[a - 1]);
    }
    await writeValid(await fetcher.basmalaFile('husary'), basmala);
    // Al-Ikhlas: ayah 1 only → stopped.
    final ikhlas = await quran.recordingBytes('husary', 112);
    await writeValid(await fetcher.downloadFile('husary', 112, 1), ikhlas[0]);
    // Al-Asr: a wrong-size file only → not counted.
    await writeValid(await fetcher.downloadFile('husary', 103, 1), 3);

    final queue = newQueue(fetcher);
    expect(queue.scanned.value, isFalse);
    await queue.ensureScanned();
    expect(queue.scanned.value, isTrue);
    expect(queue.stateOf('husary', 108)!.state, DownloadState.complete);
    expect(queue.stateOf('husary', 108)!.savedBytes, kawthar.fold(0, (a, b) => a + b) + basmala);
    expect(queue.stateOf('husary', 112)!.state, DownloadState.stopped);
    expect(queue.stateOf('husary', 112)!.savedBytes, ikhlas[0] + basmala);
    expect(queue.stateOf('husary', 103), isNull);
    // The shared basmala counts once in the reciter's total.
    expect(queue.savedBytes('husary'),
        kawthar.fold(0, (a, b) => a + b) + ikhlas[0] + basmala);
    queue.dispose();
    fetcher.dispose();
  });

  test('all ayat but no basmala is not complete, and resuming fetches only the basmala',
      () async {
    final fetcher = newFetcher();
    final ikhlas = await quran.recordingBytes('husary', 112);
    for (var a = 1; a <= ikhlas.length; a++) {
      await writeValid(await fetcher.downloadFile('husary', 112, a), ikhlas[a - 1]);
    }
    final queue = newQueue(fetcher);
    await queue.ensureScanned();
    expect(queue.stateOf('husary', 112)!.state, DownloadState.stopped);
    await queue.enqueue('husary', 112);
    await idle(queue);
    expect(server.requests, ['/primary/001001.mp3']);
    expect(queue.isComplete('husary', 112), isTrue);
    queue.dispose();
    fetcher.dispose();
  });

  test('a download fetches the basmala first, then the ayat in order, 2 at a time at most; '
      'a cached ayah is copied', () async {
    final fetcher = newFetcher();
    final mulk = await quran.recordingBytes('husary', 67);
    await writeValid(await fetcher.cacheFile('husary', 67, 2), mulk[1]); // heard recently
    server.delay = const Duration(milliseconds: 20);
    final queue = newQueue(fetcher);
    final sizeBefore = await queue.sizeOf('husary', 67);
    expect(sizeBefore, await quran.surahDownloadBytes('husary', 67));
    await queue.enqueue('husary', 67);
    await idle(queue);
    expect(queue.isComplete('husary', 67), isTrue);
    expect(server.requests.first, '/primary/001001.mp3');
    expect(server.requests, isNot(contains('/primary/067002.mp3')), reason: 'copied from cache');
    expect(server.requests.where((p) => p.startsWith('/primary/067')).length, mulk.length - 1);
    expect(server.maxInFlight, lessThanOrEqualTo(downloadConcurrency));
    expect(await queue.sizeOf('husary', 67), 0);
    // Enqueueing a complete surah does nothing.
    final before = server.requests.length;
    await queue.enqueue('husary', 67);
    await idle(queue);
    expect(server.requests.length, before);
    queue.dispose();
    fetcher.dispose();
  });

  test('losing the connection stops it; after a restart it resumes with only the missing files',
      () async {
    var fetcher = newFetcher();
    var queue = newQueue(fetcher);
    final mulk = await quran.recordingBytes('husary', 67);
    // Ayat 11+ fail on both hosts: the download stops part-way.
    for (var a = 11; a <= mulk.length; a++) {
      server.failPaths.addAll(['/primary/067${a.toString().padLeft(3, '0')}.mp3',
          '/mirror/067${a.toString().padLeft(3, '0')}.mp3']);
    }
    await queue.enqueue('husary', 67);
    await idle(queue);
    final stopped = queue.stateOf('husary', 67)!;
    expect(stopped.state, DownloadState.stopped);
    expect(stopped.stopReason, StopReason.fetchFailed);
    queue.dispose();
    fetcher.dispose();

    // Restart: a new queue finds it stopped (the queue itself is not persisted).
    fetcher = newFetcher();
    queue = newQueue(fetcher);
    await queue.ensureScanned();
    expect(queue.stateOf('husary', 67)!.state, DownloadState.stopped);
    final missing = [
      for (var a = 1; a <= mulk.length; a++)
        if (!await fetcher.isValid(await fetcher.downloadFile('husary', 67, a), mulk[a - 1])) a,
    ];
    server.failPaths.clear();
    server.requests.clear();
    await queue.enqueue('husary', 67);
    await idle(queue);
    expect(queue.isComplete('husary', 67), isTrue);
    expect(server.requests.length, lessThanOrEqualTo(missing.length + 1), reason: 'SC-011');
    queue.dispose();
    fetcher.dispose();
  });

  // Spec 008 US2 scenario 4: the browser (or the disk) has no room left.
  test('storage full: stopped for no storage, with no partly written file', () async {
    final store = MemoryFileStore()..failWithNoSpaceAfter = 0;
    final fetcher = AyahFetcher(
      recordingSize: (r, s, a) async => (await quran.recordingBytes(r, s))[a - 1],
      store: store,
    );
    final queue = newQueue(fetcher);
    await queue.enqueue('husary', 112);
    await idle(queue);
    final stopped = queue.stateOf('husary', 112);
    expect(stopped?.state ?? DownloadState.absent,
        anyOf(DownloadState.stopped, DownloadState.absent));
    if (stopped != null) expect(stopped.stopReason, StopReason.noStorage);
    final left = await store.list(StoreRoot.support, fetcher.downloadsRoot, recursive: true);
    expect(left.where((e) => !e.isDir), isEmpty, reason: 'no .part or partial file kept');
    expect(store.protected, ['support:recitations'], reason: 'asked to keep downloads (FR-014)');
    queue.dispose();
    fetcher.dispose();
  });

  test('offline: stopped with no connection', () async {
    final fetcher = newFetcher();
    final queue = newQueue(fetcher);
    network = 'none';
    await queue.enqueue('husary', 112);
    await idle(queue);
    expect(queue.stateOf('husary', 112)?.state ?? DownloadState.absent,
        anyOf(DownloadState.stopped, DownloadState.absent));
    expect(server.requests, isEmpty);
    queue.dispose();
    fetcher.dispose();
  });

  test('cancel keeps saved files; delete and delete-all remove them at once', () async {
    final fetcher = newFetcher();
    final queue = newQueue(fetcher);
    await queue.enqueue('husary', 112);
    await idle(queue);
    await queue.enqueue('husary', 108);
    await idle(queue);
    expect(queue.isComplete('husary', 112), isTrue);
    expect(queue.isComplete('husary', 108), isTrue);

    await queue.cancel('husary', 112); // nothing running: stays complete
    expect(queue.isComplete('husary', 112), isTrue);

    final delete = queue.delete('husary', 112);
    expect(queue.stateOf('husary', 112), isNull, reason: 'updates at once (SC-012)');
    await delete;
    expect(Directory('${temp.path}/support/${await fetcher.downloadDir('husary', 112)}').existsSync(),
        isFalse);
    expect(await fetcher.basmalaFile('husary').then((f) => TempStore(temp).file(f).existsSync()), isTrue,
        reason: 'the basmala is shared with other surahs');

    await queue.deleteAll('husary');
    expect(queue.states.value, isEmpty);
    expect(await fetcher.basmalaFile('husary').then((f) => TempStore(temp).file(f).existsSync()), isFalse);
    queue.dispose();
    fetcher.dispose();
  });

  test('a damaged file found at play time turns a complete surah back into stopped', () async {
    final fetcher = newFetcher();
    final queue = newQueue(fetcher);
    await queue.enqueue('husary', 112);
    await idle(queue);
    expect(queue.isComplete('husary', 112), isTrue);
    await TempStore(temp).file(await fetcher.downloadFile('husary', 112, 2)).writeAsBytes([1, 2, 3]);
    final reciter = server.reciter(id: 'husary');
    await fetcher.resolve(reciter, const RecitedItem.ayah(112, 2)); // streams it instead
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(queue.stateOf('husary', 112)!.state, DownloadState.stopped);
    queue.dispose();
    fetcher.dispose();
  });
}
