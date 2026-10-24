import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/recitation/audio_engine.dart';
import 'package:mathani/features/recitation/recitation_controller.dart';
import 'package:mathani/features/recitation/recited_item.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/fake_recitation.dart';
import '../support/harness.dart';

/// Reciter samples on the onboarding's reciter step (specs/005 contracts/onboarding-flow.md ›
/// RecitationController, data-model › ReciterPreview).
void main() {
  late ReaderController reader;
  late RecitationController c;
  late FakeAudioEngine engine;
  late FakeFetcher fetcher;
  late Reciter husary;
  late Reciter minshawy;
  const sample = RecitedItem.ayah(1, 1);

  void previewTest(String name, Future<void> Function(WidgetTester tester) body) {
    testWidgets(name, (tester) async {
      reader = (await tester.runAsync(openTestReader))!;
      (c, engine, fetcher) = openTestRecitation(reader);
      husary = reader.quran.reciter('husary')!;
      minshawy = reader.quran.reciter('minshawy')!;
      var firstPlay = false;
      c.onFirstPlay = () async => firstPlay = true;
      await body(tester);
      expect(firstPlay, isFalse, reason: 'a sample never sets up the system media controls');
      await c.stopPreview();
      await c.stop();
      c.dispose();
      await tester.runAsync(() async {
        reader.didChangeAppLifecycleState(AppLifecycleState.paused);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(seconds: 2));
    });
  }

  previewTest('plays Al-Fatiha 1:1 in the reciter\'s voice, then clears when it ends',
      (tester) async {
    final serial = reader.jumpSerial;
    final follow = c.followSerial;
    final loading = c.previewReciter(husary);
    expect(c.preview?.reciterId, 'husary');
    expect(c.preview?.status, PreviewStatus.loading);
    await loading;
    await tester.pump();
    expect(c.preview?.status, PreviewStatus.playing);
    expect(engine.window, [sample]);
    expect(engine.playing, isTrue);
    expect(fetcher.resolved.last, ('husary', sample));

    expect(c.session, isNull, reason: 'no bar, no highlight');
    expect(c.recited, isNull);
    expect(reader.jumpSerial, serial, reason: 'the reader does not move');
    expect(c.followSerial, follow);

    engine.finishCurrent();
    await tester.pump();
    expect(c.preview, isNull);
  });

  previewTest('another sample replaces the first, stopping it in between', (tester) async {
    await c.previewReciter(husary);
    await tester.pump();
    final stops = engine.stops;
    await c.previewReciter(minshawy);
    await tester.pump();
    expect(engine.stops, greaterThan(stops));
    expect(c.preview?.reciterId, 'minshawy');
    expect(c.preview?.status, PreviewStatus.playing);
    expect(fetcher.resolved.last, ('minshawy', sample));
  });

  previewTest('offline: the sample is unavailable', (tester) async {
    fetcher.offlineReciters.add('husary');
    await c.previewReciter(husary);
    await tester.pump();
    expect(c.preview?.status, PreviewStatus.unavailable);
    expect(engine.playing, isFalse);
  });

  previewTest('a sample that does not start within 5 s is unavailable', (tester) async {
    fetcher.holding.add(sample);
    unawaited(c.previewReciter(husary));
    await tester.pump(sampleStartTimeout - const Duration(milliseconds: 100));
    expect(c.preview?.status, PreviewStatus.loading);
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.preview?.status, PreviewStatus.unavailable);
    // A late file does not start playing.
    fetcher.release(sample);
    await tester.pump();
    expect(c.preview?.status, PreviewStatus.unavailable);
    expect(engine.playing, isFalse);
  });

  previewTest('stopPreview and leaving the app stop it', (tester) async {
    await c.previewReciter(husary);
    await tester.pump();
    await c.stopPreview();
    expect(c.preview, isNull);
    expect(engine.playing, isFalse);

    await c.previewReciter(minshawy);
    await tester.pump();
    c.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    expect(c.preview, isNull);
    expect(engine.playing, isFalse);
  });

  previewTest('a failure while playing makes it unavailable', (tester) async {
    await c.previewReciter(husary);
    await tester.pump();
    engine.emit(EngineFailed(StateError('decoder')));
    await tester.pump();
    expect(c.preview?.status, PreviewStatus.unavailable);
  });

  previewTest('nothing happens while a recitation is on', (tester) async {
    c.onFirstPlay = null; // a real recitation does set up the media controls
    await c.playFrom(const AyahRef(67, 1));
    await tester.pump();
    final item = c.session!.item;
    await c.previewReciter(minshawy);
    expect(c.preview, isNull);
    expect(c.session!.item, item);
    await c.stop();
  });

  previewTest('starting a recitation ends a sample', (tester) async {
    await c.previewReciter(husary);
    await tester.pump();
    c.onFirstPlay = null;
    await c.playFrom(const AyahRef(67, 1));
    await tester.pump();
    expect(c.preview, isNull);
    expect(c.session, isNotNull);
    await c.stop();
  });
}
