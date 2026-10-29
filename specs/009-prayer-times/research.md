# Research: Prayer Times and Athan Notifications

**Date**: 2026-10-29 | **Feature**: [spec.md](./spec.md)

Research combined repository inspection with two parallel research assignments: calculation/location providers and notification/audio platform behaviour. Decisions below resolve the technical unknowns. Physical-device outcomes, asset inspection and deployment configuration are validation work, not claims of completed verification.

## R1. Existing architecture and integration

**Decision**: Feature-local ChangeNotifier controller/repository, Material routes and the existing conditional platform facades. Add Prayer Times to the reader navigation sheet; keep Quran startup/home unchanged. Extend the single RecitationMediaHandler to route Quran and athan commands.

**Rationale**: `lib/main.dart`, `lib/app/app.dart`, `lib/features/reader/reader_screen.dart`, `lib/data/user_repository.dart` and `lib/features/recitation/media_handler.dart` already establish these patterns. Existing SQLite is plaintext, and existing just_audio interruption handling does not prove notification audio always pauses Quran.

**Alternatives considered**: New state management/router, separate media service and migration of all user data: unnecessary scope and regression risk.

## R2. Offline calculations

**Decision**: Pin adhan_dart 2.0.1. The adapter owns stable app method IDs, four madhhab labels, explicit high-latitude selection and nullable/unavailable results. Preserve preset offsets. Hanafi maps to its Hanafi Asr convention; the other three labels map to its Shafi convention. Use unresolved polar handling; do not silently substitute another date or location.

**Rationale**: A small pure-Dart calculator avoids sending saved coordinates to a calculation server. Five required methods are represented by its presets. Package failures/nonfinite values become domain unavailability, not midnight times.

