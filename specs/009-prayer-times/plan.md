# Implementation Plan: Prayer Times and Athan Notifications

**Branch**: `008-web-app` (actual Git branch) | **Feature ID**: `009-prayer-times` | **Date**: 2026-10-29 | **Spec**: [spec.md](./spec.md)

**Input**: `specs/009-prayer-times/spec.md`. `setup-plan.ps1 -Json` resolved this directory from `.specify/feature.json` and reported logical BRANCH `009-prayer-times`; `git branch --show-current` reports `008-web-app`. This workflow does not switch branches.

## Summary

Add a Prayer Times entry to the existing Settings screen reached from the reader toolbar, keeping the Mushaf as the home screen. A feature-local controller manages saved locations, local calculations, one active reminder location, athan settings and Qiyam. Reuse ChangeNotifier, Material routes, existing localization/themes and the single recitation audio service. Do not introduce a router, general state-management framework, account system or continuous location tracking.

Calculate offline using `adhan_dart` and IANA time zones. Use one-shot device position and explicit manual selection. Small Cloudflare Pages Functions on the existing web host normalize GeoNames city/time-zone lookups and expose optional confirmed approximate location from Cloudflare's request metadata. No prayer calculation server or external IP vendor is needed.

Use local notifications for short system alerts and Android exact alarms plus the existing audio handler for full athan. iOS full automatic background playback is unavailable; browser closed-page delivery is unavailable. These are explicit spec exceptions with tracked follow-ups, not capabilities to advertise. See [research](./research.md), [capability contract](./contracts/prayer-ui-and-reminders.md) and [follow-ups](./follow-ups.md).

**Notification increment (2026-10-30)**: Implement a separate native short-alert route before G01/G02-dependent full playback. Android AlarmManager receivers claim the protected queue and post OS notifications without creating a Flutter engine or media service. iOS uses the locked flutter_local_notifications API, future absolute UTC dates and verified pending requests. Daily standard sounds require explicit P06 acknowledgement; Qiyam has an original generated tone. G01 still blocks full Android playback and G02 still blocks recording assets. P07 documents that iOS cannot perform an application expiry check before a delayed OS-owned presentation. This route advances notifications without representing full/opening recitation as available.

## Technical Context

**Language/Version**: Dart 3.13.5 / Flutter 3.47.7 as pinned by pubspec.yaml; existing Kotlin/Java 17 Android and Swift iOS host code; JavaScript Pages Functions and Node built-in test runner for endpoint tests.

**Primary Dependencies**: Existing `http`, `intl`, `crypto`, `just_audio`, `audio_session`, `audio_service`, `path_provider`, `web`. Planned exact additions: `adhan_dart 2.0.1`, `timezone 0.11.2`, `geolocator 14.0.1`, `flutter_local_notifications 22.3.3`, `flutter_secure_storage 10.3.4`. Preserve locked platform transitive versions after solver/build checks. No runtime Hijri calendar dependency: generate a small attributed Ramadan interval table at build time (R3).

**Storage**: Dedicated, versioned encrypted prayer-preferences snapshot using Keychain/Keystore-backed secure storage; browser encrypted origin-local storage with the documented web exception. Keep precise locations out of existing plaintext user.db, alarm extras, logs and shared caches. Derived schedules are recomputed; audio uses FileStore, iOS notification clips are copied into Library/Sounds. Minimal native alarm recovery ledger excludes coordinates, names and IPs; protect any app-owned sensitive payload with platform secure storage. OS notification content is system-managed.

**Testing**: flutter_test calculation/contract/controller/widget tests; integration_test on devices; Node tests for endpoint normalization, validation and privacy headers; existing profile paging/startup checks and tool/size_check.dart. Notification timing requires physical devices, not just mocked callbacks.

**Target Platform**: iOS 15.0+, Android 7.0/API 24+ (existing targetSdk 36), existing supported web browsers from feature 008. Phone portrait first; existing centered web phone column retained.

