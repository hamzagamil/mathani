---

description: "Tasks for Prayer Times and Athan (spec rewritten 2026-11-02)"
---

# Tasks: Prayer Times and Athan

**Input**: Design documents from `specs/009-prayer-times/`. Read [plan.md](./plan.md),
[spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md),
[contracts/location-api.md](./contracts/location-api.md),
[contracts/prayer-ui-and-reminders.md](./contracts/prayer-ui-and-reminders.md) and
[quickstart.md](./quickstart.md) before starting a phase.

**Prerequisites**: plan.md and spec.md (required). This replaces the first draft's tasks, which
are in git history.

**Starting point**: Much of the code already exists on `008-web-app` (plan → Source Code marks
each file KEEP, CHANGE, NEW or DELETE). Tasks below change existing files unless they say
"create". Do not rewrite working code that a task does not mention.

**Tests**: The spec's success criteria require automated evidence: SC-002 reference fixtures,
SC-004 no duplicate or stale alerts, SC-006 Qiyam times. Test tasks are included only for
those, plus keeping the existing prayer suites passing. Device trials are in
[quickstart.md](./quickstart.md) and are recorded in `specs/009-prayer-times/validation/`.

**Organization**: Tasks are grouped by user story so each story can be built and tested on its
own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on unfinished tasks).
- **[Story]**: US1–US6 from spec.md.

## Path Conventions

Single Flutter project:
- **Dart**: `lib/`, tests in `test/` and `integration_test/`.
- **Android**: `android/app/src/main/kotlin/app/mathani/mathani/`, JVM tests in
  `android/app/src/test/kotlin/app/mathani/mathani/`.
- **iOS**: `ios/Runner/`.
- **Web**: `web/`; Pages Functions in `functions/` are unchanged.
- **Localization**: strings in `lib/app/l10n/app_en.arb` and `lib/app/l10n/app_ar.arb`.
  Regenerate with `flutter gen-l10n` after editing them.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Remove what the new design drops and add the empty catalogue.

- [X] T001 Remove `flutter_secure_storage` from `pubspec.yaml`, run `flutter pub get`, and record the dependency change in `specs/009-prayer-times/validation/dependencies.md`.
- [X] T002 [P] Delete the alarm spike:
  - Delete `android/app/src/main/kotlin/app/mathani/mathani/PrayerMediaBridge.kt` and its `PrayerMediaBridge.register(...)` call in `MainActivity.kt`.
  - Delete `integration_test/prayer_alarm_spike_test.dart`.
  - In `lib/main.dart`, remove `prayerAlarmSpikeEnabled`, `initializePrayerAlarmSpike` and `prayerAlarmSpikeRoute`.
  - In `lib/features/recitation/media_handler.dart`, remove the `PRAYER_ALARM_SPIKE` flag, `_spikeChannel` and `initializePrayerAlarmSpike()`. Keep `pauseMemorizationForPrayer`.
- [X] T003 [P] In `lib/features/prayer_times/prayer_time_zones.dart`, import `package:timezone/data/latest_10y.dart` instead of `latest_all.dart` (research R11).
  - *Done 2026-11-02, then reversed:* `latest_10y` lacks 253 link zones (e.g. `Europe/Oslo`) that GeoNames returns, so `latest_all` stays. See research R11 and validation/dependencies.md.
- [X] T004 [P] Create `assets/prayer/athan_catalogue.json` with `{"version": 1, "recordings": []}` and confirm `assets/prayer/` is listed under `flutter: assets:` in `pubspec.yaml`.
- [ ] T005 [P] Before any feature change, record the baseline in `specs/009-prayer-times/validation/baseline.md`: Android and iOS release size from `dart run tool/size_check.dart`, and cold start on the Galaxy A15.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Schema 2, storage in `user.db`, the platform interface and the app-level
coordinator. Every story depends on this phase.

- [X] T006 Rewrite `lib/features/prayer_times/prayer_models.dart` to the data model's schema 2. The constraints below are quoted from data-model.md:
  - **`PrayerState`**:
    - `schemaVersion` (`2`), `places`, `myLocation` (Place or null), `current`, `alerts`, `generation`, `movedNotice`.
    - `current`: `"myLocation"` or a place `id`. "Must point to an existing place, or to `myLocation` when that is non-null".
    - A getter `isSetUp` is false when `places` is empty and `myLocation` is null.
  - **`Place`**:
    - `id`, `name`, `city`, `region`, `countryCode`, `latitude`, `longitude`, `timezoneId`, `source` (`location`/`search`/`estimate`), `calculation`.
    - `name`: "1–80 characters, trimmed, no control characters".
    - `latitude`, `longitude`: "Rounded to 2 decimal places. Range −90..90 and −180..180".
    - `countryCode`: "ISO 3166-1 alpha-2, or empty".
    - `timezoneId`: a valid IANA ID.
  - **`CalculationSettings`**:
    - `method`: 11 values with ids `muslim_world_league`, `egyptian`, `umm_al_qura`, `karachi`, `isna`, `dubai`, `kuwait`, `qatar`, `singapore`, `turkey`, `moonsighting_committee`.
    - `methodChosen` (bool), `asr` (`standard`/`hanafi`, default `standard`), `highLatitudeRule` (`middle_of_night`/`seventh_of_night`).
    - `offsets`: map of the five prayers to int, "Values −30..30 minutes. Missing key = 0".
  - **`AlertSettings`**:
    - `prayers`: set of the five prayers, "Never `sunrise`".
    - `sound`: recitation id, `tone` or `silent`.
    - `athan`: `opening`/`full`, default `opening`.
    - `qiyam`: default `false`.
  - **`Alert`**: `id` (31-bit int), `kind`, `atUtc`, `title`, `body`, `sound`, `full`, `fullPath`, `generation`.
  - **`DaySchedule` and `PrayerEvent`**: `status` is `normal`/`adjusted`/`unavailable`; `adjustedBy` is a set of `highLatitude` and `offset`; plus `qiyamUtc` and `qiyamUnavailableReason`.
  - Delete `PrayerMadhhab`, `LocationSource`, `ReminderState`, `ReminderClaimOwner`, `ReminderCapability`, `ScheduledReminder`, `ReminderPreferences` and `acknowledgedFallbacks`. Rename download status to `absent`/`downloading`/`ready`/`failed`.
  - JSON round-trip: parsing throws `FormatException` on any violated rule.
