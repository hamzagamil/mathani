import 'package:audio_service/audio_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/recitation/ayah_fetcher.dart';
import 'package:mathani/features/recitation/media_handler.dart';
import 'package:mathani/features/recitation/recitation_controller.dart';
import 'package:mathani/features/recitation/recited_item.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/fake_recitation.dart';
import '../support/harness.dart';

/// Lock screen and notification (specs/004 T040): system commands reach the controller, and the
/// now-playing item names the surah, ayah and reciter in the interface language.
void main() {
  late ReaderController reader;
  late RecitationController c;
  late FakeFetcher fetcher;
  late RecitationMediaHandler handler;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  void mediaTest(String name, LanguagePref language, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      reader = (await tester.runAsync(openTestReader))!;
      await tester.runAsync(() async {
        reader.updatePreferences(reader.preferences.copyWith(language: language));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      (c, _, fetcher) = openTestRecitation(reader);
      handler = RecitationMediaHandler(c);
      await body(tester);
      handler.dispose();
      await c.stop();
      c.dispose();
      await tester.runAsync(() async {
        reader.didChangeAppLifecycleState(AppLifecycleState.paused);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(seconds: 2));
    });
  }

  mediaTest('Arabic: surah and ayah, reciter, album; play/pause/next/previous reach the controller',
      LanguagePref.ar, (tester) async {
    expect(handler.playbackState.value.processingState, AudioProcessingState.idle);
    c.playFrom(const AyahRef(67, 12));
    await settle(tester);
    final item = handler.mediaItem.value!;
    expect(item.title, 'سورة الملك · ١٢');
    expect(item.artist, 'محمود خليل الحصري');
    expect(item.album, 'مثاني');
    final state = handler.playbackState.value;
    expect(state.playing, isTrue);
    expect(state.processingState, AudioProcessingState.ready);
    expect(state.controls, [MediaControl.skipToPrevious, MediaControl.pause, MediaControl.skipToNext]);
    expect(state.androidCompactActionIndices, [0, 1, 2]);

    await handler.pause();
    expect(c.session!.status, RecitationStatus.paused);
    expect(handler.playbackState.value.controls[1], MediaControl.play);
    await handler.play();
    await settle(tester);
    expect(c.session!.status, RecitationStatus.playing);

    await handler.skipToNext();
    expect(c.session!.item, const RecitedItem.ayah(67, 13));
    await handler.skipToPrevious();
    expect(c.session!.item, const RecitedItem.ayah(67, 12));
    await tester.pump(skipMergeWindow + const Duration(milliseconds: 10));
    await settle(tester);

    await handler.stop();
    expect(c.session, isNull);
    expect(handler.playbackState.value.processingState, AudioProcessingState.idle);
  });

  mediaTest('English: transliterated name and surah:ayah; the basmala', LanguagePref.en,
      (tester) async {
    c.playFrom(const AyahRef(67, 12));
    await settle(tester);
    expect(handler.mediaItem.value!.title, 'Al-Mulk · 67:12');
    expect(handler.mediaItem.value!.artist, 'Mahmoud Khalil Al-Husary');
    expect(handler.mediaItem.value!.album, 'Mathani');
    c.playFrom(const AyahRef(67, 1));
    await settle(tester);
    expect(handler.mediaItem.value!.title, 'Al-Mulk · Basmala');
  });

  mediaTest('loading is buffering and an error carries its message', LanguagePref.en,
      (tester) async {
    fetcher.holding.add(const RecitedItem.ayah(67, 3));
    c.playFrom(const AyahRef(67, 3));
    await settle(tester);
    expect(handler.playbackState.value.processingState, AudioProcessingState.buffering);
    fetcher.failHeld(const RecitedItem.ayah(67, 3), FetchError.offline);
    await settle(tester);
    expect(handler.playbackState.value.processingState, AudioProcessingState.error);
    expect(handler.playbackState.value.errorMessage,
        'No connection. Download this surah to listen offline.');
  });
}
