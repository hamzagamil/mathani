// Frame performance while paging and scrolling (task T064, constitution III, SC-002).
// Profile mode on a reference device:
//   flutter drive --profile --driver=test_driver/perf_driver.dart \
//     --target=integration_test/paging_perf_test.dart -d <device>
// Add --dart-define=WITH_RECITATION=true to page while a recitation plays (specs/004 SC-006);
// the device needs a connection: Al-Baqarah streams from EveryAyah.
// Add --dart-define=WITH_MEMORIZATION=true to page 20 times during a memorization session (specs/006
// T057, SC-010), with a scripted recogniser and no microphone.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/data/quran_repository.dart';
import 'package:mathani/data/user_repository.dart';
import 'package:mathani/features/memorization/asr_model.dart';
import 'package:mathani/features/memorization/memorization_controller.dart';
import 'package:mathani/features/memorization/mic_source.dart';
import 'package:mathani/features/memorization/speech_recogniser.dart';
import 'package:mathani/features/recitation/ayah_fetcher.dart';
import 'package:mathani/features/recitation/recitation_controller.dart';
import 'package:mathani/shared/reader_state.dart';

const _withRecitation = bool.fromEnvironment('WITH_RECITATION');
const _withMemorization = bool.fromEnvironment('WITH_MEMORIZATION');

/// A recogniser that hears nothing: the session only hides words while the pages turn.
class _SilentRecogniser implements SpeechRecogniser {
  final _segments = StreamController<Segment>.broadcast();
  @override
  Stream<Segment> get segments => _segments.stream;
  @override
  Future<void> load(String modelDir) async {}
  @override
  void accept(Float32List samples) {}
  @override
  void flush() {}
  @override
  void reset() {}
  @override
  Future<void> dispose() => _segments.close();
}

class _NoMic implements MicSource {
  @override
  bool listening = false;
  @override
  Stream<Float32List> get samples => const Stream.empty();
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> start() async => listening = true;
  @override
  Future<void> stop() async => listening = false;
  @override
  void gate(Duration tone) {}
  @override
  Future<void> dispose() async {}
}

class _ReadyModel extends AsrModel {
  _ReadyModel() : super(files: const []);
  @override
  Future<void> refresh() async {}
  @override
  AsrModelState get state => AsrModelState.ready;
  @override
  String get modelDir => '/model';
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('page through 50 Mushaf pages, then scroll the flowing layout', (tester) async {
    final (quran, user) = await (QuranRepository.open(), UserRepository.open()).wait;
    final (_, prefs) = await user.loadStartup();
    final reader = ReaderController(
      quran: quran,
      user: user,
      anchor: const AyahRef(2, 1),
      preferences: prefs.copyWith(layout: ReadingLayout.mushaf, onboardingDone: true),
    );
    final recitation = _withRecitation
        ? RecitationController(
            reader: reader,
            fetcher: AyahFetcher(
              recordingSize: (r, s, a) async => (await quran.recordingBytes(r, s))[a - 1],
            ),
          )
        : null;
    final memorization = _withMemorization
        ? MemorizationController(
            reader: reader,
            model: _ReadyModel(),
            recogniser: _SilentRecogniser.new,
            mic: _NoMic.new,
          )
        : null;
    await tester.pumpWidget(
        MathaniApp(controller: reader, recitation: recitation, memorization: memorization));
    await tester.pumpAndSettle();
    if (memorization != null) {
      // Al-Baqarah 1-25: the session spans the first pages flung through.
      expect(await memorization.start(const MemorizationRange(2, 1, 25)), StartOutcome.started);
      await tester.pumpAndSettle();
    }
    if (recitation != null) {
      // Start Al-Baqarah and wait until it plays (the loading spinner never settles).
      await recitation.playFrom(const AyahRef(2, 1));
      for (var i = 0; i < 100 && recitation.session?.status != RecitationStatus.playing; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(recitation.session?.status, RecitationStatus.playing);
    }

    await binding.watchPerformance(() async {
      for (var i = 0; i < (_withMemorization ? 20 : 50); i++) {
        await tester.fling(find.byType(PageView), const Offset(400, 0), 1500);
        await tester.pumpAndSettle();
      }
    }, reportKey: _withMemorization
        ? 'mushaf_paging_with_memorization'
        : _withRecitation
            ? 'mushaf_paging_with_recitation'
            : 'mushaf_paging');

    reader.updatePreferences(reader.preferences.copyWith(layout: ReadingLayout.flowing));
    await tester.pumpAndSettle();
    await binding.watchPerformance(() async {
      for (var i = 0; i < 20; i++) {
        await tester.fling(find.byType(CustomScrollView), const Offset(0, -600), 3000);
        await tester.pumpAndSettle();
      }
    }, reportKey: _withRecitation ? 'flowing_scroll_with_recitation' : 'flowing_scroll');
    await recitation?.stop();
    await memorization?.end();
  });
}
