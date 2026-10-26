// The microphone for memorization (specs/006 research R10, FR-019, FR-020): 16 kHz mono PCM,
// converted to floats and passed on in memory; never written anywhere.
import 'dart:async';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';

import 'speech_recogniser.dart' show micSampleRate;

/// Samples are dropped this long after the mistake tone ends, so it is never decoded (R12).
const toneGateMargin = Duration(milliseconds: 150);

class MicSource {
  MicSource({AudioRecorder? recorder, DateTime Function()? now})
      : _recorder = recorder ?? AudioRecorder(),
        _now = now ?? DateTime.now;

  final AudioRecorder _recorder;
  final DateTime Function() _now;
  final _samples = StreamController<Float32List>.broadcast();
  StreamSubscription<Uint8List>? _subscription;
  final _pcm = Pcm16Decoder();
  DateTime? _gatedUntil;

  /// Float samples in [-1, 1) while listening.
  Stream<Float32List> get samples => _samples.stream;

  bool get listening => _subscription != null;

  /// Whether the microphone may be used, asking the system the first time. Call it only after
  /// the explanation sheet (FR-010).
  Future<bool> requestPermission() => _recorder.hasPermission();

  /// Whether the microphone may be used, without asking.
  Future<bool> hasPermission() => _recorder.hasPermission(request: false);

  /// Starts a new stream. The audio session becomes play-and-record, measurement mode, and keeps
  /// vibration and system sounds audible for the mistake signal (R10, R12).
  Future<void> start() async {
    if (_subscription != null) return;
    // Browsers have no audio session to configure (specs/008 research R11).
    if (!kIsWeb) {
      await _recorder.ios?.manageAudioSession(false);
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker |
            AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.measurement,
      ));
      await session.setActive(true);
    }
    _pcm.reset();
    // In browsers, echo cancellation, noise suppression and automatic gain stay off (the
    // defaults), closest to Android's voice-recognition source; spike S3 confirms (research R11).
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: micSampleRate,
      numChannels: 1,
      androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.voiceRecognition),
      iosConfig: IosRecordConfig(allowHapticsAndSystemSoundsDuringRecording: true),
    ));
    _subscription = stream.listen(_onBytes);
  }

  /// Stops the stream, not pausing it (FR-020), and gives the session back to recitation.
  Future<void> stop() async {
    final subscription = _subscription;
    if (subscription == null) return;
    _subscription = null;
    await subscription.cancel();
    await _recorder.stop();
    if (kIsWeb) return;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  /// Drops samples for [tone] plus [toneGateMargin], while the mistake tone plays.
  void gate(Duration tone) => _gatedUntil = _now().add(tone + toneGateMargin);

  void _onBytes(Uint8List bytes) {
    final samples = _pcm.convert(bytes);
    final until = _gatedUntil;
    if (until != null && _now().isBefore(until)) return;
    if (samples.isNotEmpty) _samples.add(samples);
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
    await _samples.close();
  }
}

/// Little-endian 16-bit PCM to floats, carrying a sample split across chunks.
class Pcm16Decoder {
  int? _low;

  void reset() => _low = null;

  Float32List convert(Uint8List bytes) {
    final carried = _low;
    final total = bytes.length + (carried == null ? 0 : 1);
    int byteAt(int k) => carried == null ? bytes[k] : (k == 0 ? carried : bytes[k - 1]);
    final out = Float32List(total ~/ 2);
    for (var s = 0; s < out.length; s++) {
      out[s] = _sample(byteAt(2 * s), byteAt(2 * s + 1));
    }
    _low = total.isOdd ? byteAt(total - 1) : null;
    return out;
  }

  static double _sample(int low, int high) {
    final v = high << 8 | low;
    return (v >= 0x8000 ? v - 0x10000 : v) / 32768;
  }
}