- [X] T007 [P] In `lib/data/user_repository.dart`:
  - Add `Future<String?> readPreference(String key)`, `Future<void> writePreference(String key, String value)` and `Future<void> deletePreference(String key)` on the `preferences` table.
  - Change `loadStartup()` to query `preferences` with `where: "key != 'prayer.state'"`, so the prayer JSON is never read before the first frame.
- [X] T008 Rewrite `lib/features/prayer_times/prayer_repository.dart` as `PrayerRepository(UserRepository)` with key `prayer.state`:
  - `load()` returns an empty (not set up) `PrayerState` when the value is missing, fails to parse, or has an unknown `schemaVersion`.
  - In those cases it does not overwrite the stored value until the next `save()`.
  - `save(state)` and `delete()` are serialized through one future chain.
  - Delete `SecurePrayerSnapshotStore` and all session-only code.
- [X] T009 Rewrite `lib/features/prayer_times/prayer_services.dart`:
  - Trim `PrayerFailure` to `locationDenied`, `locationUnavailable`, `timezoneUnresolved`, `providerUnavailable`, `offline`, `rateLimited`, `calculationUnavailable`, `conventionOutOfRange`, `audioUnavailable`, `notificationsDenied`.
  - Delete `PrayerSnapshotStore` and `NoPrayerNotifications`.
  - Define `abstract interface class PrayerAlertPlatform`:
    - `Future<AlertStatus> status()`, returning `notifications` (`granted|denied|notDetermined|unsupported`) and `exactAlarms` (`bool?`), without prompting.
    - `Future<AlertStatus> requestPermission()`.
    - `Future<void> openSettings({bool exactAlarms = false})`.
    - `Future<int> replace(List<Alert> alerts, int generation)`.
    - `Future<void> cancelAll()`.
    - `Stream<PrayerPlatformEvent> events`, with `opened(kind, alertId)` and `athanStarted`.
- [X] T010 Adapt `lib/features/prayer_times/prayer_calculator.dart` to the schema 2 types without changing results for the existing five methods:
  - Map `asr` to `adhan.Madhab` and `highLatitudeRule` to the existing night-fraction logic.
  - Return `DaySchedule` with `status`/`adjustedBy`, and keep `qiyamStart`.
  - Keep the existing polar-day check, Asr correction and Umm al-Qura Ramadan handling.
- [X] T011 Create `lib/features/prayer_times/prayer_alerts.dart` with an app-scoped, lazily created `PrayerAlerts` coordinator:
  - Constructor takes `PrayerRepository`, a `PrayerAlertPlatform` factory, a `PrayerCalculator` loader and the location client.
  - `onAppActive()` is a no-op placeholder that later stories fill in.
  - A `ChangeNotifier`-free `onStateSaved(PrayerState)` hook.
  - No work in the constructor.
- [X] T012 Wire `PrayerAlerts` in `lib/main.dart` and `lib/app/app.dart`:
  - Call `PrayerAlerts.onAppActive()` from `WidgetsBinding.instance.addPostFrameCallback` on start, and on `AppLifecycleState.resumed`.
  - Never before the first frame (FR-031, R11).
  - Expose the instance to `PrayerTimesScreen` the same way existing services are passed.
- [X] T013 Update `lib/platform/prayer_notifications.dart` (conditional export), `lib/platform/prayer_notifications_io.dart` and `lib/platform/prayer_notifications_web.dart` so each exports a `PrayerAlertPlatform` factory implementing T009's interface.
  - Keep the existing iOS and Android code paths compiling; their behaviour changes in US4.
  - Add `clearLegacyPrayerStorage()`: a no-op on io. On web, it removes the `localStorage` entries written by `flutter_secure_storage` 10.3.4's web implementation. Check that package's web source in the pub cache for the exact key names before deleting the package.
- [X] T014 Rewrite the skeleton of `lib/features/prayer_times/prayer_controller.dart` against schema 2:
  - Keep `load`/`save` through `PrayerRepository`.
  - Hold `viewedPlaceId` separately from `state.current`.
  - Call `PrayerAlerts.onStateSaved` after every save.
  - Delete acknowledgement, session-only, `needsAttention` and claim code.
- [X] T015 Make the existing suites compile and pass against schema 2:
  - Update `test/features/prayer_times/*.dart` and `test/platform/*.dart`.
  - Delete tests that only cover removed behaviour: secure storage, session-only, acknowledgements, claims.
  - Add a repository test: unknown `schemaVersion` loads as not set up and the stored value is unchanged until `save`.
  - Run `flutter analyze` and `flutter test test/features/prayer_times test/platform`.

**Checkpoint**: The app builds on Android, iOS and web. Prayer Times opens with an empty state.
Existing reader, recitation and memorization tests pass.

---

## Phase 3: User Story 1 — See today's prayer times where I am (Priority: P1) 🎯 MVP

