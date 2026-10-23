// Lock screen, notification, headset and car controls for the recitation (specs/004
// contracts/recitation-playback.md › System media controls; research R4). Every system command
// goes through RecitationController, so next/previous follow the ayah order, not the player's
// short window.
import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../../app/app.dart';
import '../../app/l10n/app_localizations.dart';
import 'recitation_bar.dart';
import 'recitation_controller.dart';

/// Android notification channel for the player.
const recitationChannelId = 'app.mathani.recitation';

class RecitationMediaHandler extends BaseAudioHandler {
  RecitationMediaHandler(this.recitation, {this.artUri}) {
    recitation.addListener(_sync);
    _sync();
  }

  final RecitationController recitation;

  /// The app icon as a local file, shown on the lock screen and in the notification.
  final Uri? artUri;

  /// Interface strings in the app's current language (the user's choice, or the device's).
  AppLocalizations get _l10n => lookupAppLocalizations(MathaniApp.resolveLocale(
      recitation.reader.preferences.language, PlatformDispatcher.instance.locales));

  void _sync() {
    final s = recitation.session;
    if (s == null) {
      playbackState.add(PlaybackState(processingState: AudioProcessingState.idle));
      return;
    }
    final l10n = _l10n;
    final arabic = l10n.localeName == 'ar';
    mediaItem.add(MediaItem(
      id: '${s.reciter.id}/${s.item}',
      title: s.status == RecitationStatus.ended
          ? l10n.recitationEnded
          : RecitationBar.itemText(l10n, recitation, s.item, arabic: arabic),
      artist: s.reciter.name(arabic: arabic),
      album: l10n.appName,
      artUri: artUri,
    ));
    final playing = s.status == RecitationStatus.playing || s.status == RecitationStatus.loading;
    playbackState.add(PlaybackState(
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
        RecitationStatus.playing || RecitationStatus.paused => AudioProcessingState.ready,
        RecitationStatus.error => AudioProcessingState.error,
        RecitationStatus.ended => AudioProcessingState.completed,
      },
      errorMessage: s.status == RecitationStatus.error
          ? (s.error?.name == 'offline' ? l10n.recitationOffline : l10n.recitationFetchFailed)
          : null,
    ));
  }

  @override
  Future<void> play() async => recitation.resume();

  @override
  Future<void> pause() async => recitation.pause();

  @override
  Future<void> skipToNext() async => recitation.next();

  @override
  Future<void> skipToPrevious() async => recitation.previous();

  @override
  Future<void> stop() => recitation.stop();

  void dispose() => recitation.removeListener(_sync);

  /// Starts the system media session. Called on the first play only, never at app start
  /// (Principle III). If the platform side is unavailable, playback still works in the app.
  static Future<void> start(RecitationController recitation) async {
    Uri? art;
    try {
      final file = File('${(await getApplicationCacheDirectory()).path}/recitation_art.png');
      if (!await file.exists()) {
        final data = await rootBundle.load('assets/images/mark_navy.png');
        await file.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      }
      art = file.uri;
    } on Object {
      art = null; // no artwork: the notification still works
    }
    try {
      await AudioService.init(
        builder: () => RecitationMediaHandler(recitation, artUri: art),
        config: AudioServiceConfig(
          androidNotificationChannelId: recitationChannelId,
          androidNotificationChannelName: lookupAppLocalizations(MathaniApp.resolveLocale(
                  recitation.reader.preferences.language, PlatformDispatcher.instance.locales))
              .recitationChannel,
          androidNotificationIcon: 'drawable/ic_stat_recitation',
          androidStopForegroundOnPause: true,
        ),
      );
    } on Object {
      // Tests, the browser preview, or a platform without the service: in-app playback only.
    }
  }
}
