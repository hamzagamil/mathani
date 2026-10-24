import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/memorization/mic_source.dart';
import 'package:mathani/features/memorization/recitation_matcher.dart';
import 'package:mathani/features/memorization/speech_recogniser.dart';
import 'package:mathani/features/search/arabic_normalizer.dart';

import '../support/harness.dart';

/// The microphone's PCM conversion, and real decodes through the speech isolate into the matcher
/// (specs/006 T040). The decodes need the exported model and check clips (tool/README.md ›
/// Memorization model), so they run on a maintainer's machine and are skipped elsewhere.
void main() {
  group('Pcm16Decoder', () {
    test('little-endian 16-bit samples become floats in [-1, 1)', () {
      final d = Pcm16Decoder();
      expect(d.convert(Uint8List.fromList([0x00, 0x00, 0xFF, 0x7F, 0x00, 0x80, 0xFF, 0xFF])),
          [0.0, 32767 / 32768, -1.0, -1 / 32768]);
    });

    test('a sample split across chunks is carried to the next one', () {
      final d = Pcm16Decoder();
      expect(d.convert(Uint8List.fromList([0x00, 0x40, 0x00])), [0.5]);
      expect(d.convert(Uint8List.fromList([0xC0])), [-0.5]);
      expect(d.convert(Uint8List(0)), isEmpty);
      d.reset();
      expect(d.convert(Uint8List.fromList([0x00, 0x40])), [0.5]);
    });
  });

  // 16 kHz mono float32 clips of Alafasy, named SSSAAA.f32.
  const modelDir = 'build/asr/tarteel-tiny-v1';
  const checkDir = 'build/asr/check';
  final clips = Directory(checkDir).existsSync()
      ? (Directory(checkDir).listSync().whereType<File>().where((f) => f.path.endsWith('.f32')).toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];
  final available = File('$modelDir/encoder.int8.onnx').existsSync() && clips.isNotEmpty;

  testWidgets('recited ayat decode and complete in the matcher', (tester) async {
    final quran = (await tester.runAsync(openTestReader))!.quran;
    // sherpa-onnx's desktop library, in its Windows package (from the package config).
    final packages = (jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
        as Map)['packages'] as List;
    final root = (packages.firstWhere((p) => p['name'] == 'sherpa_onnx_windows') as Map)['rootUri'] as String;
    final r = SherpaSpeechRecogniser(
        nativeLibraryDir: Uri.parse(root.endsWith('/') ? root : '$root/').resolve('windows').toFilePath());
    final report = <String>[];
    var clean = 0;
    await tester.runAsync(() async {
      await r.load(modelDir);
      for (final clip in clips) {
        final name = clip.uri.pathSegments.last.split('.').first;
        final surah = int.parse(name.substring(0, 3)), ayah = int.parse(name.substring(3));
        final words = await quran.memorizationWords(surah, ayah, ayah);
        final matcher = RecitationMatcher(
            [for (final ayat in words) [for (final w in ayat) RefWord(w.wordId, w.position, w.form)]]);
        final heard = <Segment>[];
        final sub = r.segments.listen(heard.add);
        final audio = clip.readAsBytesSync().buffer.asFloat32List();
        final started = DateTime.now();
        // As the microphone sends it: 100 ms chunks, then 1 s of silence and a flush.
        for (var i = 0; i < audio.length; i += 1600) {
          r.accept(Float32List.fromList(audio.sublist(i, (i + 1600).clamp(0, audio.length))));
        }
        r.accept(Float32List(micSampleRate));
        r.flush();
        // Done when nothing more arrives for 5 s (decoding takes about 1 s per segment here).
        var count = -1;
        while (count != heard.length) {
          count = heard.length;
          await Future<void>.delayed(const Duration(seconds: 5));
        }
        await sub.cancel();
        var completed = false;
        final mistakes = <AyahMistake>[];
        for (final (i, s) in heard.indexed) {
          final e = matcher.accept(normalizeArabic(s.text).split(' ').where((t) => t.isNotEmpty).toList(),
              finalSegment: i == heard.length - 1 || !s.forcedSplit);
          completed |= e.ayahCompleted;
          mistakes.addAll(e.mistakes);
        }
        final seconds = DateTime.now().difference(started).inMilliseconds / 1000;
        report.add('$surah:$ayah ${audio.length / micSampleRate}s audio, ${heard.length} segments, '
            '${seconds.toStringAsFixed(1)}s: ${completed ? 'complete' : 'NOT complete'}'
            '${mistakes.isEmpty ? '' : ' $mistakes'} | ${heard.map((s) => s.text).join(' / ')}');
        if (completed && mistakes.isEmpty) clean++;
      }
      await r.dispose();
    });
    // ignore: avoid_print
    print(report.join('\n'));
    // A smoke check of the whole chain on professional recordings; accuracy on ordinary readers
    // is spike S1's gate (T035).
    expect(clean / clips.length, greaterThanOrEqualTo(0.85), reason: report.join('\n'));
  }, skip: !available, timeout: const Timeout(Duration(minutes: 5)));
}