**Goal**: Set a place by approximate location, city search or the suggested estimate. See
today's six times, the next prayer and a countdown, offline after setup, with previous and next
day navigation.

**Independent Test**: [quickstart.md](./quickstart.md) scenarios 1.1–1.7.

- [X] T016 [P] [US1] Location client changes in `lib/platform/prayer_location.dart`:
  - Request `LocationAccuracy.low` with `timeLimit: Duration(seconds: 15)`.
  - Add `double roundCoordinate(double v) => (v * 100).round() / 100`. Apply it to the position before `POST /api/prayer-resolve` and to every returned place.
  - Drop `accuracyMeters` and `approximate`.
  - Map endpoint `source` `device`/`manual`/`ip` → `location`/`search`/`estimate`.
- [X] T017 [P] [US1] Make location approximate-only:
  - Remove `ACCESS_FINE_LOCATION` from `android/app/src/main/AndroidManifest.xml`.
  - Add `<key>NSLocationDefaultAccuracyReduced</key><true/>` to `ios/Runner/Info.plist`.
  - Change the `NSLocationWhenInUseUsageDescription` text in `ios/Runner/Info.plist`, `ios/Runner/en.lproj/InfoPlist.strings` and `ios/Runner/ar.lproj/InfoPlist.strings` to say that only approximate location is used, to set the prayer-times place.
- [X] T018 [US1] Add first-place actions to `lib/features/prayer_times/prayer_controller.dart`:
  - `useMyLocation(language)` detects and resolves, then sets `myLocation` with `source: location` and `current = "myLocation"`.
  - `choosePlace(place)` from a search result or the estimate appends to `places`, sets `current` to its id when not set up, and saves.
  - New places get `CalculationSettings(method: suggestion(countryCode), methodChosen: false, highLatitudeRule: |lat| > 48 ? seventh_of_night : middle_of_night)`.
  - Map failures to `locationDenied`/`locationUnavailable`/`offline`/`timezoneUnresolved`/`providerUnavailable`/`rateLimited`. Never prompt for location twice in one session after a denial.
- [X] T019 [US1] Rebuild `lib/features/prayer_times/location_setup_sheet.dart` as the first-time screen and city search (contract → Screens):
  - **First-time screen**: one line on why location is used, plus "Use my location" and "Search for a city". No permission request until "Use my location" is tapped.
  - **Search field**: 350 ms debounce, stale-response discard (existing).
  - **Results**: city, region and country, with GeoNames attribution.
  - **Suggested row**: when the sheet opens online and location is denied or unavailable, call `approximate()`. Show a first row "Suggested: {city}, {country} — estimated from your internet connection". Tapping it calls `choosePlace` with `source: estimate`; no separate confirm step (contract location-api → Client changes 2).
  - **States**: no results, offline, error with retry.
- [X] T020 [US1] Rebuild the schedule in `lib/features/prayer_times/prayer_times_screen.dart`:
  - **Not set up**: show T019's first-time screen.
  - **Header**:
    - Place name.
    - Local date with previous and next day arrows; the selected day is screen state.
    - Method name and Asr setting.
    - The zone name when `place.timezoneId` differs from the phone's zone.
  - **Rows**:
    - Fajr, Sunrise (labelled "not a prayer", no alert control), Dhuhr, Asr, Maghrib, Isha.
    - Each row shows its time in the place's zone and an "adjusted" or "unavailable" mark.
  - **Next prayer**: from `nextPrayer`, highlighted with a countdown that updates every second, today only.
  - **No network calls** on open (FR-004).
- [X] T021 [P] [US1] Add US1 strings to `lib/app/l10n/app_en.arb` and `lib/app/l10n/app_ar.arb`: first-time copy, search, Suggested row, not-a-prayer label, zone note, day arrows, and failure lines for T018's reasons. Run `flutter gen-l10n`.
- [X] T022 [P] [US1] Add tests:
  - `test/features/prayer_times/prayer_setup_test.dart`: rounding to 2 decimals before resolve; source mapping; a denial does not re-prompt.
  - `test/features/prayer_times/prayer_setup_widget_test.dart`: first-time screen issues no permission call before the tap; Suggested row selects without a confirm step; day arrows change the date; Sunrise has no alert control. Arabic and English at 320×568 with 1.5× text.
  - *Done 2026-11-02:* these cases are in `test/features/prayer_times/prayer_controller_test.dart` and `prayer_screens_test.dart`.

**Checkpoint**: US1 works alone. Run quickstart 1.1–1.7 on one Android phone and one iPhone and
record the results in `specs/009-prayer-times/validation/us1.md`.

---

## Phase 4: User Story 2 — Use the calculation my community follows (Priority: P1)

**Goal**: 11 methods with country suggestions, the two-choice Asr setting, high-latitude rules
and per-prayer offsets, saved per place.

**Independent Test**: [quickstart.md](./quickstart.md) scenarios 2.1–2.5.

- [X] T023 [US2] Extend `lib/features/prayer_times/prayer_calculator.dart` (research R2, data model → order of computation):
  - Map all 11 methods to `adhan.CalculationMethodParameters` presets: `muslimWorldLeague`, `egyptian`, `ummAlQura`, `karachi`, `northAmerica`, `dubai`, `kuwait`, `qatar`, `singapore`, `turkiye`, `moonsightingCommittee`.
  - After the existing high-latitude cap and Asr correction, re-apply `params.methodAdjustments` to Fajr, Asr and Isha. Those values are overwritten, so their built-in minute offsets are otherwise lost.
  - Then add the place's `offsets` (−30..30 min) to the five prayers and round to the minute.
  - Set `adjustedBy.offset` on any prayer with a non-zero offset.
  - Compute Qiyam from Maghrib and the next day's Fajr *after* offsets.
  - Bump the fingerprint `convention` to 2.
