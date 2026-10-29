// Lock screen, notification, headset and car controls for the recitation (specs/004
// contracts/recitation-playback.md › System media controls; research R4). Every system command
// goes through RecitationController, so next/previous follow the ayah order, not the player's
// short window.
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart'
    show rootBundle, MethodChannel, MissingPluginException;
import 'package:just_audio/just_audio.dart' as audio;

import '../../app/app.dart';
import '../../app/l10n/app_localizations.dart';
import '../../data/models.dart' show LanguagePref;
import '../../platform/file_store.dart';
import 'recitation_bar.dart';
import 'recitation_controller.dart';

/// Android notification channel for the player.
const recitationChannelId = 'app.mathani.recitation';
const prayerAlarmSpikeEnabled =
    kDebugMode && bool.fromEnvironment('PRAYER_ALARM_SPIKE');
const prayerAlarmSpikeRoute = '/prayer-alarm-spike';

class RecitationMediaHandler extends BaseAudioHandler {
  RecitationMediaHandler(RecitationController? recitation, {this.artUri})
    : _recitation = recitation {
    recitation?.addListener(_sync);
    _sync();
  }

  RecitationController? _recitation;
  RecitationController get recitation => _recitation!;
  void attachRecitation(RecitationController controller, {Uri? artUri}) {
    _recitation?.removeListener(_sync);
    _recitation = controller;
    this.artUri = artUri;
    controller.addListener(_sync);
    _sync();
  }

  /// The app icon as a local file, shown on the lock screen and in the notification.
  Uri? artUri;
  static Future<RecitationMediaHandler>? _shared;
  static FutureOr<void> Function()? pauseMemorizationForPrayer;
  static const _spikeChannel = MethodChannel('app.mathani/prayer_alarm_spike');
  audio.AudioPlayer? _spikePlayer;
  bool _spikeActive = false;
  int _spikeGeneration = 0;
  Map<String, Object?>? _spikeEvent;
  Timer? _spikeStopTimer;

  /// Interface strings in the app's current language (the user's choice, or the device's).
  AppLocalizations get _l10n => lookupAppLocalizations(
    MathaniApp.resolveLocale(
      _recitation?.reader.preferences.language ?? LanguagePref.system,
      PlatformDispatcher.instance.locales,
    ),
  );