**Project Type**: Existing single Flutter app, plus three bounded location endpoints deployed on the existing Cloudflare Pages project. No general backend or user database.

**Performance Goals**: <=2 s cold start on Galaxy A15 and iPhone SE (2nd gen); 60 fps; <=100 ms tap feedback. Lazy-initialize prayer storage, timezone database, plugins and audio after first frame or first feature use. No network/location prompt on cold start. Calculate only viewed and active-location horizons, not every saved place indefinitely.

**Constraints**: Offline schedules after confirmed setup; one active location; five independently enabled daily prayers; Qiyam off by default; two authentic, licensed recordings; timezone-based dates; no background location permission. Native notifications have finite horizons and user/system restrictions. Dependency size estimates are planning allowances, not measured binary claims.

**Scale/Scope**: Schedule, location search/list/editor, calculation sheet and reminder settings. At least three saved places supported; list virtualized. Global city search constrained by provider quotas; no country-wide catalogue download. Approximation is best-effort with manual fallback.

## Constitution Check

Pre-research review used constitution 2.0.0; design review repeated after research and contracts. All technical choices are resolved. Verification gates below are work required before release, not completed tests.

| Principle | Before research | After design |
| --- | --- | --- |
| I. Platform parity | Pass with FR-014/015/022 feasibility investigation required | Pass with justified exceptions P01-P04 recorded in spec and follow-ups: iOS system audio, browser background limits and finite scheduling horizon. Both mobile platforms retain schedules, choices and supported reminders. |
| II. Mobile first | Pass: reuse existing portrait UI | Pass: safe areas, minimum touch sizes, Arabic/English, dark mode, scaling and screen-reader scenarios in UI contract/quickstart. |
| III. Performance | Pass: no prayer work added before reader first frame | Pass by design: lazy services and bounded computation; startup/frame measurements remain release gates. |
| IV. Lean | Pass subject to dependency and asset research | Pass: each addition justified in R9; full audio on demand, bounded clip catalogue, no tracking/polling. Measure store deltas; >1 MB growth must be explained in review. |
| V. Simplicity | Pass: feature folder and existing controller pattern | Pass with justified location proxy and native alarm bridge below; no duplicate media service or storage framework. |
| Platform/privacy | Pass: in-context permissions and manual fallback | Pass with P05 browser storage exception. Precise saved locations encrypted on phones; coordinate resolution expressly disclosed; no location logging. |
| Workflow | Pass: specify then plan | Design complete; tasks and implementation come next. Physical iOS/Android, browser, timing, size and performance evidence are still required before merge. |

**Result**: design gate passes with the documented justified exceptions. No unresolved product questions or technology selections. Android headless playback, short-clip duration and provider preview checks are mandatory empirical acceptance gates; unsupported paths stay disabled if they fail.

## Project Structure

### Documentation (this feature)

```text
specs/009-prayer-times/
  spec.md
  plan.md
  research.md
  data-model.md
  quickstart.md
  follow-ups.md
  contracts/
    prayer-ui-and-reminders.md
    location-api.md
  checklists/requirements.md
```

`tasks.md` is produced by speckit-tasks, not this command.

### Source Code (repository root)

