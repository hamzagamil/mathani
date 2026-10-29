---
description: "Dependency-ordered implementation tasks for prayer times and athan notifications"
---

# Tasks: Prayer Times and Athan Notifications

**Input**: Design documents in `specs/009-prayer-times/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [UI/reminder contract](./contracts/prayer-ui-and-reminders.md), [location API contract](./contracts/location-api.md), [quickstart.md](./quickstart.md), [follow-ups.md](./follow-ups.md), constitution 2.0.0.

**Tests**: Focused test tasks implement the specification's explicit User Scenarios & Testing, SC-001..008 and G01-G05 evidence requirements. This is not a request to add unrelated tests. Test-first ordering applies to the listed behavioural tests; physical-device and usability checks follow implementation. Checked tasks must mean actual completion, not placeholders or unrun validation.

**Organization**: Setup, shared foundations, US1/US2 (P1), US3/US4 (P2), then cross-cutting acceptance. All tasks are initially unchecked. No implementation/deployment has been performed by task generation.

## Format: `[ID] [P?] [Story] Description`

- `[P]` identifies disjoint-file work that can run concurrently only after the dependencies below are complete; it does not authorize skipping prerequisites.
- Story labels map exactly to spec US1-US4. Shared phases have no story label.
- Every task names concrete repository-relative file paths; planned new files are intentional. Evidence lives under `specs/009-prayer-times/validation/` and must contain real results.

## Path Conventions

Single existing Flutter project: `lib/`, `android/`, `ios/`, `web/`, `test/`, `integration_test/`; bounded Pages endpoints in `functions/api/`. Keep Node tests in `tool/prayer/`, outside Functions routing. Native Kotlin package is `app.mathani.mathani`; published Android application ID is unchanged.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish a reproducible baseline and the planned platform/configuration boundaries without disturbing existing work.

- [X] T001 Capture the actual Git branch, existing unrelated edits, platform floors, dependency baseline and available physical-device/toolchain coverage in `specs/009-prayer-times/validation/baseline.md`; use `.specify/feature.json` to retain feature 009 independently of the Git branch and leave unrelated `lib/platform/file_store_web.dart` edits intact.

- [X] T002 Pin adhan_dart 2.0.1, timezone 0.11.2, geolocator 14.0.1, flutter_local_notifications 22.3.3 and flutter_secure_storage 10.3.4 in `pubspec.yaml`/`pubspec.lock`; solve against the pinned SDK, confirm API24/iOS15 and Java17 compatibility, and record dependency/transitive size and license expectations in `specs/009-prayer-times/validation/dependencies.md`; do not silently upgrade platform floors.

- [X] T003 Define development/preview/production API base selection, GEONAMES_USERNAME and allowed-origin binding names in `wrangler.toml` and `tool/prayer/README.md`, with local bindings excluded through `.gitignore`; use same-origin web requests and explicit native development URLs, never committed credentials or demo provider accounts.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared typed data, secure persistence and reproducible calculation inputs. Complete this phase before any user story. Notification feasibility is deliberately gated within US3, before dependent playback implementation; it does not block the schedule MVP.

- [X] T004 Define PrayerState and SavedLocation in `lib/features/prayer_times/prayer_models.dart`, preserving these model constraints verbatim: schemaVersion "Integer, initially 1; unknown future versions fail safely without overwrite"; revision "Monotonic integer for serialized user changes"; locations "List of SavedLocation, unique IDs"; activeLocationId "Nullable ID referencing an existing confirmed location"; calculationVersion "Version of app convention mapping, timezone data and Ramadan table"; id "Random opaque stable ID; independent of label/coordinates"; label "Trimmed user label, 1-80 characters; no control characters"; city/region/countryCode "Display name, optional region, ISO country code; city/region may be absent for a valid coordinate fix"; coordinates "Finite numbers, latitude -90..90 and longitude -180..180"; timezoneId "Valid resolvable IANA ID; no inferred device-zone fallback"; source "device, manual, ip"; approximate "True for IP and approximate-only device fixes"; accuracyMeters "Optional finite nonnegative device-reported accuracy"; confirmedAtUtc "UTC instant; required for saved/active state"; geonamesId "Optional provider place identifier". Include calculation/reminder relationships, require confirmation before persistence and one confirmed active location before any enabled reminder.

- [X] T005 Extend CalculationPreferences and DailyPrayerSchedule in `lib/features/prayer_times/prayer_models.dart` using the exact model constraints: "methodId: muslim_world_league, egyptian, karachi, umm_al_qura, north_america."; "madhhabLabel: hanafi, shafii, maliki, hanbali. Derived Asr factor is Hanafi=2; other labels=1. Labels are preserved independently of that grouping."; "highLatitudeRule: middle_of_night or seventh_of_night. Default middle_of_night, explicitly shown; never silently switch rules because a result fails."; "conventionVersion: stable integer tying method offsets, Ramadan handling and rounding to reviewed fixtures."; "localDate (year/month/day in location zone)"; fingerprint "coordinates + preferences + calculator/timezone/Ramadan versions"; events "fajr, sunrise, dhuhr, asr, maghrib, isha"; "status=available/adjusted/unavailable; dueAtUtc nullable; reason code; adjustment label."; "followingFajrUtc and qiyamUtc nullable, Qiyam reason code."; "generatedAtUtc and calculationVersion for invalidation, not freshness based solely on wall-clock age."

- [X] T006 Extend ReminderPreferences and ReminderCapability in `lib/features/prayer_times/prayer_models.dart`, quoting and enforcing "enabledPrayers: set drawn only from fajr/dhuhr/asr/maghrib/isha; initially empty."; "selectedAthanId: stable catalogue ID; default first eligible entry, not proof audio is ready."; "requestedMode: full/opening; initially opening."; "qiyamEnabled: false initially."; "acknowledgedFallbacks: capability-specific disclosure versions, reset if the alternative changes." Include runtime "Permission status, exactAlarmAccess, foregroundModeSupport, backgroundModeSupport, channel/system restrictions when observable, reason and recovery action." and "scheduledThroughUtc and appMustReopenByUtc"; preserve requested intent separately from effective capability and never infer audible delivery or unobservable Focus/silent settings.

- [X] T007 Extend AthanRecording and ScheduledReminder in `lib/features/prayer_times/prayer_models.dart` with catalogue fields "id, titleAr/titleEn, creditedRecorder, sourceUrl, sourceRevision, licenseId/licenseUrl, attribution/change notice."; "fullAssetUrl, SHA-256, expectedBytes, durationMs, encoding."; "openingAssetId, openingEndMs, durationMs, platform clip hashes/encodings."; "completeRecordingReviewed, fourTakbirsReviewed, iosShortEligible (complete four takbirs and duration <30000ms)."; "availability: absent/downloading/verified/failed per full recording and platform clip." Preserve ledger constraints "eventId: deterministic opaque token of location ID + local schedule date + prayer/Qiyam + generation."; "generation: persisted monotonic counter advanced by schedule-affecting changes."; "kind, dueAtUtc, expiresAtUtc, audio ID/mode, effective delivery mechanism."; "state: pending/claimed/playing/delivered/cancelled/failed."; "claimOwner: appAudio/systemFallback; started/consumed token for deduplication."

- [X] T008 Define injectable clock, location client, protected-store and notification/audio interfaces plus the contract's typed failure/recovery states in `lib/features/prayer_times/prayer_services.dart`; keep capabilities queryable without prompting, inputs fakeable and unsupported adapters explicit; do not start plugins, network, audio or location access while constructing services.

- [X] T009 Implement serialized encrypted snapshot load/save/delete and forward-version handling in `lib/features/prayer_times/prayer_repository.dart`; use the planned secure-storage options, this-device native protection and backup exclusions, never write coordinates to user.db or overwrite unreadable ciphertext, retain bookmarks on failure, and expose explicit session-only browser operation under P05 when crypto/persistence is unavailable.

- [X] T010 [P] Generate a compact versioned Ramadan interval asset from pinned MIT HijriDate 2.6.0 data with provenance and range bounds using `tool/prayer/build_ramadan_table.py`, `assets/prayer/ramadan_intervals.json` and `assets/licences/LICENSE-hijridate.txt`; document sunset-aware first/last evening conventions and reproducible commands in `tool/prayer/README.md`, without a runtime Python/calendar dependency.

- [X] T011 [P] Prepare independent PrayTimes fixture generation/provenance in `tool/prayer/build_reference_fixtures.mjs` and `test/fixtures/prayer_times/reference.json`; cover Cairo, Makkah, Karachi, London, Oslo, New York, Los Angeles, Singapore, Jakarta and Sydney with all five methods, both Asr conventions, matched offsets/rounding, DST, Ramadan and polar unavailable cases; pin reference versions and never generate expected results through the production calculator.

**Checkpoint**: Foundation ready. No notification capability or successful device trial is implied by these completed primitives.

---

## Phase 3: User Story 1 — See prayer times for my location (Priority: P1) — MVP

**Goal**: A first confirmed location and accurate local schedule through device detection, manual city selection or optional confirmed IP approximation, with offline saved-place use.

**Independent Test**: From fresh prayer state, exercise granted/denied device access, manual disambiguation, confirmed/rejected/failed IP approximation and offline reopening. The six daily events and next prayer must use the confirmed place's date/time zone; no reminder setup is required.

### Tests for User Story 1

These focused tests implement the spec's explicit acceptance scenarios and accuracy/failure criteria. Write them before their corresponding implementation and observe the expected missing-behaviour failures; do not count an unrelated build failure as evidence.

- [X] T012 [P] [US1] Add reference-driven calculation tests in `test/features/prayer_times/prayer_calculator_test.dart` for SC-002: five methods, two Asr factors, explicit adjustment/unavailable states, UTC/location date conversion, Ramadan range/boundaries and next-Fajr rollover; require <=1-minute agreement with T011 fixtures.

- [X] T013 [P] [US1] Add location endpoint contract tests in `tool/prayer/location_api_test.mjs` using injected provider/cf fixtures for validation, CORS/native no-Origin requests, missing timezone/geo, errors, bounded calls/deadlines, no-store and privacy-safe diagnostics; match `specs/009-prayer-times/contracts/location-api.md`.

- [X] T014 [P] [US1] Add setup/controller/repository/widget tests in `test/features/prayer_times/prayer_setup_test.dart` for denied permission, required IP confirmation, stale-search cancellation, restart/offline use, secure-store failure and no reader-startup prompts; include the data-model validation bounds and failed-read non-overwrite behaviour.

- [X] T015 [US1] Implement offline `PrayerCalculator.schedule` and next-prayer/countdown logic in `lib/features/prayer_times/prayer_calculator.dart`; lazily load the full IANA database, preserve library offsets, use selected-location dates and UTC instants, reject nonfinite/polar results, apply versioned Ramadan Isha intervals, and return conventionUnavailable outside table coverage rather than guessing. Exclude sunrise from next-prayer selection.

- [X] T016 [US1] Implement shared request validation, error normalization, CORS/no-store headers, provider allowlist/configuration and abortable bounded calls in `functions/_lib/prayer-location.js`; enforce search q 2-80 characters, ar/en, limit 1-10, resolve JSON <=2 KB, 5-second upstream and 8-second total deadlines, no raw personal-value logs, and the documented HTTP error envelope.

- [X] T017 [P] [US1] Implement `GET /api/prayer-places` in `functions/api/prayer-places.js` after T016; call bounded populated-place GeoNames search once, return region/country attribution, and distinguish selectable from resolvable timezone-missing results without per-keystroke timezone fan-out.

- [X] T018 [P] [US1] Implement `POST /api/prayer-resolve` in `functions/api/prayer-resolve.js` after T016; resolve nearby name and IANA zone in at most two upstream calls, retain submitted coordinates, allow an unnamed valid fix, and reject unresolved time zones without device-zone fallback.

- [X] T019 [P] [US1] Implement explicit `GET /api/prayer-location` in `functions/api/prayer-location.js` after T016; normalize trusted Cloudflare cf metadata to source=ip/approximate=true/requiresConfirmation=true, return unavailable for missing/invalid fields, and never accept a supplied IP or send location to another IP vendor.

- [X] T020 [US1] Implement one-shot geolocator and normalized endpoint client in `lib/platform/prayer_location.dart`; apply timeout/permission handling, 350ms debounced cancellable city searches, explicit API base configuration, missing-zone resolution and privacy disclosures, preserving prior data on failure and requesting no background location access.

- [X] T021 [US1] Implement first-location setup and schedule state in `lib/features/prayer_times/prayer_controller.dart`; keep candidates transient until valid/confirmed, always require explicit IP confirmation, load saved state lazily, expose typed retry/manual/session-only states and offline recomputation, and keep automatic movement tracking absent.

- [X] T022 [US1] Add Arabic/English schedule/setup/error/disclosure strings, GeoNames attribution and accessible time labels in `lib/app/l10n/app_ar.arb` and `lib/app/l10n/app_en.arb`, then regenerate localization output using the existing workflow.

- [X] T023 [US1] Build detection/manual/IP setup, candidate confirmation and disambiguated city search in `lib/features/prayer_times/location_setup_sheet.dart`; retain manual selection after denial, explain precise-coordinate resolution and connection-based approximation before requests, and never save a candidate with unresolved timezone.

- [X] T024 [US1] Build the six-event schedule, location/date/timezone/convention header, adjusted/unavailable states and next-prayer countdown in `lib/features/prayer_times/prayer_times_screen.dart`; use safe areas, inherited theme/locale, scalable typography and phone touch targets.

- [X] T025 [US1] Wire the lazy route-owned prayer controller through `lib/features/settings/settings_screen.dart` and `lib/features/prayer_times/prayer_times_screen.dart`; preserve the Mushaf home/page and existing recitation/memorization scopes, keep startup free of prayer IO/permission prompts, and retain browser PhoneColumn/back behaviour. This implementation adjustment avoids overloading the existing narrow reader toolbar; there is no existing navigation sheet.

- [X] T026 [US1] Update self-geolocation Permissions-Policy and approved same-origin API/audio CSP rules in `web/_headers`; keep other existing security and rendering headers intact, with HTTPS required for device access.

- [X] T027 [US1] Include Pages Functions and bounded `/api/prayer-*` routing in `web/_routes.json` and `tool/web_deploy.mjs`, and bypass these endpoints in `web/sw.js`; preserve static asset deployment/cache behaviour and prevent API failures becoming cached SPA HTML.

- [X] T028 [US1] Add localized foreground-location declarations in `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `ios/Runner/ar.lproj/InfoPlist.strings` and `ios/Runner/en.lproj/InfoPlist.strings`; keep API24/iOS15 minimums and omit background/always location authorization.

