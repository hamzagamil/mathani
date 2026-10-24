import 'dart:async';
import 'dart:typed_data';

import 'package:mathani/features/memorization/asr_model.dart';
import 'package:mathani/features/memorization/mic_source.dart';
import 'package:mathani/features/memorization/speech_recogniser.dart';

/// A recogniser that emits scripted segments (specs/006 T040), for controller and widget tests.
class FakeSpeechRecogniser implements SpeechRecogniser {
  final _segments = StreamController<Segment>.broadcast();

  String? loadedFrom;
  int acceptedSamples = 0;
  int flushes = 0;
  int resets = 0;
  bool disposed = false;

  /// When set, [load] waits for it, so a test can hold the session in "loading".
  Completer<void>? holdLoad;

  /// When set, [load] fails with it.
  Object? loadError;

  /// Emits what the reader "said" as one segment.
  void say(String text, {bool forcedSplit = false}) =>
      _segments.add(Segment(text, forcedSplit: forcedSplit));

  @override
  Stream<Segment> get segments => _segments.stream;

  @override
  Future<void> load(String modelDir) async {
    await holdLoad?.future;
    if (loadError != null) throw loadError!;
    loadedFrom = modelDir;
  }

  @override
  void accept(Float32List samples) => acceptedSamples += samples.length;

  @override
  void flush() => flushes++;

  @override
  void reset() => resets++;

  @override
  Future<void> dispose() async => disposed = true;
}

/// A microphone that is always allowed and never hears anything; the recogniser is scripted.
class FakeMicSource implements MicSource {
  final _samples = StreamController<Float32List>.broadcast();
  bool permitted = true;
  int starts = 0;
  int stops = 0;
  Duration? gated;

  @override
  bool listening = false;

  @override
  Stream<Float32List> get samples => _samples.stream;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<bool> requestPermission() async => permitted;

  @override
  Future<void> start() async {
    starts++;
    listening = true;
  }

  @override
  Future<void> stop() async {
    if (listening) stops++;
    listening = false;
  }

  @override
  void gate(Duration tone) => gated = tone;

  @override
  Future<void> dispose() async => _samples.close();
}

/// A model already on the device, with no files to read.
class ReadyAsrModel extends AsrModel {
  ReadyAsrModel() : super(files: const []);

  @override
  Future<void> refresh() async {}

  @override
  AsrModelState get state => AsrModelState.ready;

  @override
  String get modelDir => '/model';
}
