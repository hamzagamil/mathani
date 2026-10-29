import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mathani/features/prayer_times/athan_catalogue.dart';
import 'package:mathani/features/prayer_times/athan_player.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_services.dart';

import '../../support/memory_file_store.dart';
import '../../support/prayer_reminder_fixtures.dart';

class Port implements AthanPlaybackPort {
  final log = <String>[];
  Completer<void>? loadGate;
  final loading = Completer<void>();
  bool reject = false;
  @override
  Future<void> load(Uri uri, {Duration? start, Duration? end}) async {
    log.add('load');
    if (!loading.isCompleted) loading.complete();
    await loadGate?.future;
  }

  @override
  Future<void> play() async {
    if (reject) throw StateError('autoplay blocked');
    log.add('play');
  }

  @override
  Future<void> stop() async {
    log.add('stop');
  }
}

class BrokenClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream<List<int>>.multi((c) {
          c.add([1, 2]);
          c.addError(StateError('interrupted'));
          c.close();
        }),
        200,
      );
}

void main() {
  test('only hash/size verified downloads are promoted and corrupt data never looks ready', () async {
    final store = MemoryFileStore();
    var calls = 0;
    final downloads = AthanDownloads(
      files: store,
      client: MockClient((_) async {
        calls++;
        return http.Response.bytes([1, 2, 3, 4], 200);
      }),
    );
    final file = await downloads.prepareFull(fixtureAthan);
    expect(store.bytesOf(file), [1, 2, 3, 4]);
    expect(store.exists(file.part), isFalse);
    expect(downloads.availabilityOf(fixtureAthan), AudioAvailability.verified);
    await downloads.prepareFull(fixtureAthan);
    expect(calls, 1);
    store.put(file, [5, 6, 7, 8]);
    expect(await downloads.verifyFull(fixtureAthan), isFalse);
    expect(downloads.availabilityOf(fixtureAthan), AudioAvailability.failed);
  });
  test('interrupted, wrong hash, oversized and redirected downloads leave no final or partial file', () async {
    for (final client in <http.Client>[
      BrokenClient(),
      MockClient((_) async => http.Response.bytes([4, 3, 2, 1], 200)),
      MockClient((_) async => http.Response.bytes([1, 2, 3, 4, 5], 200)),
      MockClient(
        (_) async => http.Response(
          '',
          302,
          headers: {'location': 'https://unapproved.example/file'},
        ),
      ),
    ]) {
      final store = MemoryFileStore();
      final subject = AthanDownloads(files: store, client: client);
      await expectLater(
        subject.prepareFull(fixtureAthan),
        throwsA(isA<PrayerException>()),
      );
      expect(store.exists(subject.fullFile(fixtureAthan)), isFalse);
      expect(store.exists(subject.fullFile(fixtureAthan).part), isFalse);
      expect(subject.availabilityOf(fixtureAthan), AudioAvailability.failed);
      subject.dispose();
    }
  });
  test('Stop invalidates a pending load and playback pauses both owners without automatic resume', () async {
    final store = MemoryFileStore(),
        port = Port()..loadGate = Completer<void>();
    final downloads = AthanDownloads(files: store);
    store.put(downloads.fullFile(fixtureAthan), [1, 2, 3, 4]);
    final player = AthanPlayer(
      downloads: downloads,
      playback: port,
      recordings: [fixtureAthan],
      pauseQuran: () async {
        port.log.add('pauseQuran');
      },
      pauseMemorization: () async {
        port.log.add('pauseMemorization');
      },
    );
    final pending = player.preview(fixtureAthan);
    await port.loading.future;
    await player.stop();
    port.loadGate!.complete();
    await pending;
    expect(
      port.log,
      containsAllInOrder(['pauseMemorization', 'pauseQuran', 'load', 'stop']),
    );
    expect(port.log, isNot(contains('play')));
    port.loadGate = null;
    await player.preview(fixtureAthan);
    await player.preview(fixtureAthan);
    expect(port.log.where((s) => s == 'play'), hasLength(2));
    expect(port.log.where((s) => s.contains('resume')), isEmpty);
    await player.stop();
    downloads.dispose();
  });
  test('rejected browser autoplay is recoverable and duplicate/stale scheduled commands are no-ops', () async {
    final store = MemoryFileStore(), port = Port();
    final downloads = AthanDownloads(files: store);
    store.put(downloads.fullFile(fixtureAthan), [1, 2, 3, 4]);
    var current = true, claims = 0;
    final player = AthanPlayer(
      downloads: downloads,
      playback: port,
      recordings: [fixtureAthan],
      pauseQuran: () async {},
      pauseMemorization: () async {},
      isCurrent: (_) => current,
      claimStart: (_) async {
        claims++;
        return true;
      },
    );
    final now = DateTime.utc(2026);
    final event = ScheduledReminder(
      eventId: 'event',
      locationId: 'opaque',
      generation: 1,
      kind: PrayerKind.fajr,
      dueAtUtc: now,
      expiresAtUtc: now.add(const Duration(seconds: 60)),
      audioId: 'fixture',
      mode: AthanMode.opening,
      deliveryMechanism: 'appAudio',
    );
    await player.play(event);
    await player.play(event);
    expect(claims, 1);
    expect(port.log.where((s) => s == 'play'), hasLength(1));
    current = false;
    final before = List.of(port.log);
    await player.play(event);
    expect(port.log, before);
    port.reject = true;
    await expectLater(
      player.preview(fixtureAthan),
      throwsA(isA<PrayerException>()),
    );
    port.reject = false;
    await player.playFromUser(fixtureAthan, AthanMode.full);
    expect(port.log.where((s) => s == 'play'), hasLength(2));
    expect(claims, 1, reason: 'User Play does not replay a scheduled token');
    await player.stop();
    downloads.dispose();
  });
  test('unreviewed recordings stay out of the usable catalogue', () {
    final catalogue = AthanCatalogue.fromJson({
      'schemaVersion': 1,
      'recordings': [
        {'id': 'unreviewed', 'completeRecordingReviewed': false},
      ],
    });
    expect(catalogue.recordings, isEmpty);
    expect(
      () => AthanCatalogue.fromJson({'schemaVersion': 99, 'recordings': []}),
      throwsFormatException,
    );
  });
}
