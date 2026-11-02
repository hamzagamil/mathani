import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/prayer_times/athan_catalogue.dart';
import 'package:mathani/features/prayer_times/athan_player.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';

import '../../support/prayer_fakes.dart';

void main() {
  final recording = AthanRecording.fromJson({
    'id': 'sample',
    'nameAr': 'أذان',
    'nameEn': 'Athan',
    'reciter': 'Reciter',
    'openingEndMs': 12000,
    'fullUrl': 'https://get.mthani.app/athan/v1/sample.m4a',
    'fullSha256': 'a' * 64,
    'fullBytes': 1000,
    'fullDurationMs': 120000,
    'source': 'https://example.org/source',
    'licence': 'CC-BY-4.0',
    'attribution': 'Recorded by Reciter',
  });

  late FakePort port;
  late AthanPlayer player;
  var quran = 0, memorization = 0;
  setUp(() {
    port = FakePort();
    quran = memorization = 0;
    player = AthanPlayer(
      catalogue: AthanCatalogue([recording]),
      downloads: AthanDownloads(files: NoFiles()),
      pauseQuran: () => quran++,
      pauseMemorization: () => memorization++,
      port: port,
    );
  });

  test('one preview at a time: a second stops the first (FR-019)', () async {
    final first = player.preview(toneSound);
    await Future<void>.delayed(Duration.zero);
    expect(player.playing.value, toneSound);
    final second = player.preview('sample');
    await Future<void>.delayed(Duration.zero);
    await first;
    expect(port.stops, greaterThanOrEqualTo(1));
    expect(player.playing.value, 'sample');
    // Not downloaded: the hosted file, cut after the opening takbirat.
    expect(port.played.last.uri.toString(), recording.fullUrl);
    expect(port.played.last.end, const Duration(milliseconds: 12000));
    await player.stop();
    await second;
    expect(player.playing.value, isNull);
  });

  test('Quran and memorization pause before any athan, never resumed '
      '(FR-026)', () async {
    final full = player.playFull(recording);
    await Future<void>.delayed(Duration.zero);
    expect(quran, 1);
    expect(memorization, 1);
    expect(port.played.single.end, isNull);
    await player.stop();
    await full;
    expect(quran, 1);
  });

  test('silent plays nothing and pauses nothing', () async {
    await player.preview(silentSound);
    expect(port.played, isEmpty);
    expect(quran, 0);
  });

  test('the catalogue rejects clips of 30 s or more and foreign hosts', () {
    Map<String, dynamic> raw(Map<String, Object> change) => {
      'id': 'x',
      'nameAr': 'x',
      'nameEn': 'x',
      'reciter': 'x',
      'openingEndMs': 12000,
      'fullUrl': 'https://get.mthani.app/athan/v1/x.m4a',
      'fullSha256': 'b' * 64,
      'fullBytes': 10,
      'fullDurationMs': 100000,
      'source': 's',
      'licence': 'l',
      'attribution': 'a',
      ...change,
    };
    expect(AthanRecording.fromJson(raw({})).id, 'x');
    expect(
      () => AthanRecording.fromJson(raw({'openingEndMs': 30000})),
      throwsFormatException,
    );
    expect(
      () => AthanRecording.fromJson(
        raw({'fullUrl': 'https://evil.example/x.m4a'}),
      ),
      throwsFormatException,
    );
    expect(
      AthanCatalogue.fromJson({'version': 1, 'recordings': []}).soundChoices,
      [toneSound, silentSound],
    );
  });
}