- [X] T029 [US1] Validate GeoNames configuration, ten-city search/resolve, native requests and real cf metadata on an authorized HTTPS preview, recording sanitized G03 evidence in `specs/009-prayer-times/validation/location-services.md`; do not fabricate local cf success or mark the task complete if required account/deployment access is missing.

- [ ] T030 [US1] Implement/run first-location end-to-end cases in `integration_test/prayer_times_test.dart` and record results in `specs/009-prayer-times/validation/us1.md`; run T012-T014 tests, prove GPS denial/manual/IP confirmation and offline restart paths on iOS/Android/web, and verify no unavailable time is displayed as midnight.

**Checkpoint**: US1 MVP is independently demonstrable: setup and valid schedules, including offline saved-place operation, without enabling notification work.

---

## Phase 4: User Story 2 — Manage locations and calculation preferences (Priority: P1)

**Goal**: Multiple named places with independent conventions and a single explicit active reminder location.

**Independent Test**: Seed three confirmed places in different time zones, view versus activate each, change methods/madhahib, rename/delete and restart. Preferences persist and inspection never silently changes the active place; reminders may remain disabled.

- [X] T031 [P] [US2] Add saved-place state/repository tests in `test/features/prayer_times/prayer_locations_test.dart` for unique IDs, label bounds, three-place persistence, transient viewed location, replacement/disable confirmation and generation invalidation without losing bookmarks.