- [X] T024 [P] [US2] Replace `CalculationSettings.suggestion(countryCode)` in `lib/features/prayer_times/prayer_models.dart` with the R2 table:
  - EG→egyptian; SA, YE→umm_al_qura; AE→dubai; KW→kuwait; QA→qatar; TR→turkey.
  - SG, MY, BN, ID→singapore; PK, BD, IN, AF→karachi; US, CA→isna; GB, IE→moonsighting_committee.
  - Anything else→muslim_world_league.
- [ ] T025 [P] [US2] Collect official timetable samples (research R3) into `tool/prayer/official_timetables.json`:
  - Two dates each (one in summer or a daylight-saving date) for Dubai (IACAD), Kuwait City (Awqaf), Doha (Qatar Awqaf), Singapore (MUIS), Istanbul (Diyanet) and London (moonsighting.com).
  - Store per sample: city, coordinates, method, Asr setting, date, the six times and the source URL with the date it was fetched.
  - Document the procedure in `tool/prayer/README.md`.
- [ ] T026 [US2] Extend `test/features/prayer_times/prayer_calculator_test.dart`:
  - The existing 10-city fixtures still pass for the five original methods, both Asr settings and the daylight-saving and high-latitude cases.
  - Every sample in `tool/prayer/official_timetables.json` is within 1 minute.
  - Offsets of +5 and −30 move only the target prayer and mark it adjusted.
  - The default high-latitude rule is `seventh_of_night` above 48° (SC-002).
  - *2026-11-02:* everything except the official-timetable samples passes (`prayer_calculator_test.dart`). Waiting on T025.
- [X] T027 [US2] Add `updateCalculation(placeId, {method, asr, highLatitudeRule, offsets})` to `lib/features/prayer_times/prayer_controller.dart`:
  - Setting `method` sets `methodChosen = true`.
  - Increment `generation` when the place is current.
  - Save. Offsets are clamped to −30..30.
- [X] T028 [US2] Rebuild `lib/features/prayer_times/calculation_sheet.dart` for the viewed place:
  - 11 methods, with the country suggestion labelled "Suggested".
  - Asr choice "Standard (Shafi'i, Maliki, Hanbali)" / "Hanafi", with the note "changes Asr only".
  - Two high-latitude rules, each with a one-line explanation.
  - Five offset steppers (−30..+30, step 1, long-press repeat).
  - The schedule behind updates live.
  - 48 dp / 44 pt targets and semantic labels with values.
- [X] T029 [P] [US2] Add US2 strings (11 method names, Asr labels and note, rule explanations, offset labels) to `lib/app/l10n/app_en.arb` and `lib/app/l10n/app_ar.arb`, then run `flutter gen-l10n`.

**Checkpoint**: US1 + US2 make a releasable schedule-only feature. Record quickstart 2.1–2.5 in
`specs/009-prayer-times/validation/us2.md`.

---

## Phase 5: User Story 3 — Keep the right place when I travel or save places (Priority: P2)

**Goal**: "My location" follows the reader when the app opens. Saved places can be viewed
without changing alerts. Delete flows are safe.

**Independent Test**: [quickstart.md](./quickstart.md) scenarios 3.1–3.5.

- [X] T030 [US3] Add place management to `lib/features/prayer_times/prayer_controller.dart`:
  - `viewPlace(id)` changes screen state only.
  - `usePlace(id)` and `useMyLocation()` set `current`, increment `generation` and save.
  - `renamePlace(id, name)`: 1–80 characters, trimmed, no control characters. Increment `generation` only when the place is current.
  - `deletePlace(id, {String? replacementId, bool alertsOff = false})`: deleting the current place requires a replacement or `alertsOff`. Removing the last place with no `myLocation` returns to not set up, with all alerts off.
  - `deleteAllPrayerData()` deletes `prayer.state` and calls `PrayerAlertPlatform.cancelAll()`. It keeps recitation downloads.
- [X] T031 [US3] Implement the "My location" refresh in `PrayerAlerts.onAppActive()` in `lib/features/prayer_times/prayer_alerts.dart` (research R4). It runs only when `current == "myLocation"`:
  1. Skip if the last refresh was under 30 minutes ago (in-memory).
  2. Check permission with `Geolocator.checkPermission()`, never request. Skip unless it is granted.
  3. Get a low-accuracy position and round it.
  4. If it is more than 10 km from `myLocation`, call resolve.
  5. On success, replace `myLocation`:
     - Keep its `calculation`.
     - If `methodChosen` is false, replace `method` with the new country's suggestion.
     - If the city changed, set `movedNotice` to the city.
     - Increment `generation` and save.
  6. On any failure, keep the previous place silently.
- [X] T032 [P] [US3] Add tests for T031 in `test/features/prayer_times/prayer_locations_test.dart`:
  - Moved 5 km: no resolve call.
  - Moved 15 km: resolve, then replace and set `movedNotice`.
  - Offline: unchanged.
  - Permission not granted: no prompt and no call.
  - `methodChosen` true keeps the method; false switches it to the new country's suggestion.
  - Fixed city current: no refresh.
- [X] T033 [US3] Rebuild `lib/features/prayer_times/locations_sheet.dart`:
  - "My location" row with a refresh action, then saved places with name, city and country; the current place is marked.
  - Tapping a row calls `viewPlace`. A "Use this place" button appears while viewing a non-current place.
  - Rename and delete. Deleting the current place opens a dialog to pick a replacement or turn alerts off.
  - "Add a place" opens T019's search in add mode.
  - The list is a `ListView.builder`.
