import 'dart:async';

import 'athan_catalogue.dart';
import 'prayer_models.dart';
import 'prayer_services.dart';

/// Implemented by the ONE shared media handler. play() acknowledges start; it
/// must not wait for the recording to finish, which would block Stop.
abstract interface class AthanPlaybackPort {
  Future<void> load(Uri uri, {Duration? start, Duration? end});
  Future<void> play();
  Future<void> stop();
}

class AthanPlayer implements PrayerAudio {
  AthanPlayer({
    required this.downloads,
    required this.playback,
    required List<AthanRecording> recordings,
    required this.pauseQuran,
    required this.pauseMemorization,
    bool Function(ScheduledReminder)? isCurrent,
    Future<bool> Function(ScheduledReminder)? claimStart,
    Future<void> Function(ScheduledReminder)? cancelEvent,
  }) : recordings = List.unmodifiable(recordings),
       isCurrent = isCurrent ?? ((_) => false),
       claimStart = claimStart ?? ((_) async => false),
       cancelEvent = cancelEvent ?? ((_) async {});
  final AthanDownloads downloads;
  final AthanPlaybackPort playback;
  final List<AthanRecording> recordings;
  final Future<void> Function() pauseQuran, pauseMemorization;
  final bool Function(ScheduledReminder) isCurrent;
  final Future<bool> Function(ScheduledReminder) claimStart;
  final Future<void> Function(ScheduledReminder) cancelEvent;
  int _generation = 0;
  Future<void> _tail = Future.value();
  Uri? _uri;
  ScheduledReminder? _event;
  final _inFlight = <String>{}, _started = <String>{};
  void _release() {
    final uri = _uri;
    _uri = null;
    if (uri != null) downloads.files.release(uri);
  }

  Future<void> _serial(Future<void> Function() action) {
    final future = _tail.then((_) => action());
    _tail = future.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return future;
  }

  @override
  Future<void> preview(AthanRecording recording) =>
      _begin(recording, AthanMode.opening);
  @override
  Future<void> play(ScheduledReminder reminder) async {
    final key = '${reminder.generation}:${reminder.eventId}';
    if (_started.contains(key) ||
        _inFlight.contains(key) ||
        !isCurrent(reminder)) {
      return;
    }
    final recording = recordings
        .where((r) => r.id == reminder.audioId)
        .firstOrNull;
    if (recording == null ||
        reminder.kind == PrayerKind.sunrise ||
        reminder.kind == PrayerKind.qiyam) {
      throw const PrayerException(PrayerFailure.audioUnavailable);
    }
    _inFlight.add(key);
    try {
      await _begin(recording, reminder.mode, reminder: reminder);
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<void> _begin(
    AthanRecording recording,
    AthanMode mode, {
    ScheduledReminder? reminder,
  }) async {
    final token = ++_generation;
    final previous = _event;
    _event = reminder;
    try {
      if (previous != null) await cancelEvent(previous);
      await playback.stop();
      _release();
      if (mode == AthanMode.opening &&
          (!recording.fourTakbirsReviewed ||
              recording.openingStartMs < 0 ||
              recording.openingEndMs <= recording.openingStartMs ||
              recording.openingEndMs > recording.durationMs)) {
        throw const PrayerException(PrayerFailure.audioUnavailable);
      }
      final file = await downloads.prepareFull(recording);
      if (token != _generation) return;
      final uri = await downloads.files.playableUri(file);
      if (token != _generation) {
        downloads.files.release(uri);
        return;
      }
      await _serial(() async {
        if (token != _generation) {
          downloads.files.release(uri);
          return;
        }
        _uri = uri;
        await pauseMemorization();
        if (token != _generation) return;
        await pauseQuran();
        if (token != _generation) return;
        await playback
            .load(
              uri,
              start: mode == AthanMode.opening
                  ? Duration(milliseconds: recording.openingStartMs)
                  : null,
              end: mode == AthanMode.opening
                  ? Duration(milliseconds: recording.openingEndMs)
                  : null,
            )
            .timeout(const Duration(seconds: 15));
        if (token != _generation) return;
        if (reminder != null) {
          if (!isCurrent(reminder) ||
              !await claimStart(reminder) ||
              token != _generation) {
            if (token == _generation) {
              await playback.stop();
              _release();
              _event = null;
            }
            return;
          }
          final key = '${reminder.generation}:${reminder.eventId}';
          _started.add(key);
          if (_started.length > 192) _started.remove(_started.first);
        }
        if (token == _generation) await playback.play();
      });
    } on Object {
      if (token == _generation) {
        await playback.stop();
        _release();
        _event = null;
        throw const PrayerException(PrayerFailure.audioUnavailable);
      }
    }
  }

  @override
  Future<void> stop() async {
    ++_generation;
    final event = _event;
    _event = null;
    // Stop never waits for a pending download or load to complete.
    await playback.stop();
    _release();
    if (event != null) await cancelEvent(event);
  }
}