- [X] T032 [P] [US2] Add calculation/location sheet tests in `test/features/prayer_times/prayer_preferences_test.dart` for all named methods/four labels, two Asr conventions, overridable regional defaults, high-latitude choices and preservation of manual choices across restart/movement.

- [X] T033 [US2] Extend saved-location CRUD/view/activate actions in `lib/features/prayer_times/prayer_controller.dart`; preserve each location's calculation record, allow at most one active location, distinguish viewed ID from persisted active ID, and prevent failed detection from replacing a manual choice.

- [X] T034 [US2] Extend calculation preference updates in `lib/features/prayer_times/prayer_controller.dart`; apply the data model's explicit country suggestions and visible shafii/middle-of-night defaults, persist labels/convention versions, invalidate derived schedules and advance schedule-affecting revision/generation only after validation.

- [X] T035 [US2] Add location-management/calculation strings and Asr-only explanations in `lib/app/l10n/app_ar.arb` and `lib/app/l10n/app_en.arb`, including active/viewed labels, adjusted rules and destructive-action confirmation; regenerate localization output.

- [X] T036 [US2] Build save/name/rename/view/activate/delete controls and a virtualized location list in `lib/features/prayer_times/locations_sheet.dart`; permit the same city with distinct valid user labels/settings without silently merging identities, and require the defined label validation.

