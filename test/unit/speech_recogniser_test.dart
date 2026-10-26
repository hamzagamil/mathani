import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/memorization/mic_source.dart';
import 'package:mathani/features/memorization/recitation_matcher.dart';
import 'package:mathani/features/memorization/sherpa_recogniser.dart';
import 'package:mathani/features/memorization/speech_recogniser.dart';

import '../support/harness.dart';

/// The microphone's PCM conversion, and real decodes through the speech isolate into the matcher
/// (specs/006 T040; specs/007 T015, T019, T027): each clip is played at real time, live passes are
/// answered with commits as the controller does, and a pause pass closes it. The decodes need the
/// exported model and check clips (tool/README.md › Memorization model), so they run on a
/// maintainer's machine and are skipped elsewhere.
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

  // 16 kHz mono float32 clips, named SSSAAA[-label].f32; mistakes.csv lists the planned mistakes
  // of labelled clips as `file, surah, ayah, kind, position` (specs/007 T002).
  const modelDir = 'build/asr/khatma-v1';
  const checkDir = String.fromEnvironment('MEMO_CHECK', defaultValue: 'build/asr/check');
  final clips = Directory(checkDir).existsSync()
      ? (Directory(checkDir).listSync().whereType<File>().where((f) => f.path.endsWith('.f32')).toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];
  final available = File('$modelDir/model.int8.onnx').existsSync() && clips.isNotEmpty;
  // Every pass with its words, with --dart-define=MEMO_DEBUG=true.
  const debug = bool.fromEnvironment('MEMO_DEBUG');
  final planned = <String, (MistakeKind, int)>{
    if (File('$checkDir/mistakes.csv').existsSync())
      for (final line in File('$checkDir/mistakes.csv').readAsLinesSync().skip(1))
        if (line.split(',') case [final file, _, _, final kind, final position])
          file.trim(): (MistakeKind.values.byName(kind.trim()), int.parse(position.trim())),
  };

  testWidgets('recited ayat, played at real time, are followed live and complete', (tester) async {
    final quran = (await tester.runAsync(openTestReader))!.quran;
    // sherpa-onnx's desktop library, in its Windows package (from the package config).
    final packages = (jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
        as Map)['packages'] as List;
    final root = (packages.firstWhere((p) => p['name'] == 'sherpa_onnx_windows') as Map)['rootUri'] as String;
    final r = SherpaSpeechRecogniser(
        nativeLibraryDir: Uri.parse(root.endsWith('/') ? root : '$root/').resolve('windows').toFilePath());
    final report = <String>[];
    final delays = <double>[];
    var clean = 0, cleanClips = 0, caught = 0, plannedClips = 0, falseAlarms = 0;
    await tester.runAsync(() async {
      await r.load(modelDir);
      for (final clip in clips) {
        final name = clip.uri.pathSegments.last.split('.').first;
        final surah = int.parse(name.substring(0, 3)), ayah = int.parse(name.substring(3, 6));
        final words = await quran.memorizationWords(surah, ayah, ayah);
        final matcher = RecitationMatcher(
            [for (final ayat in words) [for (final w in ayat) RefWord(w.wordId, w.position, w.form)]]);
        final audio = clip.readAsBytesSync().buffer.asFloat32List();

        // Where each recognised word ends, from one decode of the whole clip, to time the reveals.
        // Pause passes come at each pause inside the clip, then one on flush, which ends exactly
        // one clip after where the first pass started: wait for that one, however long it takes.
        final ends = <int>[];
        var lastEnd = 0;
        int? from;
        final whole = Completer<void>();
        r.reset();
        var sub = r.heard.listen((h) {
          from ??= h.windowStart;
          if (h.hearing != Hearing.pause) return;
          for (var i = 1; i < h.words.length; i++) {
            ends.add(h.words[i].startSample);
          }
          if (h.words.isNotEmpty) ends.add(h.endSample);
          lastEnd = h.endSample;
          if (h.endSample == from! + audio.length && !whole.isCompleted) whole.complete();
        });
        r.accept(audio);
        r.flush();
        await whole.future.timeout(const Duration(minutes: 5));
        await sub.cancel();

        // Played as the microphone sends it: 100 ms chunks at real time, then 1 s of silence.
        r.reset();
        final origin2 = lastEnd;
        final origin = lastEnd - audio.length; // the first play's first sample
        final anchors = <int>[];
        final mistakes = <AyahMistake>[];
        var completed = false, live = 0, liveBeforeEnd = 0, longest = 0, revealed = 0;
        final clock = Stopwatch()..start();
        sub = r.heard.listen((h) {
          longest = h.endSample - h.windowStart > longest ? h.endSample - h.windowStart : longest;
          final onWord = anchors.contains(h.windowStart);
          final used = h.hearing == Hearing.live && h.words.isNotEmpty
              ? h.words.sublist(0, h.words.length - 1)
              : h.words;
          final e = matcher.accept([for (final w in used) w.text],
              hearing: h.hearing, startsOnMatched: onWord);
          completed |= e.ayahCompleted;
          mistakes.addAll(e.mistakes);
          if (debug) {
            // ignore: avoid_print
            print('  #${h.pass} ${h.hearing.name} ${((h.windowStart - origin2) / micSampleRate).toStringAsFixed(2)}'
                '-${((h.endSample - origin2) / micSampleRate).toStringAsFixed(2)}s onWord=$onWord '
                '[${[for (final w in h.words) w.text].join(' ')}] -> cursor ${matcher.ayahIndex}:${matcher.cursor} '
                'last ${e.lastMatchedToken} ${e.mistakes}');
          }
          for (var k = 0; k < e.matched.length; k++, revealed++) {
            if (revealed < ends.length) {
              delays.add(clock.elapsedMilliseconds / 1000 - (ends[revealed] - origin) / micSampleRate);
            }
          }
          if (h.hearing == Hearing.live) {
            live++;
            if (clock.elapsedMilliseconds < audio.length * 1000 ~/ micSampleRate) liveBeforeEnd++;
            var from = h.windowStart;
            if (e.mistakes.isNotEmpty || e.droppedRest) {
              from = h.endSample;
            } else if (e.lastMatchedToken >= 0) {
              from = used[e.lastMatchedToken].startSample;
              if (from < h.windowStart) from = h.windowStart;
              anchors.add(from);
            }
            r.commit(h.pass, from);
          }
        });
        for (var i = 0; i < audio.length; i += 1600) {
          r.accept(Float32List.fromList(audio.sublist(i, (i + 1600).clamp(0, audio.length))));
          final due = (i + 1600) * 1000 ~/ micSampleRate;
          final wait = due - clock.elapsedMilliseconds;
          if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
        }
        // 2 s of room noise, as a microphone hears after the reader stops (the VAD takes digital
        // zeros for speech).
        final noise = math.Random(1);
        for (var i = 0; i < 20; i++) {
          r.accept(Float32List.fromList([for (var k = 0; k < 1600; k++) (noise.nextDouble() - 0.5) * 0.002]));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        r.flush();
        await Future<void>.delayed(const Duration(seconds: 3));
        await sub.cancel();

        final plan = planned[name];
        if (plan == null) {
          cleanClips++;
          if (completed && mistakes.isEmpty) clean++;
          falseAlarms += mistakes.length;
        } else {
          plannedClips++;
          if (mistakes.any((m) => m.kind == plan.$1 && m.position == plan.$2)) caught++;
          falseAlarms += mistakes.where((m) => m.position != plan.$2).length;
        }
        report.add('$name ${(audio.length / micSampleRate).toStringAsFixed(1)}s: $live live passes '
            '($liveBeforeEnd before the clip ended), longest window '
            '${(longest / micSampleRate).toStringAsFixed(1)}s, '
            '${completed ? 'complete' : 'NOT complete'}${mistakes.isEmpty ? '' : ' $mistakes'}');
        expect(longest, lessThanOrEqualTo((maxHeld + 1) * micSampleRate), reason: name);
        if (plan == null) expect(liveBeforeEnd, greaterThan(0), reason: '$name: words before the end');
      }
      await r.dispose();
    });
    delays.sort();
    String at(double q) => delays.isEmpty ? '-' : delays[(q * (delays.length - 1)).round()].toStringAsFixed(2);
    report
      ..add('reveal delay after the word ends (s): median ${at(0.5)}, 90th percentile ${at(0.9)}, '
          'max ${at(1)} over ${delays.length} words')
      ..add('(a) correct ayat completed with 0 mistakes: $clean / $cleanClips'
          '${plannedClips == 0 ? '' : '; (b) planned mistakes caught: $caught / $plannedClips'}'
          '; false alarms: $falseAlarms. Baseline: specs/007-khatma-live-recognition/baseline.md');
    // ignore: avoid_print
    print(report.join('\n'));
    // A smoke check of the whole chain; accuracy on ordinary readers is spike S1's gate (006 T035,
    // 007 T027).
    expect(clean / cleanClips, greaterThanOrEqualTo(0.85), reason: report.join('\n'));
  }, skip: !available, timeout: const Timeout(Duration(minutes: 15)));
}