```text
lib/features/prayer_times/
  prayer_models.dart
  prayer_calculator.dart
  prayer_repository.dart
  prayer_controller.dart
  prayer_reminder_scheduler.dart
  athan_catalogue.dart
  athan_player.dart
  prayer_times_screen.dart
  locations_sheet.dart
  calculation_sheet.dart
  reminder_settings.dart
lib/platform/
  prayer_location.dart              # geolocator + normalized HTTP results
  prayer_notifications.dart        # conditional platform facade
  prayer_notifications_io.dart
  prayer_notifications_web.dart
lib/features/recitation/media_handler.dart   # extend the ONE audio service
lib/features/reader/reader_screen.dart       # navigation sheet entry
lib/app/app.dart, lib/main.dart              # lazy scope and lifecycle reconciliation
lib/app/l10n/app_ar.arb, app_en.arb
android/app/src/main/kotlin/app/mathani/mathani/
  PrayerAlarmReceiver.kt
  PrayerMediaBridge.kt
  PrayerAlarmStore.kt                # protected derived queue, no coordinates
android/app/src/main/AndroidManifest.xml
android/app/src/main/res/raw/                # bounded short fallback clips
ios/Runner/
  AppDelegate.swift                         # notification plugin registration/delegate
web/_headers, web/sw.js, web/_routes.json
functions/api/prayer-location.js
functions/api/prayer-places.js
functions/api/prayer-resolve.js
functions/_lib/prayer-location.js
wrangler.toml                               # Pages config/bindings, no credentials
assets/prayer/                              # catalogue + compact Ramadan table
assets/licences/                            # attribution and calendar source notice
assets/athan/                               # short clips only; full audio on demand
tool/prayer/                                # asset preparation and fixture provenance
test/features/prayer_times/
test/platform/prayer_notifications_web_test.dart
tool/prayer/location_api_test.mjs            # outside Functions routing tree
integration_test/prayer_times_test.dart
```

**Structure Decision**: Extend existing small conditional platform seams and feature-local controllers. Actual iOS source path is `ios/Runner/`. New names are planned files; they do not exist yet. No Quran database migration. Proxy endpoints are deployed with existing Pages tooling; ensure functions are compiled/included and /api paths bypass the SPA/offline cache. Do not overwrite existing unrelated FileStore edits.

## Complexity Tracking

| Deviation or added complexity | Why needed | Simpler alternative rejected because |
| --- | --- | --- |
| Platform exceptions P01-P04 | OS-managed sounds and browser lifecycle cannot implement universal full/indefinite athan promises | Dart timers, chained iOS alerts or silent background audio would be unreliable or misuse platform mechanisms. |
| P05 browser secure-storage exception | Web has no native Keychain/Keystore; encrypted origin-local storage preserves saved locations on web | Plaintext coordinates violate the privacy intent; disabling all saved locations breaks required web access. Browser storage protection is explicitly limited, not represented as native security. |
| Three Pages endpoints | Correct timezone/place resolution and optional IP fallback without exposing provider configuration | Bundled global gazetteer adds size; direct providers add browser restrictions and spread privacy/error handling. No server-side prayer history is needed. |
| Android native alarm-to-media bridge | Ordinary notification delivery does not invoke Dart to play a full recording | A second player/service would risk overlap and duplicate media controls. Use existing audio_service with an acknowledged, idempotent custom command. |
| Secure prayer snapshot separate from user.db | Saved coordinates are sensitive and existing SQLite is plaintext | Encrypting all Quran/user storage would expand scope and risk existing bookmarks; a small isolated snapshot is sufficient. |

## Delivery Sequence and Validation Gates

1. **Feasibility first**: G01 Android cold-process alarm-to-single-handler spike; G02 authentic four-takbir clips under 30 seconds and two complete recordings; G03 real Pages geo and commercial GeoNames account checks. Details in follow-ups and quickstart. Never turn a failed spike into a claimed capability.
2. Build local model, offline calculation, versioned Ramadan convention, encrypted persistence and reference fixtures. Add schedule/navigation, saved-place management and location setup.
3. Implement capability-aware notification settings, idempotent reconciliation, short notifications, single-handler athan playback and independent Qiyam. Apply explicit platform exceptions to UI copy.
4. Validate denied permission, no GPS, offline, high latitude, DST, restart, revoke/delete, audio interruption, no duplicate delivery and finite horizon. Run the required physical-device trials and usability tasks.
5. Measure size/performance and update privacy/attribution/release documentation. No new dependency is added by this planning command and no deployment is performed.