- [X] T037 [US2] Build five-method, four-madhhab-label and middle/seventh-night controls in `lib/features/prayer_times/calculation_sheet.dart`; show current/suggested selections, explain Asr grouping and unavailable results, and preserve explicit user overrides.

- [X] T038 [US2] Integrate active-location badge, picker and calculation sheets into `lib/features/prayer_times/prayer_times_screen.dart`; viewing another place must leave notification intent unchanged, and displayed dates/timezones must follow that viewed place.

- [X] T039 [US2] Implement transactional active/last-place deletion and clear-prayer-data handling in `lib/features/prayer_times/prayer_controller.dart` and `lib/features/prayer_times/prayer_repository.dart`; invalidate the future reminder generation through the injectable scheduler boundary, delete sensitive state and preserve unrelated reader data. The pre-US3 adapter must explicitly have no queued reminders.

- [X] T040 [US2] Refresh viewed/active schedules after resume, midnight and device clock/timezone changes in `lib/features/prayer_times/prayer_controller.dart` and `lib/features/prayer_times/prayer_times_screen.dart`; extend the existing route-owned lifecycle observer instead of introducing prayer IO in `lib/app/app.dart`, retain the location's IANA zone and never initiate location polling or silent travel updates.

- [ ] T041 [US2] Run three-location, five-method, four-label, delete/restart and DST acceptance flows in `integration_test/prayer_times_test.dart`, execute T031-T032 tests and record SC-003/G04 evidence in `specs/009-prayer-times/validation/us2.md`; notification delivery itself is validated in US3.

**Checkpoint**: US1 and US2 work with notifications disabled. US2 can be accepted using seeded places without repeating external location lookup.

---

## Phase 5: User Story 3 — Choose how I hear the athan (Priority: P2)

**Goal**: Five independent daily prayer switches, two named recordings, full/opening choices, safe offline audio and capability-aware native reminders.

**Independent Test**: Seed a confirmed active place, preview/select two recordings and each supported duration, enable/disable prayers, then verify one current-generation reminder, Stop and disclosed fallbacks in foreground/background/locked states. G01/G02 precede dependent production playback; iOS/web exceptions P01-P04 are mandatory.

- [ ] T042 [P] [US3] Add scheduler/capability contract tests in `test/features/prayer_times/prayer_scheduler_test.dart` for five-prayer-only switches, requested/effective modes, generation replacement, finite horizon, revoked permissions, <=60-second overdue expiry, fallback acknowledgements and no stale/duplicate event delivery.

- [ ] T043 [P] [US3] Add catalogue/download/coordinator tests in `test/features/prayer_times/athan_player_test.dart` for hashes/size validation, interrupted downloads, one preview owner, Stop invalidating queued starts, Quran/memorization pause without automatic resume and rejected browser autoplay.

- [ ] T044 [P] [US3] Add Android queue/claim tests in `android/app/src/test/kotlin/app/mathani/mathani/PrayerAlarmStoreTest.kt` and required test configuration in `android/app/build.gradle.kts`; prove protected persistence, single-winner audio/fallback claims, cancelled/stale/expired rejection and boot-before-unlock recovery rules without storing coordinates in intents.

- [ ] T045 [US3] Prove G01 with a minimal reusable `android/app/src/main/kotlin/app/mathani/mathani/PrayerMediaBridge.kt`, early single-handler initialization in `lib/features/recitation/media_handler.dart`/`lib/main.dart` and `integration_test/prayer_alarm_spike_test.dart`; verify API24/31+/33+/36 cold-process alarm startup, acknowledgement, foreground deadline, one service/notification and Stop. Record sanitized results in `specs/009-prayer-times/validation/android-headless.md`; retain full mode disabled and revise design/spec if proof fails.

- [ ] T046 [P] [US3] Complete G02 asset preparation in `tool/prayer/prepare_athan.py`, `assets/prayer/athan_catalogue.json`, `assets/athan/`, `android/app/src/main/res/raw/` and `assets/licences/`; human-review the two research source candidates, complete four-takbir boundaries and <30000ms CAF eligibility, preserve revisions/licenses/transformations/hashes, generate a short Qiyam tone and record evidence in `specs/009-prayer-times/validation/athan-assets.md`. Replace unsuitable recordings; never truncate spoken words.

