import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as audio;

import 'athan_catalogue.dart';
import 'prayer_models.dart';

/// Where a sound comes from: a Flutter asset or a URI (a downloaded file or the hosted file).
typedef AthanSource = ({String? asset, Uri? uri, Duration? end});

/// Playback, kept apart so the player can be tested without audio.
abstract interface class AthanPlaybackPort {
  /// Plays [source] and completes when it ends or is stopped.
  Future<void> play(AthanSource source);
  Future<void> stop();
}

/// just_audio, separate from the recitation player. Starting it takes audio focus, so the
/// recitation pauses as well as through [AthanPlayer.pauseQuran].
class JustAudioAthanPort implements AthanPlaybackPort {
  audio.AudioPlayer? _player;
  @override
  Future<void> play(AthanSource source) async {
    final player = _player ??= audio.AudioPlayer();
    final base = source.asset != null
        ? audio.AudioSource.asset(source.asset!)
        : audio.AudioSource.uri(source.uri!);
    await player.setAudioSource(
      source.end == null
          ? base
          : audio.ClippingAudioSource(child: base, end: source.end),
    );
    await player.play();
    await player.processingStateStream.firstWhere(
      (s) => s == audio.ProcessingState.completed || !player.playing,
    );
    await player.stop();
  }

  @override
  Future<void> stop() async => _player?.stop();
}

/// The app's own athan playback: previews, the full athan on iPhone and web, and web alerts.
/// It pauses Quran recitation and memorization first and never resumes them (FR-026).
class AthanPlayer {
  AthanPlayer({
    required this.catalogue,
    required this.downloads,
    required this.pauseQuran,
    required this.pauseMemorization,
    AthanPlaybackPort? port,
  }) : port = port ?? JustAudioAthanPort();
  final AthanCatalogue catalogue;
  final AthanDownloads downloads;
  final AthanPlaybackPort port;
  final void Function() pauseQuran, pauseMemorization;

  static const toneAsset = 'assets/prayer/tone.wav';

  /// What is playing: a sound id while previewing, `full` for an athan, null when silent.
  final playing = ValueNotifier<String?>(null);
  int _token = 0;
  Uri? _uri;

  Future<AthanSource?> _source(String sound, {required bool full}) async {
    if (sound == silentSound) return null;
    if (sound == toneSound) return (asset: toneAsset, uri: null, end: null);
    final r = catalogue.byId(sound);
    if (r == null) return (asset: toneAsset, uri: null, end: null);
    final end = full ? null : Duration(milliseconds: r.openingEndMs);
    if (downloads.status(r) == DownloadStatus.ready) {
      _uri = await downloads.files.playableUri(downloads.fullFile(r));
      return (asset: null, uri: _uri, end: end);
    }
    // Not downloaded yet: stream the hosted file (previews, and the web while online).
    return (asset: null, uri: Uri.parse(r.fullUrl), end: end);
  }

  Future<void> _play(String label, String sound, {required bool full}) async {
    final token = ++_token;
    await _stopPort();
    final source = await _source(sound, full: full);
    if (source == null || token != _token) return;
    pauseMemorization();
    pauseQuran();
    playing.value = label;
    try {
      await port.play(source);
    } finally {
      if (token == _token) {
        playing.value = null;
        _release();
      }
    }
  }

  /// One preview at a time: starting another stops the first (FR-019).
  Future<void> preview(String sound) => _play(sound, sound, full: false);

  /// The complete recording (iPhone and web, Story 5).
  Future<void> playFull(AthanRecording r) => _play('full', r.id, full: true);

  /// A web alert: the chosen sound, or the full athan when [Alert.full].
  Future<void> playAlert(Alert alert) =>
      _play(alert.full ? 'full' : alert.sound, alert.sound, full: alert.full);

  Future<void> _stopPort() async {
    await port.stop();
    _release();
  }

  void _release() {
    final uri = _uri;
    _uri = null;
    if (uri != null) downloads.files.release(uri);
  }

  Future<void> stop() async {
    ++_token;
    playing.value = null;
    await _stopPort();
  }
}