**Alternatives considered**: Aladhan network calculations add offline/privacy dependencies; hand-written astronomy duplicates maintained work. Source: [package and presets](https://pub.dev/packages/adhan_dart), [manifest](https://raw.githubusercontent.com/prayer-timetable/adhan_dart/master/pubspec.yaml), [parameters](https://raw.githubusercontent.com/prayer-timetable/adhan_dart/master/lib/src/CalculationParameters.dart), [license](https://pub.dev/packages/adhan_dart/license).

## R3. Dates, Ramadan and reference results

**Decision**: Pin timezone 0.11.2, use the full IANA database lazily, and store zone IDs rather than offsets. Construct the schedule's calendar date in its zone, pass its date components to the calculator, normalize returned instants to UTC, and render through that zone. Never substitute the device zone. Qiyam is Maghrib + two thirds of elapsed UTC duration to next-day Fajr, not the package's convenience night interval.

**Rationale**: Location time zones and DST require date-dependent rules. Include all IANA names returned by location providers. [Timezone publisher documentation](https://pub.dev/packages/timezone).

**Decision**: Complete the Umm al-Qura convention by adding 30 minutes to its base 90-minute Isha during Ramadan. Generate a compact, versioned Ramadan start/end table from pinned MIT-licensed HijriDate 2.6.0 month data during asset preparation; ship only interval data and its notice, no Python runtime. Determine the Islamic evening by the civil date after Maghrib: the evening preceding Ramadan day 1 is included and the evening preceding Shawwal day 1 is excluded. Require explicit table coverage for every scheduled date; outside coverage mark that method unavailable rather than guess. Verify first/last Ramadan evenings against reviewed calendar references.

**Alternatives considered**: Forgetting the Ramadan extension produces a known wrong convention; adding a large calendar/UI package is unnecessary for two boundaries per year. Sources: [Umm al-Qura preset note](https://pub.dev/packages/adhan_dart), [HijriDate source, version and MIT license](https://github.com/dralshehri/hijridate), [calendar documentation](https://hijridate.readthedocs.io/).

**Decision**: Freeze independently reviewed fixtures from PrayTimes for ten cities with matched angles, offsets, shadow factors, rounding and high-latitude policies. Record reference version, convention, calendar and provenance with each fixture. Use Cairo, Makkah, Karachi, London, Oslo, New York, Los Angeles, Singapore, Jakarta and Sydney, plus polar unavailable cases. Cover DST, Ramadan boundaries and after-Isha rollover. Do not derive expected values using the production Dart adapter itself.

**Rationale**: Agreement with a mosque timetable with unknown settings cannot establish SC-002. [PrayTimes calculation definitions](https://praytimes.org/calculation), [reference implementation manual](https://praytimes.org/manual).

## R4. Device, manual and IP location

**Decision**: Pin geolocator 14.0.1 for one foreground position request with timeout and denied/permanently-denied handling. No streams, background permission or always authorization. Keep actual detected coordinates when resolving a nearby city; do not replace them with that city's centroid.

**Rationale**: Platform permission differences belong in a maintained plugin. Device access and online place/timezone resolution are separate steps and failures. [Geolocator documentation](https://pub.dev/packages/geolocator), [manifest](https://raw.githubusercontent.com/Baseflow/flutter-geolocator/main/geolocator/pubspec.yaml).

**Decision**: GeoNames via bounded Pages endpoints supplies manual city search, nearby place names and IANA time zones. Use HTTPS searchJSON, findNearbyPlaceNameJSON and timezoneJSON with a real enabled GEONAMES_USERNAME, never demo. Disclose coordinate sharing for explicit device-place resolution. Retain confirmed results with attribution; free quotas require debouncing, limits and retry handling. The published account allowance is 10,000 daily and 1,000 hourly credits; premium capacity can be configured without redesign.

**Alternatives considered**: Open-Meteo's free tier is noncommercial; ipapi.co retention limits conflict with saved places; a global gazetteer increases download size. Sources: [GeoNames commercial usage/data terms](https://www.geonames.org/export/), [service contracts](https://www.geonames.org/export/web-services.html), [Open-Meteo pricing](https://open-meteo.com/en/pricing), [ipapi.co terms](https://ipapi.co/terms/).

**Decision**: Optional IP approximation uses the existing Cloudflare Pages host's request.cf metadata. Return only available location fields, label approximate and require confirmation. Missing metadata yields unavailable/manual selection. No external IP vendor or raw IP forwarding is needed. Return no-store responses; do not log personal values or store them at the server. Disable/redact application observability for these endpoints; do not promise that Cloudflare has no infrastructure retention.

**Rationale**: Pages Functions receive a Workers Request with geo metadata, which may be missing locally or in previews. Three narrow functions fit the existing deployment. Route only /api/prayer-* through Functions; static assets bypass them. Functions share Workers usage limits, so rates and provider errors must remain recoverable. Sources: [Pages API](https://developers.cloudflare.com/pages/functions/api-reference/), [Request metadata](https://developers.cloudflare.com/workers/runtime-apis/request/), [pricing](https://developers.cloudflare.com/pages/functions/pricing/), [logs](https://developers.cloudflare.com/workers/observability/logs/workers-logs/).

## R5. Notification capability and horizons

**Decision**: Pin flutter_local_notifications 22.3.3 for system alerts, authorization and pending-request management. iOS schedules the next 60 events total (roughly ten days at six per day); show scheduled-through and refill on launch/resume/settings change. Do not rely on discretionary background refresh for indefinite coverage. Android keeps a bounded 30-day horizon, restoring future alarms on reboot/clock changes and refilling on normal app reconciliation. Never replay missed events.

**Rationale**: The plugin's documented requirements fit API24/iOS15/Flutter3.47 and its iOS pending-request limit is 64. It does not automatically invoke Dart on notification delivery. [Pinned version documentation](https://pub.dev/packages/flutter_local_notifications/versions/21.0.0), [publisher changelog](https://pub.dev/packages/flutter_local_notifications/changelog), [Apple background scheduling discretion](https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate).

**Decision**: iOS opening clips must contain all four initial takbirs and be under 30 seconds in supported CAF encoding. System-owned notification playback works without the app but cannot play a complete multi-minute athan or offer reliable application Stop/pause-Quran control. Full playback is foreground or user-initiated after opening the app; do not simulate it with chained notifications or silent audio. Track P01/P02. If an authentic opening clip exceeds the limit, that recording is not eligible for iOS opening mode.

**Rationale**: Native notification delivery is not a general background Dart execution hook. Test actual interaction with active Quran audio; do not claim absolute nonoverlap for system-owned audio. Sources: [Apple notification sound](https://developer.apple.com/documentation/usernotifications/unnotificationsound), [delivery lifecycle](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app).

**Decision**: Web provides schedules, setup, previews and in-page reminders while execution/audio permission permits. No closed-page or suspended-page precise timer/custom athan promise; no new push backend. React to autoplay rejection with a Play action. Track P03.

**Alternatives considered**: Service workers are event-driven, not durable timers; Web Push still cannot promise custom full athan and adds subscriptions/server retention. Sources: [Notifications standard](https://notifications.spec.whatwg.org/), [service worker lifecycle](https://chromium.googlesource.com/chromium/src/+/main/docs/security/service-worker-security-faq.md), [autoplay](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay).

## R6. Android full athan and audio ownership

**Decision**: A native exact-alarm receiver validates a generation/event token and invokes the existing single audio_service handler through a media-browser/controller custom action. Handler initialization must work without an Activity and without opening the Quran databases first. Persist the pending command until acknowledgement. Pause Quran and stop previews before athan; expose Stop and require user action to resume Quran. Foreground delivery suppresses OS sound to avoid double playback.

**Rationale**: The upstream service creates a Flutter engine and routes custom media actions; arbitrary Intent extras do not invoke Dart playback. This architecture is a design inference, not proof of successful headless delivery. G01 must establish cold-engine promotion/acknowledgement before Android full mode is enabled. No second player service. [AudioService source](https://raw.githubusercontent.com/ryanheise/audio_service/minor/audio_service/android/src/main/java/com/ryanheise/audioservice/AudioService.java), [plugin queue/handler source](https://raw.githubusercontent.com/ryanheise/audio_service/minor/audio_service/android/src/main/java/com/ryanheise/audioservice/AudioServicePlugin.java).

**Decision**: Use user-granted SCHEDULE_EXACT_ALARM with capability checks, not policy-limited USE_EXACT_ALARM. Ask POST_NOTIFICATIONS contextually on API33+. Exact user-requested alarms can qualify for foreground-service startup; boot restores alarms and never immediately starts media. Respect channels, silent modes and force-stop behaviour. Use bounded catalogue-specific channels for fallback sounds; do not recreate channels to override user choices. If exact access is denied, offer clearly labelled approximate short notifications or disable precise mode, never claim SC-004 timing.

**Sources**: [alarms](https://developer.android.com/develop/background-work/services/alarms), [foreground startup exemptions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start), [media service restrictions](https://developer.android.com/develop/background-work/services/fgs/service-types#media), [notification permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission), [channels](https://developer.android.com/develop/ui/compose/notifications/channels).

## R7. Licensed recordings

**Decision (updated 2026-10-29)**: The user rejected Beautiful adhan and the Madinah recording and requested Egyptian recordings. Current review candidates are Al-Hussary and El-Minshawi from Assabile. The user selected Al-Hussary and supplied `0:12`; this was interpreted back as the opening interval 0:00–0:12. Source hashes and the review decision are in `tool/prayer/athan_sources.json` and `athan_review.json`. El-Minshawi remains unapproved. Redistribution rights for both Egyptian recordings remain unverified; neither may enter the production catalogue or hosted assets yet. Preserve source revisions, attribution, rights evidence and transformation hashes. Human listening must verify complete athan, exact four-takbir cuts, clean playback and suitability; metadata alone is not an audio audit.

**Rationale**: User suitability review supersedes the original candidate choice. Local preparation can support review without implying redistribution permission. Full files will be downloaded on selection from a project-controlled host only after clearance; small eligible opening clips and a generated Qiyam tone form the bounded bundle. G02 blocks release until two suitable complete recordings/clips and their redistribution permission are verified. Never cut spoken phrases to meet iOS limits.

**Alternatives considered**: Unlicensed celebrity recordings; runtime hotlinks to mutable third-party audio; bundling every full recording. Sources: [Beautiful adhan source/license](https://commons.wikimedia.org/wiki/File:Beautiful_adhan.ogg), [Madinah source/license](https://commons.wikimedia.org/wiki/File:33937_ejaz215_call-to-prayer-from-the-prophet-s-mo.ogg).

## R8. Sensitive persistence

**Decision**: Pin flutter_secure_storage 10.3.4 for a small versioned prayer snapshot. Phones use native protected storage without biometrics that would prevent routine reminder recovery. Keep coordinates/names out of plaintext SQLite and native alarm payloads. Exclude encrypted native preferences and audio from inappropriate backups; do not destroy unrelated reader data on a prayer-store error.

**Rationale**: Its Android minimum is below the app's API24 floor; the 10.x line avoids the newer major's toolchain uplift. Its web storage uses encrypted browser-local data and is explicitly experimental, not equivalent to native protected storage. Track P05; use HTTPS, hardened headers and no hard-coded browser secret, and disable persistence if crypto fails. Prefer a this-device-only iOS accessibility configuration suitable after first unlock. Clear both Dart and native prayer state on deletion.

**Alternatives considered**: Plaintext SQLite locations or a whole-database encryption migration. Sources: [pinned package](https://pub.dev/packages/flutter_secure_storage/versions/10.3.4), [10.3.4 changelog](https://pub.dev/packages/flutter_secure_storage/versions/10.3.4/changelog).

## R9. Dependency and size ledger

These are incremental design allowances, not measured download deltas. Report actual Android/iOS compressed growth and explain >1 MB in review. Include all transitive licenses. Remove any allowance's unused components rather than shipping speculative code.

| Addition | Why existing code/platform alone is insufficient | Incremental allowance |
| --- | --- | --- |
| adhan_dart 2.0.1, MIT | Offline astronomy and conventions; no implementation exists | <150 KB compiled code target; measure |
| timezone 0.11.2, BSD-2-Clause | IANA rules for arbitrary saved places; fixed offsets fail DST | <=1 MB database/code allowance; lazy load; measure full database |
| geolocator 14.0.1, MIT | Reliable one-shot permissions and position across platforms | <=500 KB plugin/transitives allowance; measure |
| flutter_local_notifications 22.3.3, BSD-3-Clause | Native notification lifecycle/permission/scheduling integration | <=1 MB native/transitive allowance; measure release shrinking |
| flutter_secure_storage 10.3.4, BSD-3-Clause | Sensitive location retention; user.db is plaintext | <=500 KB native/transitive allowance; measure |
| Two short clips and Qiyam tone | Offline system sounds cannot fetch remote audio at delivery | <=1 MB aggregate target; if exceeded, record why, never truncate words |
| Ramadan table, MIT source notice | Correct selected convention at seasonal boundary | <10 KB target; build-time derivation only |

Reuse existing audio/http/crypto/FileStore packages. A geocoding plugin, external IP SDK, push service, full calendar framework, general background task runner and second audio service are unnecessary.

## Resolution status

All research decisions are resolved and carried into the plan/model/contracts. G01-G05 in follow-ups are objective implementation/release acceptance gates. No credentials were read, accounts created, audio downloaded, production endpoints deployed or platform results fabricated during planning.
