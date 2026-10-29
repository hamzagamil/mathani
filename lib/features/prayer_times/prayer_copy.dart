import '../../app/l10n/app_localizations.dart';
import 'prayer_models.dart';
import 'prayer_services.dart';

String prayerName(AppLocalizations l, PrayerKind kind) => switch (kind) {
  PrayerKind.fajr => l.prayerFajr,
  PrayerKind.sunrise => l.prayerSunrise,
  PrayerKind.dhuhr => l.prayerDhuhr,
  PrayerKind.asr => l.prayerAsr,
  PrayerKind.maghrib => l.prayerMaghrib,
  PrayerKind.isha => l.prayerIsha,
  PrayerKind.qiyam => l.prayerQiyam,
};
String prayerMethodName(AppLocalizations l, PrayerMethod method) =>
    switch (method) {
      PrayerMethod.muslimWorldLeague => l.prayerMethodMwl,
      PrayerMethod.egyptian => l.prayerMethodEgypt,
      PrayerMethod.karachi => l.prayerMethodKarachi,
      PrayerMethod.ummAlQura => l.prayerMethodMakkah,
      PrayerMethod.northAmerica => l.prayerMethodNorthAmerica,
    };
String prayerFailureMessage(AppLocalizations l, PrayerFailure reason) =>
    switch (reason) {
      PrayerFailure.locationDenied => l.prayerLocationDenied,
      PrayerFailure.locationUnavailable => l.prayerLocationUnavailable,
      PrayerFailure.timezoneUnresolved => l.prayerTimezoneUnavailable,
      PrayerFailure.offline => l.prayerOffline,
      PrayerFailure.secureStorageUnavailable => l.prayerStorageUnavailable,
      PrayerFailure.needsAttention => l.prayerNeedsAttention,
      PrayerFailure.calculationUnavailable ||
      PrayerFailure.conventionOutOfRange => l.prayerCalculationUnavailable,
      _ => l.prayerServiceUnavailable,
    };
String prayerMadhhabName(AppLocalizations l, PrayerMadhhab madhhab) =>
    switch (madhhab) {
      PrayerMadhhab.hanafi => l.prayerHanafi,
      PrayerMadhhab.shafii => l.prayerShafii,
      PrayerMadhhab.maliki => l.prayerMaliki,
      PrayerMadhhab.hanbali => l.prayerHanbali,
    };