- [X] T034 [US3] In `lib/features/prayer_times/prayer_times_screen.dart`:
  - Show the viewed place's schedule in its own zone, with a "Viewing — alerts follow {current}" note when it is not current.
  - Show a one-time "Moved to {city}" banner when `movedNotice` is set, and clear it after it is shown.
- [X] T035 [P] [US3] Add US3 strings (My location, Use this place, viewing note, moved banner, delete dialog, rename) to `lib/app/l10n/app_en.arb` and `lib/app/l10n/app_ar.arb`, then run `flutter gen-l10n`.

**Checkpoint**: Record quickstart 3.1–3.5 in `specs/009-prayer-times/validation/us3.md`.

---

## Phase 6: User Story 4 — Get an athan alert at prayer time (Priority: P2)

**Goal**: Per-prayer alerts that fire locked or closed, through reboots, for 7+ days, with no
duplicates or stale alerts. Sound is the opening takbirat clip, the tone or silent.

**Independent Test**: [quickstart.md](./quickstart.md) scenarios 4.1–4.9. If no recording is
cleared yet (research R10), test with "Simple tone".

- [X] T036 [US4] Implement `buildAlerts(PrayerState state, DateTime nowUtc, PrayerCalculator calc, AthanCatalogue catalogue, AppLocalizations l10n)` in `lib/features/prayer_times/prayer_alerts.dart`, moving the reusable parts of `prayer_reminder_scheduler.dart`. It returns the next 60 alerts (data model → Alert):
  - Only the current place, and only prayers in `alerts.prayers`. Never Sunrise. Skip `unavailable` events.
  - `id` = 31-bit hash of (place id, local date, kind), stable across refills.
  - Title is the prayer name; body is the time and the place name, localized.
  - `sound`: `alerts.sound`, or `tone` when that recitation is not in the catalogue.
  - `generation` from the state.
  - Delete `lib/features/prayer_times/prayer_reminder_scheduler.dart`.
- [X] T037 [US4] Implement refill in `lib/features/prayer_times/prayer_alerts.dart`:
  - `onStateSaved` and `onAppActive` call `buildAlerts`, then `platform.replace(alerts, generation)`. When no prayer is enabled or the state is not set up, they call `platform.cancelAll()`.
  - Refills are serialized; the latest state wins.
  - Exposes the last `AlertStatus` and pending count for the Alerts sheet.
- [X] T038 [P] [US4] Add `test/features/prayer_times/prayer_alerts_test.dart` (SC-004):
  - At most 60 alerts, all in the future.
  - Sunrise is never included; unavailable events are skipped.
  - Ids are stable across two builds.
  - Changing method or place and rebuilding yields no stale id with an old time.
  - The generation increases.
  - An empty `prayers` set gives `cancelAll`.
- [X] T039 [US4] Simplify `android/app/src/main/kotlin/app/mathani/mathani/PrayerAlarmStore.kt` to plain `SharedPreferences` JSON:
  - Store the current `generation` and the list of `{id, kind, atUtcMs, title, body, sound, full, fullPath}`.
  - Delete the Keystore AES-GCM code, claim and consume states, and first-unlock gating.
  - Operations: `replace(generation, alerts)`, `get(id)`, `remove(id)`, `future(nowMs)`, `clear()`.
- [X] T040 [US4] Rework `android/app/src/main/kotlin/app/mathani/mathani/PrayerNotificationsPlugin.kt` to the contract's method channel `app.mathani/prayer_notifications`:
  - **`status`** and **`requestPermission`**: `POST_NOTIFICATIONS` on API 33+; `canScheduleExactAlarms()` on API 31+.
  - **`openSettings`**: app notification settings, or `ACTION_REQUEST_SCHEDULE_EXACT_ALARM` when `exactAlarms` is true.
  - **`replace`**:
    - Store the list, cancel `PendingIntent`s for ids no longer present, and set one alarm per alert.
    - Use `setExactAndAllowWhileIdle` when exact alarms are allowed, otherwise `setAndAllowWhileIdle`.
    - Return the count.
  - **`cancelAll`**.
  - **Channels**, created on first use: `prayer_<sound>_v1` with sound `res/raw/athan_<id>_opening` or `res/raw/qiyam_tone`, `prayer_silent_v1` with no sound, and the existing Qiyam channel.
  - **Events**: emit `opened {kind, alertId}` when `MainActivity` is launched from an alert intent.
- [X] T041 [US4] Rework `android/app/src/main/kotlin/app/mathani/mathani/PrayerAlarmReceiver.kt`:
  - **On an alarm**:
    - Load the alert from the store. Ignore it if missing, from an older generation, or more than 15 minutes late (`now - atUtcMs > 15 * 60_000`).
    - Otherwise post the notification on its sound channel with a content intent to `MainActivity` carrying the alert id and kind, then `remove(id)`.
  - **On `BOOT_COMPLETED`, `TIME_SET`, `TIMEZONE_CHANGED` and `SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED`**: re-set alarms for `future(now)` only.
- [X] T042 [P] [US4] Rewrite `android/app/src/test/kotlin/app/mathani/mathani/PrayerAlarmStoreTest.kt` and add `PrayerAlarmReceiverTest.kt`, testing the receiver's decision logic extracted as a pure function:
  - Store replace removes old ids.
  - An older generation is ignored.
  - 14 minutes late posts; 16 minutes late is dropped.
  - Boot restore sets only future alerts.
  - A delivered alert is removed, so it never posts twice.