- [ ] T047 [US3] Implement catalogue parsing and atomic full-audio download/verification in `lib/features/prayer_times/athan_catalogue.dart`, reusing existing FileStore/http/crypto; enforce source allowlists, per-variant availability and human-reviewed eligibility, mark only verified assets offlineReady, preserve the last usable selection, and keep complete recordings on demand rather than in the store bundle.

- [ ] T048 [US3] Implement Keystore-backed AES-GCM derived queue/presentation storage in `android/app/src/main/kotlin/app/mathani/mathani/PrayerAlarmStore.kt`; preserve atomic event claims, current generation and cancellable start state, keep coordinate-free alarm tokens, avoid undocumented Flutter secure-store internals, and protect native title/location data rather than persisting plaintext plugin scheduling payloads.

- [ ] T049 [US3] Implement production exact-alarm delivery/restore in `android/app/src/main/kotlin/app/mathani/mathani/PrayerAlarmReceiver.kt` and finalize `PrayerMediaBridge.kt` after G01; validate current tokens/due/expiry, acknowledge the single media-handler action, let only a winning fallback post sound, restore future alarms after boot/unlock/clock changes and never start playback from boot or replay a backlog.

- [ ] T050 [US3] Extend the existing single handler with acknowledged `playAthan`/Stop commands and headless-safe initialization in `lib/features/recitation/media_handler.dart` and `lib/main.dart`; reject stale/consumed commands, start without opening Quran databases first, preserve existing Quran media controls and prevent a second audio service/Flutter playback owner.

- [ ] T051 [US3] Implement iOS system scheduling and native facade in `lib/platform/prayer_notifications_io.dart` and `ios/Runner/AppDelegate.swift`; register plugin/delegate safely, prepare eligible CAF files in Library/Sounds, keep next 60 events total, suppress foreground OS sound during app playback, support open-to-play-full and expose P01/P02 limits without indefinite background refresh claims.

- [ ] T052 [US3] Register an Activity-independent Android prayer channel/plugin in `android/app/src/main/kotlin/app/mathani/mathani/PrayerNotificationsPlugin.kt`, `MainActivity.kt`, `android/app/src/main/AndroidManifest.xml` and required Gradle setup; expose capabilities/exact-access/replace/cancel/list/stop, add POST_NOTIFICATIONS/SCHEDULE_EXACT_ALARM/boot permissions and safe receiver filters, preserving mediaPlayback declarations without background location or full-screen intents.

- [ ] T053 [US3] Implement browser capability, optional notification and active-page audio behaviour in `lib/platform/prayer_notifications_web.dart` and conditional `lib/platform/prayer_notifications.dart`; handle permission/autoplay rejection, expiry/suspension and explicit Play, show P03/mobile alternatives and never claim closed-page precise custom athan.

- [ ] T054 [US3] Implement shared idempotent reconciliation in `lib/features/prayer_times/prayer_reminder_scheduler.dart`; commit current-generation intent, cancel obsolete queues, install only valid future daily events, verify actual pending state before reporting ready, cap Android at 30 days/iOS at 60 total, and expose partial/blocked/scheduled-through status with retry and P04 disclosures.

- [ ] T055 [US3] Implement shared app-controlled preview/full/opening playback in `lib/features/prayer_times/athan_player.dart` against the single handler; pause Quran and memorization before taking ownership, suppress overlapping previews/system foreground sounds, respect selected clip boundaries, expose Stop and never automatically resume interrupted activity.

- [ ] T056 [US3] Wire persisted daily switches, requested mode/recording, acknowledgement versions and effective permissions into `lib/features/prayer_times/prayer_controller.dart`/`prayer_repository.dart`; keep choices after denial, prevent unsupported full mode from appearing active, and require acknowledged fallback or leave delivery blocked.

- [ ] T057 [US3] Add Arabic/English notification, recording attribution, offline-readiness, platform-limit, exact-access, scheduled-through and Stop strings in `lib/app/l10n/app_ar.arb` and `lib/app/l10n/app_en.arb`, then regenerate localization output without changing unrelated reader copy.

- [ ] T058 [US3] Build five prayer toggles, named previews, full/opening options and capability-aware readiness/permission/recovery UI in `lib/features/prayer_times/reminder_settings.dart`; exclude sunrise, retain all-disabled defaults, distinguish requested/effective modes and expose P01-P04 before activation.

- [ ] T059 [US3] Wire reminder settings, notification-open routes and launch/resume/locale/permission/audio-readiness reconciliation in `lib/features/prayer_times/prayer_times_screen.dart`, `lib/features/prayer_times/prayer_controller.dart` and `lib/app/app.dart`; preserve lazy first-frame behaviour and serialize refresh against user changes.

- [ ] T060 [US3] Integrate real native cancel/reconcile with location activation/deletion and calculation changes in `lib/features/prayer_times/prayer_controller.dart` and `lib/features/prayer_times/prayer_reminder_scheduler.dart`; replace the pre-notification empty adapter, invalidate stale queued starts and confirm last-place/clear-all removes both protected state and pending alerts.

- [ ] T061 [US3] Implement bounded recording-specific short fallback channels and silent app-audio media notification handling in `android/app/src/main/kotlin/app/mathani/mathani/PrayerNotificationsPlugin.kt`/`PrayerAlarmReceiver.kt` and `lib/platform/prayer_notifications_io.dart`; respect immutable user channel settings, never recreate channels to bypass them, and label any accepted inexact fallback accurately.