  void _sync() {
    if (_spikeActive) return;
    final s = _recitation?.session;
    if (s == null) {
      playbackState.add(
        PlaybackState(processingState: AudioProcessingState.idle),
      );
      return;
    }
    final l10n = _l10n;
    final arabic = l10n.localeName == 'ar';
    mediaItem.add(
      MediaItem(
        id: '${s.reciter.id}/${s.item}',
        title: s.status == RecitationStatus.ended
            ? l10n.recitationEnded
            : RecitationBar.itemText(l10n, recitation, s.item, arabic: arabic),
        artist: s.reciter.name(arabic: arabic),
        album: l10n.appName,
        artUri: artUri,
      ),
    );
    final playing =
        s.status == RecitationStatus.playing ||
        s.status == RecitationStatus.loading;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {MediaAction.stop},
        playing: playing,
        processingState: switch (s.status) {
          RecitationStatus.loading => AudioProcessingState.buffering,
          RecitationStatus.playing ||
          RecitationStatus.paused => AudioProcessingState.ready,
          RecitationStatus.error => AudioProcessingState.error,
          RecitationStatus.ended => AudioProcessingState.completed,
        },
        errorMessage: s.status == RecitationStatus.error
            ? (s.error?.name == 'offline'
                  ? l10n.recitationOffline
                  : l10n.recitationFetchFailed)
            : null,
      ),
    );
  }

  @override
  Future<void> play() async {
    if (!_spikeActive) _recitation?.resume();
  }

  @override
  Future<void> pause() async {
    if (_spikeActive) {
      await _stopSpike();
    } else {
      _recitation?.pause();
    }
  }

  @override
  Future<void> skipToNext() async {
    if (!_spikeActive) _recitation?.next();
  }

  @override
  Future<void> skipToPrevious() async {
    if (!_spikeActive) _recitation?.previous();
  }

  @override
  Future<void> stop() async {
    if (_spikeActive) {
      await _stopSpike();
    } else {
      await _recitation?.stop();
    }
  }

  void dispose() {
    _recitation?.removeListener(_sync);
    _spikeStopTimer?.cancel();
    if (_spikePlayer != null) unawaited(_spikePlayer!.dispose());
  }

  static Future<RecitationMediaHandler> _ensureHandler(
    RecitationController? recitation, {
    Uri? artUri,
  }) async {
    try {
      return await (_shared ??= AudioService.init<RecitationMediaHandler>(
        builder: () => RecitationMediaHandler(recitation, artUri: artUri),
        config: AudioServiceConfig(
          androidNotificationChannelId: recitationChannelId,
          androidNotificationChannelName: lookupAppLocalizations(
            MathaniApp.resolveLocale(
              recitation?.reader.preferences.language ?? LanguagePref.system,
              PlatformDispatcher.instance.locales,
            ),
          ).recitationChannel,
          androidNotificationIcon: 'drawable/ic_stat_recitation',
          androidStopForegroundOnPause: true,
        ),
      ));
    } on Object {
      _shared = null;
      rethrow;
    }
  }

  /// Only the opt-in G01 debug build starts this before opening reader databases.
  static Future<void> initializePrayerAlarmSpike() async {
    if (!prayerAlarmSpikeEnabled) return;
    final handler = await _ensureHandler(null);
    _spikeChannel.setMethodCallHandler((call) async {
      if (call.method != 'stopFromNative') throw MissingPluginException();
      await handler._stopSpike(cancelNative: false);
      return {'audioStopped': handler._spikePlayer?.playing != true};
    });
    await _spikeChannel.invokeMethod<void>('ready');
  }

  Future<void> _stopSpike({bool cancelNative = true}) async {
    ++_spikeGeneration;
    _spikeStopTimer?.cancel();
    _spikeStopTimer = null;
    final event = _spikeEvent;
    _spikeEvent = null;
    try {
      await _spikePlayer?.stop();
    } finally {
      _spikeActive = false;
      _sync();
      if (event != null && cancelNative) {
        await _spikeChannel.invokeMethod<bool>('cancel', event);
      }
    }
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (!prayerAlarmSpikeEnabled || name != 'prayerSpike') {
      return super.customAction(name, extras);
    }
    final id = extras?['eventId'], generation = extras?['generation'];
    if (id is! String || generation is! num || generation.toInt() < 0) {
      return {'state': 'rejected'};
    }
    if (_spikeEvent?['eventId'] == id &&
        _spikeEvent?['generation'] == generation.toInt()) {
      return {'state': 'duplicate'};
    }
    await _stopSpike();
    final token = ++_spikeGeneration;
    final event = <String, Object?>{
      'eventId': id,
      'generation': generation.toInt(),
    };
    _spikeEvent = event;
    try {
      final source = await _spikeChannel.invokeMethod<String>('source', event);
      if (source == null || token != _spikeGeneration) {
        return {'state': 'rejected'};
      }
      _spikeActive = true;
      await pauseMemorizationForPrayer?.call();
      _recitation?.pause();
      if (token != _spikeGeneration) return {'state': 'cancelled'};
      mediaItem.add(
        MediaItem(id: id, title: _l10n.prayerTimesTitle, album: _l10n.appName),
      );
      playbackState.add(
        PlaybackState(
          controls: [MediaControl.stop],
          systemActions: {MediaAction.stop},
          processingState: AudioProcessingState.loading,
          playing: true,
        ),
      );
      final player = _spikePlayer ??= audio.AudioPlayer();
      await player.setUrl(source).timeout(const Duration(seconds: 10));
      await player.setLoopMode(audio.LoopMode.one);
      if (token != _spikeGeneration ||
          await _spikeChannel.invokeMethod<bool>('claimStart', event) != true) {
        return {'state': 'cancelled'};
      }
      if (token != _spikeGeneration) return {'state': 'cancelled'};
      final playing = player.play();
      await Future.any<void>([
        playing,
        player.playingStream.firstWhere((value) => value).then<void>((_) {}),
      ]).timeout(const Duration(seconds: 2));
      if (!player.playing || token != _spikeGeneration) {
        return {'state': 'cancelled'};
      }
      playbackState.add(
        PlaybackState(
          controls: [MediaControl.stop],
          systemActions: {MediaAction.stop},
          processingState: AudioProcessingState.ready,
          playing: true,
        ),
      );
      await _spikeChannel.invokeMethod<bool>('ackStarted', event);
      _spikeStopTimer = Timer(
        const Duration(seconds: 20),
        () => unawaited(_stopSpike()),
      );
      return {'state': 'started', 'eventId': id};
    } on Object {
      await _stopSpike();
      return {'state': 'failed', 'eventId': id};
    } finally {
      if (token == _spikeGeneration && _spikePlayer?.playing != true) {
        _spikeActive = false;
        _sync();
      }
    }
  }

  /// Starts the system media session. Called on the first play only, never at app start
  /// (Principle III). If the platform side is unavailable, playback still works in the app.
  static Future<void> start(RecitationController recitation) async {
    Uri? art;
    try {
      final store = fileStore();
      const file = StoreFile(StoreRoot.cache, 'recitation_art.png');
      final data = await rootBundle.load('assets/images/mark_navy.png');
      if (await store.length(file) != data.lengthInBytes) {
        await store.delete(file);
        await store.append(
          file,
          Stream.value(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          ),
        );
      }
      art = await store.playableUri(file);
    } on Object {
      art = null; // no artwork: the notification still works
    }
    try {
      final handler = await _ensureHandler(recitation, artUri: art);
      handler.attachRecitation(recitation, artUri: art);
    } on Object {
      // Tests, or a platform without the service: in-app playback only.
    }
  }
}