- [X] T043 [US4] Rework the io adapter in `lib/platform/prayer_notifications_io.dart`:
  - **Android**: delegate to the method channel from T040.
  - **iOS**, through `flutter_local_notifications`:
    - Initialize without permission requests; `requestPermission()` asks for alert and sound.
    - `replace()` cancels app-owned pending ids not in the list. It then calls `zonedSchedule` for each alert at its absolute UTC time (`tz.UTC`) with `DarwinNotificationDetails(sound: 'athan_<id>_opening.caf' | 'qiyam_tone.caf' | null for silent)`, then reads pending requests back and returns the count.
    - Cap at 60.
  - Map plugin notification responses to `opened` events.
  - Remove the Library/Sounds copy from `rootBundle` (T044 bundles the files).
  - *Done 2026-11-02:* Dart analysis passes. Not built or run on iOS: no Mac or iPhone was available.
- [X] T044 [US4] Bundle iOS sounds natively:
  - Add `ios/Runner/qiyam_tone.caf` (moved from `assets/prayer/qiyam_tone.caf`) to the Runner target's Copy Bundle Resources in `ios/Runner.xcodeproj/project.pbxproj`.
  - Remove `assets/prayer/qiyam_tone.caf` and its pubspec entry, so Android no longer ships the CAF.
  - Confirm `android/app/src/main/res/raw/qiyam_tone.wav` is listed in `res/raw/prayer_keep.xml`.
  - *Done 2026-11-02:* the Xcode project edit has not been built.
- [X] T045 [P] [US4] Adapt the web adapter in `lib/platform/prayer_notifications_page.dart` and `lib/platform/prayer_notifications_web.dart` to `replace(alerts, generation)`:
  - Keep the in-memory timers, browser notification when permitted and the tone or opening sound through `AthanPlayer`.
  - Do not replay missed alerts on revisit. Show "Play athan" when autoplay is blocked.
- [X] T046 [US4] Update `lib/features/prayer_times/athan_catalogue.dart`:
  - Load `assets/prayer/athan_catalogue.json` (data model → AthanRecording).
  - Expose `soundChoices`: the recitations, then `tone` and `silent`.
  - `preview(choice)` plays the opening span for a recitation (`openingEndMs`) or the tone, through `AthanPlayer`.
- [X] T047 [US4] Add alert actions to `lib/features/prayer_times/prayer_controller.dart`:
  - `setPrayerAlert(kind, enabled)`: on the first enable while `status().notifications` is `notDetermined`, call `requestPermission()` first. If it is denied, keep the choice.
  - `setSound(choice)`.
  - Each saves with `generation++`.
- [X] T048 [US4] Rebuild `lib/features/prayer_times/reminder_settings.dart` as the Alerts sheet (contract → Screens):
  - Five switches with no Sunrise, and an "Alerts follow {place}" line.
  - Status lines: "Notifications blocked" + Open settings; Android "Exact alarms off — alerts may be a few minutes late" + Allow.
  - Sound list: recitations, Simple tone and Silent, each with preview and Stop. One preview at a time; closing the sheet stops it.
  - Announce status changes to screen readers.
- [X] T049 [US4] In `lib/features/prayer_times/prayer_notification_open_host.dart`, handle `PrayerAlertPlatform.events` `opened` by pushing one `PrayerTimesScreen` route after the first frame. Keep the existing duplicate-route guard.
- [X] T050 [P] [US4] Add US4 strings (alert titles and bodies per prayer, Alerts sheet labels, status lines, sound names) to `lib/app/l10n/app_en.arb` and `lib/app/l10n/app_ar.arb`, then run `flutter gen-l10n`.

**Checkpoint**: With the tone, the feature is releasable through US4. Run quickstart 4.1–4.9 on an
Android phone (API 33+) and an iPhone, including the 20-alert timing trial and the 7-day and
reboot checks. Record them in `specs/009-prayer-times/validation/us4.md`.

---

## Phase 7: User Story 5 — Hear the full athan (Priority: P3)

**Goal**: Full athan plays in full on Android even when locked. On iPhone and web it plays in the
app (open, or after tapping the alert). It always has Stop, and Quran recitation pauses without
resuming.

**Independent Test**: [quickstart.md](./quickstart.md) scenarios 5.1–5.5. Needs at least one
catalogue recording with cleared rights (research R10).

- [X] T051 [US5] Create `android/app/src/main/kotlin/app/mathani/mathani/AthanPlaybackService.kt`, a foreground service of type `mediaPlayback`:
  - `onStartCommand(alertId, title, body, fullPath)` calls `startForeground` with an ongoing notification on a silent `prayer_athan_playback_v1` channel. The notification has a Stop action and a content intent to `MainActivity`.
  - Request `AUDIOFOCUS_GAIN` with `USAGE_ALARM`/`CONTENT_TYPE_SONIFICATION`, then play `fullPath` with `MediaPlayer`.
  - On completion, Stop, error or any focus loss: release the player, abandon focus and `stopSelf()`.
  - Send `athanStarted` through `PrayerNotificationsPlugin` if a Flutter engine is attached.
  - Declare it in `android/app/src/main/AndroidManifest.xml` with `android:foregroundServiceType="mediaPlayback"` and `android:exported="false"`.
- [X] T052 [US5] In `android/app/src/main/kotlin/app/mathani/mathani/PrayerAlarmReceiver.kt`, when an alert has `full = true`, `File(fullPath).exists()`, and exact alarms are allowed (or API < 31), start `AthanPlaybackService` with `ContextCompat.startForegroundService` instead of posting.
  - On `ForegroundServiceStartNotAllowedException`, or when those conditions fail, post the opening-clip notification as in T041.
  - Extend `PrayerAlarmReceiverTest.kt` for these branches.