- [ ] T062 [US3] Register short assets/catalogue in `pubspec.yaml`, host versioned full recordings via existing `tool/web_deploy.mjs`, and apply required audio allowlists/cache behaviour in `web/_headers`/`web/sw.js`; prepare native offline clips without bundling full files or changing unrelated FileStore work.

- [ ] T063 [US3] Add and run foreground/background/locked/process-absent, offline-audio, permission-revocation, Stop/fallback-race, horizon and active-Quran scenarios in `integration_test/prayer_times_test.dart` plus native tests; record observed iOS system-sound interruption limits and P01-P04 acceptance in `specs/009-prayer-times/validation/us3-platforms.md` without claiming unsupported states passed.

- [ ] T064 [US3] Run T042-T044 automated checks, recheck G01/G02 after integration and record the story acceptance/capability matrix in `specs/009-prayer-times/validation/us3.md`; block completed status for missing two-recording proof or unsupported Android full playback until the design/spec exception is explicitly resolved.

**Checkpoint**: Daily reminders are independently acceptable with Qiyam off. Full Android capability remains gated by measured cold-process proof; iOS/browser boundaries stay visible.

---

## Phase 6: User Story 4 — Receive an optional Qiyam reminder (Priority: P2)

**Goal**: Independently enabled, clearly labelled short Qiyam reminder at the start of the last third of the night.

**Independent Test**: Seed a valid Maghrib/next-day Fajr pair and active location, enable Qiyam with all five daily toggles off, verify one displayed/scheduled reminder, then disable it and confirm daily preferences are unchanged.

- [ ] T065 [P] [US4] Add Qiyam calculation tests in `test/features/prayer_times/qiyam_calculator_test.dart` for cross-midnight/DST elapsed durations, rounding, invalid boundaries and local delivery date; require the displayed/scheduled instant to agree with the specified boundary within one minute.

- [ ] T066 [P] [US4] Add Qiyam preference/UI/scheduler tests in `test/features/prayer_times/qiyam_reminder_test.dart` for default off, enablement with daily prayers off, independent cancellation, no obligatory athan and recomputation after active-place/settings changes.

- [ ] T067 [US4] Implement Qiyam derivation in `lib/features/prayer_times/prayer_calculator.dart` using the model rule "qiyamUtc = maghribUtc + 2*(fajrUtc-maghribUtc)/3, rounded consistently to the displayed minute."; "Require positive valid boundaries." and "No valid boundaries means no Qiyam event." Preserve its actual local delivery date and avoid the calculator package's differing convenience night interval.

- [ ] T068 [US4] Add independent Qiyam enable/disable transitions in `lib/features/prayer_times/prayer_controller.dart` and `prayer_repository.dart`; enforce "qiyamEnabled: false initially.", require confirmed active location and valid effective permission, and leave daily prayer preferences unchanged.

- [ ] T069 [US4] Extend event generation and native reconciliation in `lib/features/prayer_times/prayer_reminder_scheduler.dart` to enqueue exactly one Qiyam per valid night using the generated short tone, share the finite total horizon, cancel only Qiyam when disabled and suppress invalid-boundary nights with an explicit reason.

- [ ] T070 [US4] Add Arabic/English last-third explanation, distinct Qiyam label, unavailable-boundary reason and upcoming local date/time strings in `lib/app/l10n/app_ar.arb` and `lib/app/l10n/app_en.arb`, then regenerate localization output.

- [ ] T071 [US4] Add independent Qiyam controls and upcoming date/time to `lib/features/prayer_times/reminder_settings.dart` and `prayer_times_screen.dart`; display the reminder instant before activation and never present Qiyam as a sixth obligatory-prayer athan.

- [ ] T072 [US4] Run T065-T066 and Qiyam device/offline/location-change acceptance in `integration_test/prayer_times_test.dart`, recording SC-005 and independent-toggle results in `specs/009-prayer-times/validation/us4.md`; exercise missing night boundaries and one-alert/no-backlog behaviour.

**Checkpoint**: All four stories are functional subject to the final evidence gates; Qiyam can be verified independently of enabled daily athans.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Required release evidence across all desired stories. Do not mark implementation complete by treating absent physical-device access, a missing provider binding or a user study as a passing check.

- [ ] T073 Update location/coordinate-sharing, IP approximation, retention/deletion, local audio, browser storage and notification-limit disclosures in `docs/store/privacy.md`, `docs/release.md` and `ios/Runner/PrivacyInfo.xcprivacy` where applicable; prepare consistent store privacy/Data safety changes without claiming no infrastructure retention or publishing account changes.

- [ ] T074 [P] Register all dependency/calendar/audio licenses, GeoNames attribution and changed-recording credits in `docs/licences.md`, `assets/licences/` and `lib/features/settings/about_section.dart`; verify names are recorder attributions rather than invented reciter identities and no unconfirmed audio source is shipped.

- [ ] T075 Execute the SC-004 timed matrix from `specs/009-prayer-times/quickstart.md`, recording at least 30 trials per supported playback mode per mobile platform in `specs/009-prayer-times/validation/notification-timing.md`; require >=95% start within 60 seconds, correct recitation/duration and zero stale/duplicate alerts, explicitly listing P01-P04 rather than omitting unsupported states as passes.

