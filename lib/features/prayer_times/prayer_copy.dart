import '../../app/l10n/app_localizations.dart';
import 'athan_catalogue.dart';
import 'prayer_models.dart';
import 'prayer_services.dart';

/// A prayer's name; on Fridays at the place, Dhuhr is Jumu'ah (specs/015 FR-001, FR-002).
String prayerName(AppLocalizations l, PrayerKind kind, {bool friday = false}) =>
    switch (kind) {
      PrayerKind.fajr => l.prayerFajr,
      PrayerKind.sunrise => l.prayerSunrise,
      PrayerKind.dhuhr => friday ? l.prayerJumuah : l.prayerDhuhr,
      PrayerKind.asr => l.prayerAsr,
      PrayerKind.maghrib => l.prayerMaghrib,
      PrayerKind.isha => l.prayerIsha,
      PrayerKind.qiyam => l.prayerQiyam,
      PrayerKind.jumuah => l.prayerJumuahReminder,
      PrayerKind.duha => l.prayerDuha,
    };

String prayerMethodName(AppLocalizations l, PrayerMethod method) =>
    switch (method) {
      PrayerMethod.muslimWorldLeague => l.prayerMethodMwl,
      PrayerMethod.egyptian => l.prayerMethodEgypt,
      PrayerMethod.ummAlQura => l.prayerMethodMakkah,
      PrayerMethod.karachi => l.prayerMethodKarachi,
      PrayerMethod.isna => l.prayerMethodNorthAmerica,
      PrayerMethod.dubai => l.prayerMethodDubai,
      PrayerMethod.kuwait => l.prayerMethodKuwait,
      PrayerMethod.qatar => l.prayerMethodQatar,
      PrayerMethod.singapore => l.prayerMethodSingapore,
      PrayerMethod.turkey => l.prayerMethodTurkey,
      PrayerMethod.moonsightingCommittee => l.prayerMethodMoonsighting,
    };

String prayerAsrName(AppLocalizations l, AsrSetting asr) => switch (asr) {
  AsrSetting.standard => l.prayerAsrStandard,
  AsrSetting.hanafi => l.prayerAsrHanafi,
};

String prayerRuleName(AppLocalizations l, HighLatitudeRule rule) =>
    switch (rule) {
      HighLatitudeRule.middleOfNight => l.prayerMiddleNight,
      HighLatitudeRule.seventhOfNight => l.prayerSeventhNight,
    };

String prayerFailureMessage(AppLocalizations l, PrayerFailure reason) =>
    switch (reason) {
      PrayerFailure.locationDenied => l.prayerLocationDenied,
      PrayerFailure.locationUnavailable => l.prayerLocationUnavailable,
      PrayerFailure.timezoneUnresolved => l.prayerTimezoneUnavailable,
      PrayerFailure.providerUnavailable => l.prayerServiceUnavailable,
      PrayerFailure.offline => l.prayerOffline,
      PrayerFailure.rateLimited => l.prayerRateLimited,
      PrayerFailure.calculationUnavailable ||
      PrayerFailure.conventionOutOfRange => l.prayerCalculationUnavailable,
      PrayerFailure.audioUnavailable => l.prayerAudioFailed,
      PrayerFailure.notificationsDenied => l.prayerNotificationsDenied,
    };

/// A sound's name in the sound list.
String prayerSoundName(
  AppLocalizations l,
  AthanCatalogue catalogue,
  String sound,
) => switch (sound) {
  toneSound => l.prayerSoundTone,
  silentSound => l.prayerSoundSilent,
  _ =>
    catalogue.byId(sound)?.name(arabic: l.localeName == 'ar') ??
        l.prayerSoundTone,
};

/// Android notification channel names, one per sound (contracts › Android).
Map<String, String> prayerChannelNames(
  AppLocalizations l,
  AthanCatalogue catalogue,
) => {
  for (final sound in catalogue.soundChoices)
    sound: l.prayerChannelSound(prayerSoundName(l, catalogue, sound)),
  // The reminders' channel: Qiyam, Jumu'ah and Duha (specs/015 R3).
  'qiyam': l.prayerChannelQiyam,
  'playback': l.prayerChannelAthan,
  'stop': l.prayerAthanStop,
};

/// An offset with its sign, e.g. `+5` or `−10`.
String signedMinutes(int minutes) => minutes > 0
    ? '+$minutes'
    : minutes < 0
    ? '−${-minutes}'
    : '0';
