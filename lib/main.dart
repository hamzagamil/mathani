import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/l10n/app_localizations.dart';
import 'data/quran_repository.dart';
import 'data/user_repository.dart';
import 'features/memorization/asr_model.dart';
import 'features/memorization/memorization_controller.dart';
import 'features/mutashabihat/mutashabihat_loader.dart';
import 'features/onboarding/onboarding_controller.dart';
import 'features/prayer_times/prayer_alerts.dart';
import 'features/prayer_times/prayer_repository.dart';
import 'features/recitation/ayah_fetcher.dart';
import 'features/recitation/media_handler.dart';
import 'features/recitation/recitation_controller.dart';
import 'features/settings/about_section.dart';
import 'platform/database.dart';
import 'shared/reader_state.dart';

Future<void> main() => runMathani();

/// Opens the databases and starts the app, on phones and in browsers (specs/008).
Future<void> runMathani() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAssetLicences(); // lazy: the files are read only when the licences page opens
  await initDatabases();
  // Both databases open in parallel on phones; no network and no background work at startup. In
  // browsers they open one at a time, and the Quran database is fetched only on a first visit or
  // a new version (specs/008 research R4). The Mutashabihat content file loads alongside them, so
  // linked ayat are coloured on the first page (specs/010 research R3).
  final similarLoad = loadMutashabihat();
  final (quran, user) = parallelDatabaseOpen
      ? await (QuranRepository.open(), UserRepository.open()).wait
      : (await QuranRepository.open(), await UserRepository.open());
  final (anchor, preferences) = await user.loadStartup();
  final controller = ReaderController(
    quran: quran,
    user: user,
    anchor: anchor,
    preferences: preferences,
    similar: await similarLoad,
  );
  // Recitations (specs/004): nothing here touches the network, audio or disk before the first
  // frame; the fetcher and player start on the first play.
  final recitation = RecitationController(
    reader: controller,
    fetcher: AyahFetcher(
      recordingSize: (r, s, a) async => (await quran.recordingBytes(r, s))[a - 1],
      // Reciters recorded one surah per file: each ayah is a byte range of it (specs/006 R18).
      clipRange: (r, s, a) async {
        final clip = await quran.clipRange(r, s, a);
        final total = await quran.surahFileBytes(r, s);
        return clip == null || total == null ? null : (start: clip.$1, end: clip.$2, total: total);
      },
    ),
  );
  // Lock screen and notification controls start with the first recitation, not at launch.
  recitation.onFirstPlay = () => RecitationMediaHandler.start(recitation);
  // First run, or the first launch after updating from 1.3.0: the onboarding (specs/005).
  final onboarding =
      OnboardingController(reader: controller, recitation: recitation, hasMemorize: true);
  // Memorization (specs/006): nothing is loaded until a session starts.
  final memorization = MemorizationController(reader: controller, recitation: recitation);
  // Prayer times (specs/009): idle until after the first frame, then alerts are refilled on
  // every start and resume, so they keep working for readers who never open Prayer Times (R11).
  final prayer = PrayerAlerts(
    store: UserPrayerStateStore(user),
    l10n: () => lookupAppLocalizations(MathaniApp.resolveLocale(
        controller.preferences.language, PlatformDispatcher.instance.locales)),
    pauseQuran: recitation.pause,
    pauseMemorization: memorization.pause,
  );
  AppLifecycleListener(
    onResume: () => unawaited(prayer.onAppActive()),
    onHide: prayer.onAppInactive,
  );
  runApp(MathaniApp(
    controller: controller,
    recitation: recitation,
    onboarding: onboarding,
    memorization: memorization,
    prayer: prayer,
  ));
  // After updating, the previous recognition model's files are freed without waiting for
  // memorization to open; after the first frame, so cold start is unchanged (specs/007 FR-004).
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(AsrModel.removeOtherVersions());
    unawaited(prayer.onAppActive());
  });
}
