import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/l10n/app_localizations.dart';
import 'data/quran_repository.dart';
import 'data/user_repository.dart';
import 'features/khatma/group/group_client.dart';
import 'features/khatma/group/group_controller.dart';
import 'features/khatma/group/group_repository.dart';
import 'features/khatma/khatma_controller.dart';
import 'features/khatma/khatma_reminders.dart';
import 'features/khatma/khatma_repository.dart';
import 'features/memorization/asr_model.dart';
import 'features/memorization/memorization_controller.dart';
import 'features/mutashabihat/mutashabihat_loader.dart';
import 'features/mutashabihat/mutashabihat_updater.dart';
import 'features/onboarding/onboarding_controller.dart';
import 'features/prayer_times/prayer_alerts.dart';
import 'features/prayer_times/prayer_repository.dart';
import 'features/recitation/ayah_fetcher.dart';
import 'features/recitation/media_handler.dart';
import 'features/recitation/recitation_controller.dart';
import 'features/settings/about_section.dart';
import 'platform/api_base.dart';
import 'platform/database.dart';
import 'platform/device.dart';
import 'platform/key_store.dart';
import 'platform/khatma_reminders.dart';
import 'shared/numerals.dart';
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
      OnboardingController(
      reader: controller, recitation: recitation, hasMemorize: true, hasKhatma: true);
  // Memorization (specs/006): nothing is loaded until a session starts.
  final memorization = MemorizationController(reader: controller, recitation: recitation);
  // The khatma (specs/014): idle until after the first frame, then it reads its own tables
  // (FR-039, research R10).
  final khatma = KhatmaController(
    repository: KhatmaRepository.of(user),
    reader: controller,
    isMemorizing: () => memorization.active,
  );
  AppLocalizations l10n() => lookupAppLocalizations(MathaniApp.resolveLocale(
      controller.preferences.language, PlatformDispatcher.instance.locales));
  // Its daily reminder (specs/014 research R8): rebuilt after the first frame, on resume and
  // after every change.
  final reminders = KhatmaReminders(
    khatma: khatma,
    platform: khatmaReminderPlatform(channelName: () => l10n().khatmaReminder),
    l10n: l10n,
  );
  // Group khatmas (specs/014 release B): local copies load after the first frame; no request
  // is made unless the reader keeps one or opens one (FR-054, SC-012).
  final groups = GroupController(
    client: GroupClient(base: apiBase(), keys: keyStore(user)),
    repository: GroupRepository(user),
    khatma: khatma,
    keepBrowserData: const DeviceChannel().keepBrowserData,
  );
  reminders.heldParts = () {
    final strings = l10n();
    return [
      for (final p in groups.heldUnread)
        HeldPartReminder(
          title: p.title,
          partName: p.division == 30
              ? strings.juzLabel(formatNumber(p.n, Locale(strings.localeName)))
              : strings.khatmaHizb(formatNumber(p.n, Locale(strings.localeName))),
        ),
    ];
  };
  groups.addListener(reminders.sync);
  // Prayer times (specs/009): idle until after the first frame, then alerts are refilled on
  // every start and resume, so they keep working for readers who never open Prayer Times (R11).
  final prayer = PrayerAlerts(
    store: UserPrayerStateStore(user),
    l10n: () => lookupAppLocalizations(MathaniApp.resolveLocale(
        controller.preferences.language, PlatformDispatcher.instance.locales)),
    pauseQuran: recitation.pause,
    pauseMemorization: memorization.pause,
  );
  // Mutashabihat content updates (specs/011 R5): after the first frame and on resume, at most
  // every 6 hours, never blocking reading.
  final mutashabihat = MutashabihatUpdater(reader: controller);
  AppLifecycleListener(
    onResume: () {
      unawaited(prayer.onAppActive());
      unawaited(reminders.sync());
      unawaited(mutashabihat.check());
    },
    onHide: prayer.onAppInactive,
  );
  runApp(MathaniApp(
    controller: controller,
    recitation: recitation,
    onboarding: onboarding,
    memorization: memorization,
    prayer: prayer,
    khatma: khatma,
    reminders: reminders,
    groups: groups,
  ));
  // After updating, the previous recognition model's files are freed without waiting for
  // memorization to open; after the first frame, so cold start is unchanged (specs/007 FR-004).
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(AsrModel.removeOtherVersions());
    unawaited(khatma.load().then((_) => groups.load()).then((_) => reminders.start()));
    unawaited(prayer.onAppActive());
    unawaited(mutashabihat.check());
  });
}