- [X] T053 [US5] Set `full` and `fullPath` in `lib/features/prayer_times/prayer_alerts.dart`:
  - `full` is true only when `alerts.athan == full` and `AthanDownloads.availabilityOf(recording) == ready`.
  - `fullPath` is the downloaded file's absolute path, Android only.
  - On iOS, full-mode alerts use `DarwinNotificationDetails(presentSound: false)` in T043's `replace()`.
- [X] T054 [US5] Add the in-app full athan to `lib/features/prayer_times/prayer_alerts.dart`:
  - While the app is active on iOS or web and the next alert is `full`, keep a `Timer` for it.
  - When it fires, call `AthanPlayer.playFull(recording)`, which pauses Quran recitation and memorization and never resumes them.
  - Cancel the timer on `AppLifecycleState.paused` and on refill.
- [X] T055 [US5] When `opened` arrives for a full-mode alert with a ready recording on iOS or web, call `AthanPlayer.playFull` after pushing Prayer Times, in `lib/features/prayer_times/prayer_notification_open_host.dart`. On Android, `athanStarted` pauses memorization through `RecitationMediaHandler.pauseMemorizationForPrayer`, wired in `lib/main.dart`.
  - *Done 2026-11-02:* `athanStarted` reaches `PrayerAlerts`, which calls `MemorizationController.pause` directly. `RecitationMediaHandler.pauseMemorizationForPrayer` was removed with the spike.
- [X] T056 [US5] Add athan length to `lib/features/prayer_times/reminder_settings.dart`:
  - "Opening takbirat" / "Full athan", with the platform line from the contract (Android, iPhone or web).
  - When full is selected and the recording is not downloaded: a download row using `AthanDownloads.prepareFull` with progress and retry, plus the line "Until downloaded, alerts play the opening".
  - A Stop button stays visible while an app-played athan is playing.
  - Add `setAthanLength(mode)` to `lib/features/prayer_times/prayer_controller.dart` (`generation++`, save).
- [X] T057 [P] [US5] Add US5 strings (athan length labels, the three platform lines, download states, Stop) to `lib/app/l10n/app_en.arb` and `lib/app/l10n/app_ar.arb`, then run `flutter gen-l10n`.
- [ ] T058 [US5] When rights are cleared for each recording (research R10), add it:
  1. Run `tool/prayer/prepare_athan.py` to produce `android/app/src/main/res/raw/athan_<id>_opening.ogg` and `ios/Runner/athan_<id>_opening.caf` (under 30 000 ms, ending after the fourth "Allahu akbar").
  2. Add the CAF to Copy Bundle Resources in `ios/Runner.xcodeproj/project.pbxproj`.
  3. Add the entry, with `fullUrl`/`fullSha256`/`fullBytes`/`source`/`licence`/`attribution`, to `assets/prayer/athan_catalogue.json`.
  4. Upload the full file to the web host's static assets.
  5. Add attribution to `docs/licences.md`.
  - Do not add any recording whose rights are unconfirmed.

**Checkpoint**: Record quickstart 5.1–5.5 in `specs/009-prayer-times/validation/us5.md`.

---

## Phase 8: User Story 6 — Get a Qiyam reminder (Priority: P3)

**Goal**: An optional nightly tone at the start of the last third of the night, separate from
prayer alerts.

**Independent Test**: [quickstart.md](./quickstart.md) scenarios 6.1–6.4.

- [X] T059 [US6] Add Qiyam to `buildAlerts` in `lib/features/prayer_times/prayer_alerts.dart`:
  - When `alerts.qiyam` is true, add an alert with `kind: qiyam` and `sound: tone` at each night's `qiyamUtc`.
  - Skip nights where it is null.
  - Count Qiyam within the 60-alert cap.
  - On Android it uses the existing Qiyam channel (T040).
  - Extend `test/features/prayer_times/prayer_alerts_test.dart`: Qiyam on adds one per night; off removes only Qiyam ids.
- [X] T060 [P] [US6] Update `test/features/prayer_times/qiyam_calculator_test.dart` for SC-006. Five places or dates, with Qiyam computed after offsets, must match Maghrib + ⅔ × (next Fajr − Maghrib) within 1 minute. A night with an unavailable boundary gives null and a reason.
- [X] T061 [US6] Add `setQiyam(bool)` to `lib/features/prayer_times/prayer_controller.dart` (save, `generation++`). In `lib/features/prayer_times/reminder_settings.dart`, add the Qiyam switch:
  - Separate from the five prayers and off by default.
  - Shows tonight's local time, the one-line "start of the last third of the night, from Maghrib to Fajr" explanation, and the unavailable reason when there is one.
  - Asks for notification permission on first enable, as in T047.
- [X] T062 [P] [US6] Add US6 strings to `lib/app/l10n/app_en.arb` and `lib/app/l10n/app_ar.arb`, then run `flutter gen-l10n`.

**Checkpoint**: Record quickstart 6.1–6.4 in `specs/009-prayer-times/validation/us6.md`.

---

## Phase 9: Polish & Cross-Cutting Concerns

- [X] T063 [P] Remove strings no longer referenced (first-draft acknowledgement, secure-storage, horizon and P0x copy) from `lib/app/l10n/app_en.arb` and `lib/app/l10n/app_ar.arb`. Delete or trim `lib/features/prayer_times/prayer_copy.dart`. Run `flutter gen-l10n` and `flutter analyze`.
- [X] T064 [P] Update `docs/store/privacy.md` (research R12):
  - Approximate location only, sent to Mathani's server and GeoNames to find the place name and time zone; nothing kept on the server.
  - No precise or background location.
  - Alerts are local notifications; no encrypted-snapshot wording.
  - List the App Privacy and Data safety answers that must change before submission.