- [ ] T076 Complete G04 independent fixture and persistence/recovery coverage through `test/features/prayer_times/` and `integration_test/prayer_times_test.dart`, with results in `specs/009-prayer-times/validation/correctness-recovery.md`; require every available result within one minute across the full method/city matrix and verify DST/Ramadan/polar/midnight/restart/delete/clock cases.

- [ ] T077 Audit G03/P05 endpoint/log/cache/storage protection in `tool/prayer/location_api_test.mjs`, `test/platform/prayer_notifications_web_test.dart` and `specs/009-prayer-times/validation/privacy-security.md`; exercise missing grants, broken crypto, private browsing/eviction, no-Origin native calls, blocked origins, invalid input/upstream hosts, no-store/SPA bypass and protected native queue/title data.

- [ ] T078 Validate Arabic/English RTL, dark mode, large fonts, safe areas, 44pt/48dp targets, VoiceOver/TalkBack and supported-browser capability copy in `integration_test/prayer_times_test.dart` and `specs/009-prayer-times/validation/accessibility-browser.md`; include system-owned sound/Stop boundaries and horizon expiry announcements.

- [ ] T079 Add/run schedule-scrolling profile coverage in `integration_test/prayer_times_perf_test.dart`, reuse `integration_test/paging_perf_test.dart` and `test_driver/perf_driver.dart`, and record cold-start/frame/tap/network/battery observations in `specs/009-prayer-times/validation/performance.md`; meet <=2s startup on Galaxy A15/iPhone SE2, 60fps and <=100ms feedback without startup location/network/plugin work.

- [ ] T080 Measure Android/iOS release build deltas with the existing `tool/size_check.dart` against `docs/size_baseline.json`, record per-dependency/asset growth in `specs/009-prayer-times/validation/size.md` and update `docs/release.md`; explain >1MB growth in review and never pass --approved or alter baselines to manufacture approval. Remove temporary spike assets/dead paths and keep only used dependencies.

- [ ] T081 Run SC-001/SC-007 representative Arabic/English and screen-reader usability tasks and record participant counts/results in `specs/009-prayer-times/validation/usability.md`; require >=90% confirmed setup within two minutes and >=90% unassisted recitation/mode/Qiyam completion, including denied-location users, without fabricated study results.

- [ ] T082 Run the complete applicable `specs/009-prayer-times/quickstart.md` suite plus existing reader/recitation/memorization regressions; consolidate evidence links and actual pass/fail/blocked outcomes in `specs/009-prayer-times/validation/summary.md` and update `specs/009-prayer-times/follow-ups.md` for G01-G05/P01-P05. Require both mobile platforms and the supported-browser matrix, keep missing evidence open, and do not mark release readiness from code-only tests.

---

## Dependencies & Execution Order

### Phase dependencies

```text
Phase 1 Setup (T001-T003)
    |
Phase 2 Foundations (T004-T011)
    |
US1 Schedule/setup (T012-T030) ----> independently demonstrable MVP
    |
US2 Saved places/preferences (T031-T041)
    |
US3 Daily athan reminders (T042-T064)
    |     G01: T045 -> native/full/headless production work
    |     G02: T046 -> verified catalogue/clip-dependent production work
    |
US4 Independent Qiyam reminder (T065-T072)
    |
Polish and release evidence (T073-T082)
```

All stories require foundations. This app's real shared controller/state dependencies mean the integrated stories follow the order above; do not claim that whole stories editing the same files are independent parallel work. Their acceptance remains independently runnable with seeded valid state: US2 need not repeat provider lookup, US3 can use one seeded location, and US4 can run with every daily toggle off.

### Within-phase dependencies

- T001 establishes the baseline; T002 and T003 complete setup. T004-T007 extend the same model file sequentially, then T008 defines service boundaries and T009 implements persistence. T010 and T011 are independent foundational work after setup and may proceed alongside the sequential model/storage track. All T004-T011 must finish before US1.
- US1 test tasks T012-T014 precede corresponding behaviour. T015 depends on the model, Ramadan table and reference fixtures. T016 creates shared endpoint helpers; only then run T017-T019 concurrently. T020 consumes these contracts; T021 needs the calculator, repository and location client. T022 localization precedes T023/T024 widgets. T025 integrates the UI. T026-T028 may be implemented after their relevant contracts but must be serialized where they touch shared build/config files; T029 requires deployed/configured endpoint work, and T030 requires the complete story.
- US2 tests T031/T032 can be authored together. T033/T034 extend the same controller sequentially. T035 localization precedes the T036/T037 sheets. T038 integrates them, T039 binds deletion/invalidation and T040 lifecycle refresh; T041 validates the increment.
- US3 tests T042-T044 are disjoint. T045 (G01) and T046 (G02) can proceed concurrently after the required shared/test scaffolding. T047 requires verified asset metadata from T046. T048 precedes T049; T049/T050 depend on the successful T045 route. Never enable full scheduled Android playback on a failed/unrun G01.
- T051/T052/T053 implement platform adapters against the established facade/model; T051 also needs eligible clips and T052 the native queue/receiver. Their separate-file work may be scheduled concurrently only once those prerequisites exist; common facade/Gradle ownership must be coordinated. T054 integrates adapters. T055 requires the single handler and verified catalogue. T056 needs effective scheduling/audio outcomes; T057 strings precede T058 settings. T059-T062 integrate lifecycle/deletion/channels/assets without concurrent writes to shared files. T063/T064 accept the story.
- US4 tests T065/T066 are disjoint. T067 uses the existing calculator; T068/T069 serialize controller/repository/scheduler changes. T070 strings precede T071 UI; T072 verifies the full increment. Use the G02 tone rather than adding another Qiyam audio subsystem.
- Polish follows all four stories. T073 and T074 can be worked independently in the listed files. Measurements T075-T081 require finished implementation and actual provider/device/study access. T082 closes G01-G05 only after evidence exists. Documentation may be drafted earlier, but no validation result may be prefilled as passed.

