import 'dart:async';
import 'dart:typed_data';

import 'package:mathani/features/memorization/asr_model.dart';
import 'package:mathani/features/memorization/mic_source.dart';
import 'package:mathani/features/memorization/speech_recogniser.dart';

/// A recogniser that emits scripted passes (specs/006 T040, specs/007 T013), for controller and
/// widget tests. Words are 8000 samples apart; each pass starts where the last commit left it.
class FakeSpeechRecogniser implements SpeechRecogniser {
  final _heard = StreamController<Heard>.broadcast();

  String? loadedFrom;
  int acceptedSamples = 0;
  int flushes = 0;
  int resets = 0;
  bool disposed = false;

  /// Every commit, as (pass, fromSample).
  final commits = <(int, int)>[];
  int _pass = 0;
  int _anchor = 0;

  /// When set, [load] waits for it, so a test can hold the session in "loading".
  Completer<void>? holdLoad;

  /// When set, [load] fails with it.
  Object? loadError;

  /// The pass [say] last emitted.
  late Heard last;

  /// Emits what the reader "said" as one pass, starting at [start] (the current anchor by
  /// default). A pause pass moves the anchor past its words, as the recogniser does.
  Heard say(String text, {Hearing hearing = Hearing.pause, int? start}) {
    final from = start ?? _anchor;
    final words = [
      for (final (i, w) in text.split(' ').where((w) => w.isNotEmpty).indexed)
        HeardWord(w, from + i * 8000, from + i * 8000 + 7000), // each word lasts most of its slot
    ];
    final end = from + words.length * 8000;
    last = Heard(++_pass, hearing, words, from, end);
    if (hearing == Hearing.pause) _anchor = end;
    _heard.add(last);
    return last;
  }

  /// Emits a hand-made pass, for words timed as [say] does not time them.
  void emit(Heard heard) {
    _pass = heard.pass;
    last = heard;
    _heard.add(heard);
  }

  @override
  Stream<Heard> get heard => _heard.stream;

  @override
  void commit(int pass, int fromSample) {
    commits.add((pass, fromSample));
    if (pass == _pass && fromSample > _anchor) _anchor = fromSample;
  }

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