- [ ] T065 Update `integration_test/prayer_times_test.dart` to cover search → schedule → enable one alert with the tone → pending count > 0 → delete place → pending count 0. Run it on one Android device and one iOS device.
  - *2026-11-02:* rewritten in `integration_test/prayer_times_test.dart`. Not run: no Android or iOS device is connected.
- [ ] T066 Measure and record in `specs/009-prayer-times/validation/summary.md`:
  - Android and iOS size delta against T005's baseline (`dart run tool/size_check.dart`); explain anything over 1 MB.
  - Cold start on the Galaxy A15 and iPhone SE, with alerts on and "My location" current (≤ 2 s).
  - `integration_test/paging_perf_test.dart` in profile mode (60 fps).
- [ ] T067 Accessibility pass (quickstart Q2): every story with TalkBack and with VoiceOver, in Arabic and English, at the largest text size. Fix clipped text and missing semantic labels in the prayer screens. Record the results in `specs/009-prayer-times/validation/summary.md`.
- [ ] T068 Run the web checks (quickstart W1–W2):
  - Build with `flutter build web --wasm --release --no-web-resources-cdn`.
  - Prepare with `node tool/web_deploy.mjs --prepare-only`.
  - Test locally with `npx wrangler@4 pages dev build/web`.
  - Confirm `clearLegacyPrayerStorage()` removed the old entries.
  - Record the results.
  - Deploy only when the user asks.
  - *2026-11-02:* the web build and `--prepare-only` passed. The browser checks with `wrangler pages dev` are not done.
- [X] T069 Final run of `flutter analyze`, `flutter test`, `node --test tool/prayer/location_api_test.mjs` and the Android JVM tests. Consolidate pass, fail and blocked outcomes, plus open items (recording rights, store privacy answers), in `specs/009-prayer-times/validation/summary.md`. Missing device evidence stays marked open.
  - *Done 2026-11-02:* outcomes are in `validation/summary.md`. Device evidence stays open.

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: none.
- **Foundational (Phase 2)**: needs Setup. Blocks all stories.
- **US1 (Phase 3)**: needs Foundational. This is the MVP.
- **US2 (Phase 4)**: needs Foundational; its UI shows on US1's schedule screen (T020). The
  calculator and fixture tasks (T023–T026) can run alongside US1.
- **US3 (Phase 5)**: needs US1 (place setup and search).
- **US4 (Phase 6)**: needs Foundational and a place from US1. Independent of US2 and US3.
- **US5 (Phase 7)**: needs US4 (alert list, receiver, Alerts sheet). Real audio needs R10.
- **US6 (Phase 8)**: needs US4 (alert list and Alerts sheet). It can be done before US5, as the
  plan's delivery order suggests.
- **Polish (Phase 9)**: after the stories being released.

### Within each story

Models and calculator → controller actions → platform code → UI → strings → story tests and
quickstart checkpoint.

### Key task dependencies

- T006 → T008, T010, T014. T009 → T011, T013. T007 → T008. T011 → T012.
- T016 → T018 → T019, T020.
- T023 → T026. T025 → T026. T027 → T028.
- T030 → T033. T031 → T032. T031 → T034.
- T036 → T037 → T038. T039 → T040 → T041 → T042. T043 needs T044. T046 → T048. T047 → T048.
- T051 → T052. T053 → T054 → T055.
- T059 → T061.

---

## Parallel Examples

```text
# Phase 1, together:
T002 Delete the alarm spike (Dart and Kotlin files)
T003 Switch time zones to latest_10y
T004 Create the empty athan catalogue
T005 Record the size and cold-start baseline

# Phase 2, after T006:
T007 user_repository preference helpers     | T009 PrayerAlertPlatform interface

# US1, together:
T016 Location client rounding and low accuracy
T017 Manifest and Info.plist approximate location
T021 US1 strings
T022 US1 tests (after T018–T020 land)

# US2, alongside US1 once Phase 2 is done:
T024 Country suggestion table
T025 Official timetable samples

# US4, together:
T038 Alert-list tests (Dart)                | T042 Store and receiver tests (Kotlin)
T045 Web adapter                            | T050 US4 strings
```

---

## Implementation Strategy

### MVP first (US1 + US2)

1. Phase 1 → Phase 2 (the app builds, with Prayer Times empty).
2. US1: a schedule from location, search or the suggested estimate. Validate quickstart 1.x.
3. US2: methods, Asr and offsets. Validate quickstart 2.x.
4. **Stop and release-check**: a schedule-only Prayer Times with no notification permission at all.

### Incremental delivery

1. US3: travel and saved places.
2. US4: alerts with the tone. This can ship before any recording is cleared.
3. US6: Qiyam.
4. US5: full athan, plus recordings as their rights clear (T058).

Each step runs its quickstart checkpoint on one Android phone and one iPhone before the next.

---

## Notes

- Work is currently on `008-web-app`. Moving it to its own `009-prayer-times` branch is the user's
  decision (plan → Open items). These tasks do not switch branches.
- Do not commit, deploy or upload to stores unless the user asks.
- A checked task means the work is done and its checks ran. A mocked test or a compile is not a
  device result. Device outcomes go in `validation/`.
- `functions/` (location endpoints) must not change. `tool/prayer/location_api_test.mjs` should
  keep passing untouched.