### Requirement and gate coverage

| Requirement / outcome | Primary implementation and acceptance tasks |
| --- | --- |
| FR-001/002/010/011, SC-002 | T005, T010-T012, T015, T024, T030, T034, T037, T076 |
| FR-003/004/005 | T013/T014, T016-T023, T026-T030, T077 |
| FR-006/007, SC-003 | T004/T009, T031-T041, T060, T076 |
| FR-008/009 | T005, T011/T012, T015, T032/T034/T035/T037, T041, T076 |
| FR-012/013/014 | T006/T007, T042-T047, T050-T058, T063/T064, T075 |
| FR-015/016, SC-004 | T042/T044/T045, T048-T054, T059-T064, T075 |
| FR-017 | T043/T045, T049/T050/T055, T063/T064 |
| FR-018/020 | T009/T014/T015/T030, T043/T046/T047/T062/T063 |
| FR-019, SC-005 | T065-T072 |
| FR-021/022 | T022-T028, T035, T051-T053/T057/T058, T070/T071, T078 |
| FR-023 | T004/T009, T013/T014/T016, T039/T044/T048, T073/T077 |
| FR-024, SC-008 | T008/T025/T040/T059, T079/T080 |
| SC-001/007 | T030/T072, T078/T081 |
| SC-006 | T013/T014/T030/T032/T042/T043/T063/T066, T077/T078 |
| P01/P02/P03/P04/P05 | T009/T026, T042/T051/T053/T054/T057/T058/T063, T073/T077/T078/T082 |
| G01 Android headless feasibility | T044/T045, T048-T050/T063/T064, T075/T082 |
| G02 licensed/eligible audio | T046/T047/T062/T064/T074/T082 |
| G03 location operations/privacy | T013/T016-T020/T026-T030/T073/T077/T082 |
| G04 correctness/recovery | T009-T015/T031-T041/T042/T044/T063/T065-T072/T076/T077/T082 |
| G05 complete product evidence | T073-T082 |

## Parallel Examples per User Story

These are scheduling examples, not additional checkbox tasks. Parallelize only after the specified predecessors are complete.

- **US1**: After foundations, author T012 calculator, T013 endpoint and T014 setup tests in their separate files. After T016, implement T017 city search, T018 coordinate resolution and T019 approximate location concurrently; integrate through T020 afterward.
- **US2**: Author T031 state tests and T032 sheet tests concurrently. After T033-T035, T036 location management and T037 calculation selection are separate widget files and can run together; T038 owns their shared screen integration.
- **US3**: Author T042 scheduler, T043 player and T044 native-store tests concurrently. After scaffolding, run T045 Android feasibility and T046 catalogue preparation concurrently in disjoint files. Once verified dependencies exist, iOS T051 and web T053 are separate adapter work; do not race T049/T050 or shared facade edits.
- **US4**: Author T065 calculation tests and T066 reminder tests concurrently. Calculation T067 and localization T070 touch different files and may proceed together after test contracts are agreed; T071 waits for localized copy and T068/T069 state/scheduler behaviour.

## Implementation Strategy

### MVP first

Complete setup, foundations and US1, then validate the first-location schedule on iOS/Android/web. This MVP includes detection, manual search, optional confirmed approximation, correct timezone/convention handling and offline saved-place schedules. It does not require an enabled notification service. Use T030 evidence before treating the MVP as demonstrated; a production release still requires applicable cross-cutting checks.

### Incremental delivery

Add US2's saved-place/convention controls, verify with seeded locations, then prove G01/G02 before implementing dependent notification capability. Complete US3 with Qiyam off. Add US4 independently of daily toggle selections. Finally collect the full release matrix; P01-P05 remain visible product limitations, not unfinished code to hide.

### Evidence and blocker handling

Implementation may prepare fixtures, code and executable checks without target devices/provider credentials, but must leave the corresponding acceptance task incomplete with a concrete reason in its evidence file. Never fake physical iOS results on Windows, a passing user study, licensed audio review, provider coverage or an Android cold-process proof. A failed G01 requires explicit plan/spec revision before shipping a further Android capability exception. Keep follow-up IDs and requirement-quality checklist ownership intact.

## Task Summary

| Phase | Tasks | Count |
| --- | --- | --- |
| Setup | T001-T003 | 3 |
| Foundations | T004-T011 | 8 |
| US1 (P1, MVP) | T012-T030 | 19 |
| US2 (P1) | T031-T041 | 11 |
| US3 (P2) | T042-T064 | 23 |
| US4 (P2) | T065-T072 | 8 |
| Polish / cross-cutting | T073-T082 | 10 |
| **Total** | **T001-T082** | **82** |

## Notes

Every checkbox is initially open and follows the required ID/optional-parallel/required-story-label/path format. Task IDs are execution-order identifiers; the dependency rules above take precedence for optional parallel work. User-story checkpoints are acceptance milestones, not permission requests to stop authorized work. Do not modify unrelated work, add speculative features, bypass system/user notification settings or mark required evidence complete without running the checks.
