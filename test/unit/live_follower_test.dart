import 'dart:io' show sleep;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/memorization/live_follower.dart';
import 'package:mathani/features/memorization/speech_recogniser.dart';

/// A VAD and decoder the test drives: speech is "detected" while [detected] is set, segments end
/// when the test adds them, and every decode records the audio it was given.
class _ScriptedEngine implements SpeechEngine {
  bool detected = false;
  final segments = <({int start, int length})>[];
  final decoded = <int>[]; // samples per decode
  Duration decodeTime = Duration.zero;
  int vadSamples = 0;
  int resets = 0;
  bool freed = false;

  @override
  void vadAccept(Float32List window) => vadSamples += window.length;

  @override
  bool get vadDetected => detected;

  @override
  bool get vadEmpty => segments.isEmpty;

  @override
  ({int start, int length}) vadFront() => segments.first;

  @override
  void vadPop() => segments.removeAt(0);

  @override
  void vadFlush() {}

  @override
  void vadReset() => resets++;

  @override
  ({List<String> tokens, List<double> timestamps}) decode(Float32List audio) {
    if (decodeTime > Duration.zero) sleep(decodeTime);
    decoded.add(audio.length);
    return (tokens: const ['▁بسم'], timestamps: const [0.0]);
  }

  @override
  void free() => freed = true;
}

/// LiveFollower (specs/008 T021): the live-follow rules moved unchanged out of the speech isolate
/// (specs/007 contracts/live-recognition.md), checked over a scripted engine.
void main() {
  const second = micSampleRate;
  late _ScriptedEngine engine;
  late List<Heard> heard;
  late LiveFollower follower;

  setUp(() {
    engine = _ScriptedEngine();
    heard = [];
    follower = LiveFollower(engine, heard.add);
  });

  /// Live passes are paced by the clock too (never sooner than the last pass took), and a
  /// synchronous test does not move it.
  Future<void> waitPacing() => Future<void>.delayed(const Duration(milliseconds: 50));

  /// Feeds [seconds] of audio in 0.1 s chunks.
  void feed(double seconds) {
    final chunk = Float32List(second ~/ 10);
    for (var i = 0; i < (seconds * 10).round(); i++) {
      follower.accept(chunk);
    }
  }

  test('no pass while the VAD hears no speech', () {
    feed(3);
    expect(heard, isEmpty);
    expect(engine.vadSamples, 3 * second - (3 * second) % vadWindow);
  });

  test('a live pass after livePassEvery of speech, then none until it is committed', () async {
    engine.detected = true;
    feed(livePassEvery);
    expect(heard, hasLength(1));
    expect(heard.single.hearing, Hearing.live);
    feed(2);
    expect(heard, hasLength(1), reason: 'awaiting the commit');
    follower.commit(heard.single.pass, 0);
    await waitPacing();
    feed(livePassEvery);
    expect(heard, hasLength(2));
  });

  test('a commit for an older pass is ignored', () {
    engine.detected = true;
    feed(livePassEvery);
    follower.commit(heard.single.pass + 1, second);
    feed(1);
    expect(heard, hasLength(1));
  });

  test('a commit moves the anchor: the next pass starts there', () async {
    engine.detected = true;
    feed(livePassEvery);
    follower.commit(heard.single.pass, second ~/ 4);
    await waitPacing();
    feed(livePassEvery);
    expect(heard.last.windowStart, second ~/ 4);
  });

  test('a VAD segment that ends is a pause pass up to its end', () {
    engine.detected = true;
    feed(livePassEvery);
    follower.commit(heard.single.pass, 0);
    engine
      ..detected = false
      ..segments.add((start: 0, length: second ~/ 2));
    feed(0.1);
    expect(heard.last.hearing, Hearing.pause);
    expect(heard.last.endSample, second ~/ 2);
  });

  test('a segment cut at vadMaxSpeech is speech continuing, not a pause', () {
    engine.segments.add((start: 0, length: (vadMaxSpeech * second).round()));
    feed(0.1);
    expect(heard, isEmpty);
    expect(engine.segments, isEmpty);
  });

  test('a pass slower than liveSlowPass stops live passes until the next pause', () async {
    engine
      ..detected = true
      ..decodeTime = liveSlowPass + const Duration(milliseconds: 100);
    feed(livePassEvery);
    expect(heard, hasLength(1));
    engine.decodeTime = Duration.zero;
    follower.commit(heard.single.pass, 0);
    feed(2);
    expect(heard, hasLength(1), reason: 'live passes suspended');
    engine.segments.add((start: 0, length: 2 * second));
    feed(0.1);
    expect(heard.last.hearing, Hearing.pause);
    await Future<void>.delayed(liveSlowPass + const Duration(milliseconds: 200));
    feed(livePassEvery);
    expect(heard.last.hearing, Hearing.live, reason: 'resumed after the pause');
  });

  test('audio held past maxHeld is cut to its last second at the commit', () async {
    engine.detected = true;
    feed(livePassEvery);
    feed(maxHeld + 1.0);
    follower.commit(heard.single.pass, 0);
    await waitPacing();
    feed(livePassEvery);
    final total = ((livePassEvery + maxHeld + 1.0) * second).round();
    expect(heard.last.windowStart, total - second);
  });

  test('flush decodes what is held as a pause pass', () {
    engine.detected = true;
    feed(livePassEvery);
    follower.commit(heard.single.pass, 0);
    feed(1);
    follower.flush();
    expect(heard.last.hearing, Hearing.pause);
    expect(heard.last.endSample, ((livePassEvery + 1) * second).round());
  });

  test('reset drops held audio: the next pass decodes only what came after', () async {
    engine.detected = true;
    feed(2);
    follower.reset();
    expect(engine.resets, 1);
    await waitPacing();
    feed(0.1);
    expect(heard.last.windowStart, 2 * second, reason: 'the anchor moved to the reset');
    expect(engine.decoded.last, second ~/ 10, reason: 'nothing from before the reset');
  });

  test('free frees the engine', () {
    follower.free();
    expect(engine.freed, isTrue);
  });
}
