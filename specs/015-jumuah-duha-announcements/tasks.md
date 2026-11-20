# Tasks: Jumu'ah Alerts, Duha Reminder and Announcements

**Input**: Design documents from `specs/015-jumuah-duha-announcements/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included. The plan and quickstart name unit tests, matching the project's existing
`test/features/prayer_times` suite.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1 Friday label, US2 Jumu'ah reminder, US3 Duha, US4 Announcements

## Phase 1: Setup

- [X] T001 Add `firebase_core` and `firebase_messaging` (pinned versions) to `pubspec.yaml` and run `flutter pub get`

## Phase 2: Foundational (blocks US2 and US3)

- [X] T002 Add `jumuah` and `duha` to `PrayerKind` in `lib/features/prayer_times/prayer_models.dart` (after `qiyam`; never in `dailyPrayers`), and make every exhaustive `switch` over `PrayerKind` compile (`prayer_copy.dart` `prayerName`, channel names)
- [X] T003 [P] Accept kinds `jumuah` and `duha` in `PrayerAlarmStore.kt`, and treat them like `qiyam` (tone sound, `QIYAM_CHANNEL`, never full) in `PrayerAlarmReceiver.kt`, `PrayerNotificationsPlugin.kt` and `PrayerAlarmStore.decide` under `android/app/src/main/kotlin/app/mathani/mathani/`
- [X] T004 Rename the Qiyam Android channel's display string to "Reminders" / "التذكيرات" (`prayerChannelQiyam` value) in `lib/app/l10n/app_en.arb` and `app_ar.arb`

## Phase 3: User Story 1 - Friday alerts say Jumu'ah (P1) 🎯 MVP

**Goal**: On the place's Friday, the Dhuhr alert title and schedule label say Jumu'ah.

**Independent Test**: quickstart Manual 1.

- [X] T005 [P] [US1] Add `bool get isFriday => localDate.weekday == DateTime.friday` to `DaySchedule` in `lib/features/prayer_times/prayer_models.dart`
- [X] T006 [P] [US1] Add strings `prayerJumuah` ("Jumu'ah" / "الجمعة") to `lib/app/l10n/app_en.arb` and `app_ar.arb`, regenerate localizations
- [X] T007 [US1] Add a `friday` flag to `prayerName` in `lib/features/prayer_times/prayer_copy.dart` returning `prayerJumuah` for `dhuhr` when true
- [X] T008 [US1] In `buildAlerts` (`lib/features/prayer_times/prayer_alerts.dart`), use `prayerName(l10n, e.kind, friday: schedule.isFriday)` for the alert title; id, body and sound unchanged
- [X] T009 [US1] Label the Dhuhr row and the next-prayer header "Jumu'ah" on Fridays in `lib/features/prayer_times/prayer_times_screen.dart`
- [X] T010 [US1] Tests in `test/features/prayer_times/prayer_alerts_test.dart`: Friday Dhuhr title names Jumu'ah, Thursday names Dhuhr, id unchanged

## Phase 4: User Story 2 - Jumu'ah reminder (P1)

**Goal**: A reminder 20 minutes before Friday Dhuhr, following the Dhuhr alert until changed.

**Independent Test**: quickstart Manual 2.

- [X] T011 [US2] Add `final bool? jumuah` (default `null`, "never changed: follows the Dhuhr alert") and `bool get jumuahOn => jumuah ?? prayers.contains(PrayerKind.dhuhr)` to `AlertSettings`; include it in `any`, `copyWith` (allow setting a non-null value), `toJson` (write only when not null) and `fromJson` (`j['jumuah'] as bool?`) in `lib/features/prayer_times/prayer_models.dart`
- [X] T012 [P] [US2] Add strings `prayerJumuahReminder` ("Jumu'ah reminder"), `prayerJumuahReminderTitle` ("Jumu'ah prayer in {minutes} minutes" / "صلاة الجمعة بعد {minutes} دقيقة"), `prayerJumuahReminderBody` ("Hasten to the remembrance of Allah." / "فاسعوا إلى ذكر الله"), `prayerJumuahReminderExplanation` ("20 minutes before Jumu'ah, on Fridays.") and `prayerJumuahReminderUpcoming` ("Next: {time}") to both ARB files
- [X] T013 [US2] In `buildAlerts`, when `settings.jumuahOn` and `schedule.isFriday` and Dhuhr is available, add a `PrayerKind.jumuah` alert at Dhuhr − 20 min (skipped if not after `now`), `toneSound`, title with localized 20, in `lib/features/prayer_times/prayer_alerts.dart`
- [X] T014 [US2] Priority cut (research R10) in `nearestAlerts`, called by `buildAlerts`: after taking `max`, reminders (`qiyam`, `jumuah`, `duha`) in the last day of the window give way to cut prayer alerts of that day; nearer alerts are never dropped
- [X] T015 [US2] Add `setJumuah(bool)` and `nextJumuah` (next Friday reminder time for the current place) to `lib/features/prayer_times/prayer_controller.dart`, following `setQiyam`/`nextQiyam` (permission request when turning on)
- [X] T016 [US2] Add the Jumu'ah reminder row after Qiyam in `lib/features/prayer_times/reminder_settings.dart` (key `alert-jumuah`, value `alerts.jumuahOn`)
- [X] T017 [US2] Tests in `test/features/prayer_times/prayer_alerts_test.dart` and `prayer_state_test.dart`: reminder at Dhuhr − 20 (with a +5 adjustment), none on other days, `null` follows Dhuhr, explicit false stays off when Dhuhr toggles, old JSON reads `null`, priority cut keeps prayers

## Phase 5: User Story 3 - Duha reminder (P2)

**Goal**: An optional daily reminder halfway between Sunrise and Dhuhr.

**Independent Test**: quickstart Manual 3.

- [X] T018 [US3] Add `DateTime? duhaUtc` to `DaySchedule` (`lib/features/prayer_times/prayer_models.dart`) and compute it in `prayer_calculator.dart` as "Midpoint of the adjusted Sunrise and Dhuhr, rounded to the minute; null if either is null"
- [X] T019 [US3] Add `final bool duha` (default `false`) to `AlertSettings` with `any`, `copyWith`, `toJson`, `fromJson` (`j['duha'] as bool? ?? false`)
- [X] T020 [P] [US3] Add strings `prayerDuha` ("Duha" / "الضحى"), `prayerDuhaTitle` ("Duha prayer" / "صلاة الضحى"), `prayerDuhaBody` ("The prayer of those who turn to Allah." / "صلاة الأوابين"), `prayerDuhaExplanation` ("Halfway between sunrise and Dhuhr, the best time for Duha."), `prayerDuhaUpcoming` ("Next: {time}"), `prayerDuhaUnavailable` to both ARB files
- [X] T021 [US3] In `buildAlerts`, add a `PrayerKind.duha` alert at `schedule.duhaUtc` when `settings.duha` and it is after `now`, `toneSound`
- [X] T022 [US3] Add `setDuha(bool)` and `nextDuha` to `prayer_controller.dart`, and the Duha row after the Jumu'ah row in `reminder_settings.dart` (key `alert-duha`)
- [X] T023 [US3] Tests in `test/features/prayer_times/prayer_calculator_test.dart` and `prayer_alerts_test.dart`: midpoint and rounding, null when Sunrise unavailable, alert only when on

## Phase 6: User Story 4 - Announcements (P2)

**Goal**: Messages sent from the Firebase console to topics reach readers who have the switch on.

**Independent Test**: quickstart Manual 4.

- [X] T024 [P] [US4] Add `announcements` (default `true`) to `ReaderPreferences` in `lib/data/models.dart` (field, constructor, `copyWith`, JSON with missing key → true) and a setter on the reader state in `lib/shared/reader_state.dart`
- [X] T025 [P] [US4] Create `lib/platform/announcements.dart` (conditional export), `announcements_io.dart` (FCM: initialise with `DefaultFirebaseOptions`, auto-init on/off, topic subscribe/unsubscribe, iOS foreground options banner+list no sound, Android foreground message shown via `flutter_local_notifications` on channel `announcements_v1`, `getInitialMessage` + `onMessageOpenedApp` → `data.link`) and `announcements_web.dart` (no-op), per `contracts/announcements.md`
- [X] T026 [P] [US4] Create `lib/firebase_options.dart` placeholder whose `DefaultFirebaseOptions.currentPlatform` throws `UnsupportedError` (as the generated file does for an unconfigured platform) until `flutterfire configure` replaces it; `start()` returns false then
- [X] T027 [US4] Create `lib/features/announcements/announcements.dart`: controller that, after the first frame, starts the platform when the preference is on, subscribes `all` + `lang_<language>`, re-subscribes on language change, unsubscribes all three when off, and forwards links that are `https` on `mthani.app`, `www.mthani.app` or `get.mthani.app`
- [X] T028 [US4] Merge announcement links into the link source used by `GroupLinkHost` (`lib/platform/app_links_io.dart` or a merged `LinkSource` in `lib/main.dart`), and start the controller after the first frame in `lib/main.dart`
- [X] T029 [US4] Add the "Announcements from Mathani" switch with its hint to `lib/features/settings/settings_screen.dart` (hidden on web), asking notification permission when switched on, plus strings `settingsAnnouncements`, `settingsAnnouncementsHint`, `announcementsChannel` in both ARB files
- [X] T030 [P] [US4] Android: manifest meta-data `firebase_messaging_auto_init_enabled=false`, `com.google.firebase.messaging.default_notification_channel_id=announcements_v1`, default notification icon; create channel `announcements_v1` (default importance) in `PrayerNotificationsPlugin.kt` channel setup or from Dart, in `android/app/src/main/`
- [X] T031 [P] [US4] iOS: `aps-environment` in `ios/Runner/Runner.entitlements` (added with 1.9.0+34, after the App ID got Push Notifications and the profile was regenerated), `FirebaseMessagingAutoInitEnabled=false` in `ios/Runner/Info.plist`
- [X] T032 [US4] Tests in `test/features/announcements/announcements_test.dart` with a fake platform: topics on start, language change, off unsubscribes, link host check, not started when preference off or platform unavailable

## Phase 7: Polish & Cross-Cutting

- [X] T033 [P] Update `docs/store/privacy.md` with the push service section and store answers (research R11)
- [X] T034 [P] Mark FR status and the 009 out-of-scope note in `specs/009-prayer-times/spec.md` (Jumu'ah reminder now covered by 015)
- [X] T035 Run `flutter analyze` and `flutter test`; fix failures

## Dependencies & Execution Order

- Setup (T001) → only US4 needs it.
- Foundational (T002–T004) → blocks US2 and US3 (new kinds); US1 needs only T002's compile fixes.
- US1 → US2 (US2 reuses `isFriday`). US3 is independent of US1/US2 after Phase 2. US4 is
  independent of US1–US3.
- Polish after the stories.

## Parallel Examples

- Phase 2: T003 (Kotlin) alongside T002/T004 (Dart).
- US1: T005 and T006 together, then T007–T010.
- US4: T024, T025, T026, T030, T031 together, then T027–T029, then T032.

## Implementation Strategy

1. MVP: Phase 2 + US1 (Friday label), shippable alone.
2. Add US2, then US3 (each a release-sized increment, all on the phone).
3. US4 ships once the owner has configured Firebase (research R11); until then the code is
   present and inactive.
