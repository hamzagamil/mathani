# Tasks: Usage Analytics

**Input**: Design documents from `specs/016-usage-analytics/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included (quickstart names unit and privacy tests).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1 active users, US2 screens and actions, US3 disclosure, US4 web

## Phase 1: Setup

- [X] T001 Add `firebase_analytics: 13.1.0` (pinned, next to the other Firebase packages, with a comment) to `pubspec.yaml` and run `flutter pub get`
- [X] T002 Run `flutterfire configure --project=mthani --platforms=android,ios,web` to add the web app and its options to `lib/firebase_options.dart`

## Phase 2: Foundational (blocks all stories)

- [X] T003 Create `lib/platform/firebase_app.dart` with `firebaseReady()`: one shared `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` future, false on `UnsupportedError` or failure; use it in `lib/platform/announcements_io.dart` instead of its own `initializeApp`
- [X] T004 Create `lib/features/analytics/usage.dart`: `UsageSink` interface, `NoUsage`, `UsageScreen` and `UsageSetting` enums with snake_case `wire` names, and the `Usage` facade with one typed method per contract event (contracts/usage-events.md), plus `TrackedScreen` for stateless screens; no method takes free text, a page, an ayah or a place
- [X] T005 Create `lib/platform/usage_firebase.dart`: `FirebaseUsage` sink with states waiting/on/off (data-model.md), queue of at most 50 events before start, `start()` after the first frame enabling collection only when `kReleaseMode || USAGE_DEBUG` and, on the web, only on `get.mthani.app`; otherwise `setAnalyticsCollectionEnabled(false)`
- [X] T006 Install the sink in `lib/main.dart` (`Usage.sink = FirebaseUsage()`), start it in the existing post-frame callback
- [X] T007 [P] Android `android/app/src/main/AndroidManifest.xml`: replace `firebase_analytics_collection_deactivated` with `firebase_analytics_collection_enabled=false`; add `google_analytics_adid_collection_enabled=false`, `google_analytics_default_allow_ad_personalization_signals=false`, `google_analytics_automatic_screen_reporting_enabled=false`; remove the merged `com.google.android.gms.permission.AD_ID` permission with `tools:node="remove"`
- [X] T008 [P] iOS `ios/Runner/Info.plist`: `FIREBASE_ANALYTICS_COLLECTION_ENABLED=false`, `FirebaseAutomaticScreenReportingEnabled=false`, `GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS=false`, `GOOGLE_ANALYTICS_REGISTRATION_WITH_AD_NETWORK_ENABLED=false`, `GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED=false`

## Phase 3: User Story 1 - Active users (P1) 🎯 MVP

**Goal**: Each release build counts as an active user per platform.

**Independent Test**: quickstart Manual 1.

- [X] T009 [US1] Tests in `test/features/analytics/usage_test.dart`: the facade sends through the installed sink, and screen views report on push and page pop but not sheet pop (the Firebase sink's queue needs Firebase and is checked on device, quickstart Manual 1)

## Phase 4: User Story 2 - Screens and actions (P1)

**Goal**: The contract's screens and actions reach the property.

**Independent Test**: quickstart Manual 2.

- [X] T010 [US2] Add `ScreenTracking` mixin (RouteAware: log on push and on pop-next) and a shared `usageRouteObserver` to `lib/features/analytics/usage.dart`; register it in `MaterialApp.navigatorObservers` in `lib/app/app.dart`
- [X] T011 [US2] Apply `ScreenTracking` to the reader, index, search, settings, prayer times, khatma, wird list, khatma complete, group khatma, downloads, memorization result, onboarding, similar-wording sheet and reciter sheet screens (`lib/features/**`), converting a screen to stateful only where needed
- [X] T012 [US2] Log `setting_changed` from `ReaderController.updatePreferences` (`lib/shared/reader_state.dart`) for each changed field in the contract, and from `PrayerController.updateCalculation`, `setSound`, `setAthanLength` (`lib/features/prayer_times/prayer_controller.dart`)
- [X] T013 [US2] Log actions: `recitation_started` (`recitation_controller.dart` `playFrom`/`playFromPage`), `surah_download_started` (`download_queue.dart` `enqueue`), `memorization_started` (`memorization_controller.dart` `start`, with the outcome), `search` (`search_screen.dart`, once per visit), `bookmark_added` (`ayah_actions.dart`, `reader_screen.dart`), `khatma_started` and `wird_completed` (`khatma_controller.dart`), `group_khatma_started` and `group_khatma_joined` (`group_controller.dart`), `prayer_alert_changed` (`prayer_controller.dart` setters), `announcement_opened` (`announcements_io.dart`), `onboarding_completed` (`onboarding_controller.dart`)
- [X] T014 [US2] Tests in `test/features/analytics/usage_test.dart`: every name snake_case ≤ 40 characters, unique; a settings diff logs exactly the changed fields with contract values
- [X] T015 [US2] Privacy test `test/features/analytics/usage_privacy_test.dart`: only `lib/platform/usage_firebase.dart` imports `firebase_analytics`; only `lib/features/analytics/usage.dart` calls `UsageSink`

## Phase 5: User Story 3 - Disclosure (P1)

**Goal**: Every text tells readers the same thing.

**Independent Test**: quickstart Manual 3.

- [X] T016 [P] [US3] Add the About sentence and a policy link (`aboutUsageStatistics`, `aboutPrivacyPolicy` in both ARB files, regenerate) to `lib/features/settings/about_section.dart`
- [X] T017 [P] [US3] Declare `NSPrivacyCollectedDataTypes` (`DeviceID`, `ProductInteraction`; purpose Analytics; not linked; not tracking) in `ios/Runner/PrivacyInfo.xcprivacy`
- [X] T018 [P] [US3] Update `docs/store/privacy.md` (new "Usage statistics (specs/016)" section with store answers, research R10) and the listings `docs/store/listing_en.md`, `listing_ar.md`
- [X] T019 [US3] Add a "Usage statistics" section to the published policy (`Mathani-landing/privacypolicy.html`) and deploy the landing site
- [X] T020 [P] [US3] Note in `specs/008-web-app/spec.md` FR-027 and `specs/015-jumuah-duha-announcements/plan.md` that specs/016 supersedes "no analytics"

## Phase 6: User Story 4 - Web (P2)

**Goal**: get.mthani.app reports the same events.

**Independent Test**: quickstart Manual 4.

- [X] T021 [US4] Widen the CSP in `web/_headers` for gstatic, googletagmanager, google-analytics, installations and config hosts (research R8)
- [X] T022 [US4] Build the web app (`flutter build web --wasm --release --no-web-resources-cdn`) and check it initialises Firebase on the web

## Phase 7: Polish

- [X] T023 Run `flutter analyze` and `flutter test --exclude-tags web,golden`; fix failures
- [X] T024 Measure size (research R9) and record it in the plan (Android +3.00 MB since the 1.4.0 baseline; see plan › Size)

## Dependencies & Execution Order

- T001–T002 → T003–T008 → stories. US2 needs T010 before T011. US3 and US4 are independent of US2.
- T019 is an outward action (published policy), done together with the web deploy.

## Implementation Strategy

1. MVP: Phases 1–3 (active users).
2. US2 screens and actions; US3 texts; US4 web.
3. Ship the policy, the web deploy and the store builds together.
