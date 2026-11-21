# Research: Usage Analytics

## R1. Library on the phones and the web

- **Decision**: `firebase_analytics` 13.1.0 (with `firebase_analytics_web` 0.6.4+16), pinned like the
  other Firebase packages. It resolves against the existing `firebase_core` 5.2.0 with no other
  change.
- **Rationale**: The owner's property (539746070) is the one linked to Firebase project `mthani`;
  Firebase Analytics feeds it directly on Android, iOS and the web, with one Dart API. The custom
  dashboard reads that property.
- **Alternatives**: GA4 Measurement Protocol through a Cloudflare function for the web (no
  third-party script, same-origin), rejected for now: it needs an API secret created by the owner,
  its own session and engagement handling, and a second code path. Plausible or similar
  privacy-first tools, rejected: they do not feed the owner's GA4 property or dashboard.

## R2. Debug builds and previews stay out (FR-013)

- **Decision**: Collection is off by default in the native configuration
  (`firebase_analytics_collection_enabled=false` in the Android manifest,
  `FIREBASE_ANALYTICS_COLLECTION_ENABLED=false` in Info.plist), and the app turns it on with
  `setAnalyticsCollectionEnabled(true)` only in release builds, and on the web only on
  `get.mthani.app`. Other builds call it with `false`, which the SDK remembers.
- **Rationale**: Firebase is already initialised by announcements (specs/015) on phones, and the
  native SDK would otherwise log `first_open` and `session_start` from any build as soon as it
  starts. The existing `firebase_analytics_collection_deactivated=true` must go, because
  "deactivated" cannot be undone at runtime.
- **Alternatives**: A separate debug property, rejected (more setup for little gain).

## R3. No advertising identifier and no tracking (FR-005)

- **Decision**:
  - Android: remove the `com.google.android.gms.permission.AD_ID` permission the library merges
    (`tools:node="remove"`), and set `google_analytics_adid_collection_enabled=false` and
    `google_analytics_default_allow_ad_personalization_signals=false`.
  - iOS: `GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS=false`,
    `GOOGLE_ANALYTICS_REGISTRATION_WITH_AD_NETWORK_ENABLED=false`,
    `GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED=false`. The app never shows Apple's tracking prompt,
    so the advertising identifier stays zeros; `NSPrivacyTracking` stays false.
  - Property (owner, in GA admin): Google signals off, ads personalisation off, data retention
    2 months (FR-014).
- **Rationale**: Only the random app-instance id is needed to count a reader once a day (FR-008).

## R4. Screens (FR-002)

- **Decision**: Automatic screen reporting is off (`google_analytics_automatic_screen_reporting_enabled=false`
  on Android, `FirebaseAutomaticScreenReportingEnabled=false` on iOS); a Flutter app is one
  activity or view controller, so automatic names would all be the same. Each tracked screen mixes
  in `ScreenTracking` on its `State`, which logs `screen_view` with a name from `UsageScreen` when
  the route is pushed and again when it becomes visible after the route above it is popped
  (`RouteAware`, one `RouteObserver` in `MaterialApp`).
- **Rationale**: Routes are unnamed `MaterialPageRoute`s; a mixin keeps the name next to the
  screen and covers returning to the reader, which is most of the use.

## R5. The allowed-events list (FR-003, FR-004, FR-009)

- **Decision**: One file, `lib/features/analytics/usage.dart`, defines every screen name, action
  name and parameter, with typed methods (`Usage.recitationStarted(reciter: …)`,
  `Usage.settingChanged(UsageSetting.theme, ThemePref.night)`). Values come only from enums or from
  the app's own catalogues (reciter ids, athan sound ids). No method takes free text, a page, an
  ayah or a place. A test fails if any other file imports the analytics library.
- **Rationale**: The spec's privacy promise depends on a single list a reviewer can read.

## R6. Settings changes

- **Decision**: `ReaderController.updatePreferences` compares the old and new preferences and logs
  one `setting_changed` per changed field (layout, theme, flowing font size, keep screen on,
  language, lettering, reciter, mistake signal, two pages, announcements). The prayer controller
  logs calculation method, Asr rule, high-latitude rule, athan sound and athan length when they
  change. Internal flags (onboarding done, similar intro seen) are not settings.

## R7. Starting after the first frame (FR-019) and the shared Firebase start

- **Decision**: A shared `firebaseReady()` in `lib/platform/firebase_app.dart` initialises Firebase
  once for announcements and analytics (two concurrent `initializeApp` calls would fail). The
  analytics sink starts after the first frame and queues up to 50 events logged before it is
  ready (the first screen), then flushes them. If Firebase fails (offline web, no script), the
  queue is dropped and the app is unaffected.

## R8. The web (FR-011, FR-012)

- **Decision**: `flutterfire configure` adds a web app to project `mthani` (a web data stream in
  the property) and its options to `lib/firebase_options.dart`. The Firebase JS SDK and gtag are
  loaded by the plugin after the first frame, so `web/_headers` CSP adds
  `https://www.gstatic.com` and `https://www.googletagmanager.com` to `script-src`, and the
  analytics, installations and config hosts to `connect-src`
  (`https://*.google-analytics.com https://*.analytics.google.com https://*.googletagmanager.com
  https://firebaseinstallations.googleapis.com https://firebase.googleapis.com`). The web stores
  its client id in a first-party cookie, as agreed (no banner).
- **Rationale**: Same Dart API and event list as the phones.
- **Risk**: content blockers stop it; the app works and the visit is not counted.

## R9. Size (constitution IV)

- **Decision**: Measure with `tool/size_check.dart` after building. Expected roughly +0.5 to 1 MB on
  Android and +1 to 2 MB on iOS (Google App Measurement); the web adds no bundle weight (scripts
  loaded at runtime, about 150 KB). Called out in review if over 1 MB.

## R10. Store answers and texts (FR-016 to FR-018)

- **Apple App Privacy**: Identifiers › Device ID; Usage Data › Product Interaction. Purpose
  Analytics; not linked to the user; not used for tracking. Combined with announcements (Device ID,
  App Functionality).
- **iOS privacy manifest**: `NSPrivacyCollectedDataTypes` with `DeviceID` and
  `ProductInteraction`, purpose `Analytics`, not linked, not tracking.
- **Google Play Data safety**: App activity › App interactions; Device or other IDs. Collected,
  not shared (Google is a service provider), **required** (no switch), for Analytics, encrypted in
  transit.
- **Listings**: the "Nothing leaves your device…" sentence is replaced; About gets one sentence
  with a link to the policy.
- **Policy** (mthani.app/privacypolicy, landing site): a new "Usage statistics" section.

## R11. Owner actions

- In GA admin: data retention 2 months, Google signals off, ads personalisation off (FR-014).
- Optionally register custom dimensions `setting`, `value`, `reciter`, `prayer`, `outcome` so the
  dashboard can break events down by them (event counts work without).
- Confirm the store answers in both consoles before the public release.
