# Implementation Plan: Prayer Times and Athan

**Branch**: `009-prayer-times` (feature ID; the work so far is committed on `008-web-app`) |
**Date**: 2026-11-02 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/009-prayer-times/spec.md`, rewritten 2026-11-02. This
plan replaces the plan for the first draft, which is in git history.

## Summary

Prayer Times, reached from Settings, shows the reader's schedule calculated on the phone. It
supports "My location" (approximate, refreshed when the app opens), city search with an
internet-based suggestion, saved places, 11 methods, the Asr setting, high-latitude rules and
per-prayer offsets. Alerts play a bundled opening-takbirat clip, a tone, or nothing. Full athan
plays from a small native Android service, or in the app on iPhone and web. Qiyam is an optional
tone at the start of the last third of the night.

Much of this already exists on `008-web-app`: calculation, location endpoints (live), native short
alerts and Qiyam. The plan **reshapes that code** to the new spec. It adds the new features, swaps
secure storage for `user.db`, and replaces the unproven audio_service bridge with a native
playback service. Details: [research R1](./research.md#r1-build-on-the-existing-code-reshape-it-to-the-new-spec).

## Technical Context

**Language/Version**: Dart 3.13.5 / Flutter 3.47.7 (pinned). Kotlin (Java 17) and Swift host
code. JavaScript Pages Functions (unchanged).

**Primary Dependencies**:
- **Kept**: `adhan_dart 2.0.1`, `timezone 0.11.2`, `geolocator 14.0.1`,
  `flutter_local_notifications 22.3.3`.
- **Removed**: `flutter_secure_storage`.
- **Reused**: `just_audio`, `audio_session`, `http`, `crypto`, `sqflite`.
- No new packages.

**Storage**: JSON under key `prayer.state` in the existing `user.db` `preferences` table. Android
keeps a derived alert list in `SharedPreferences` for reboot restore. Full recordings live in
the existing FileStore. See [data-model.md](./data-model.md).

**Testing**:
- `flutter_test`: calculator fixtures, controller, alert-list building, widgets.
- Android JVM tests: alarm store and receiver decisions.
- `node --test`: endpoints (unchanged).
- `integration_test` on devices, plus manual device trials from [quickstart.md](./quickstart.md).

**Target Platform**: iOS 15.0+, Android 7.0 (API 24)+ (target SDK 36), and the supported browsers
of feature 008. Phone portrait.

**Project Type**: Existing Flutter mobile app with web build, plus the existing Cloudflare Pages
Functions.

**Performance Goals**: Cold start ≤ 2 s on Galaxy A15 and iPhone SE (2nd gen). 60 fps. Tap
feedback ≤ 100 ms. No prayer work before the first reader frame (R11).

**Constraints**:
- Offline schedules.
- Approximate location only; no background location.
- At most 60 pending alerts (iOS limit 64).
- Android channel sounds fixed per channel.
- iOS alert sounds ≤ 30 s.
- Athan recordings need redistribution rights (R10).

**Scale/Scope**: 6 screens and sheets, 11 methods, any number of saved places (list virtualized),
60 pending alerts. GeoNames free quota of 10,000 credits a day (R5).

## Constitution Check

Constitution 2.0.0. Checked before research and again after design.

| Principle | Result |
| --- | --- |
| **I. Platform parity** | **Pass with one documented gap.** Every story works on iOS and Android. iPhone cannot play a full athan from a locked phone without the alert being tapped (30 s sound limit). This is recorded in the spec's Assumptions as the accepted gap, and FR-024 tells the reader. Web alerts only while the page is open (FR-028). iOS 15.0 and Android API 24 are stated. Permissions follow each platform: approximate location, Android exact-alarm access, iOS notification authorization. |
| **II. Mobile-first** | **Pass.** Portrait sheets, safe areas, 44 pt / 48 dp targets, RTL, dark mode, text scaling and screen readers are required in the UI contract and checked in quickstart Q2. |
| **III. Performance** | **Pass by design, measured before merge.** Nothing before the first frame. The refill runs once after the first frame. Quickstart Q1 checks cold start and paging fps. |
| **IV. Lean** | **Pass.** No new packages and one removed (`flutter_secure_storage`). Code removed: the audio_service bridge, the spike, the encrypted queue and acknowledgements. Assets: bundled opening clips (~150–250 KB each, one format per platform) and the existing tone. Report size deltas and explain anything over 1 MB. Background work runs only for alarms the reader turned on. |
| **V. Simplicity** | **Pass with one justified addition** (Complexity Tracking): a native Android playback service next to the app's `just_audio` player. |
| **Platform and store** | **Pass, with one decision on record.** City-level positions are treated as not sensitive data (spec Assumptions, R6), so they live in `user.db`, not Keychain or Keystore. Permissions are asked in context only. The app works with every permission denied. App Privacy and Data safety answers must be updated (R12). |
| **Workflow** | **Pass.** specify → plan → tasks → implement. Before merge: real iPhone and Android checks (quickstart), plus the performance and size checks. |

**Gate result**: passes. No unresolved clarifications. One external dependency (recording rights,
R10) blocks only FR-019 and Story 5, not the design.

## Project Structure

### Documentation (this feature)

```text
specs/009-prayer-times/
├── spec.md              # Rewritten 2026-11-02
├── plan.md              # This file
├── research.md          # R1–R12
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── location-api.md
│   └── prayer-ui-and-reminders.md
├── checklists/requirements.md
├── validation/          # Device and test evidence (earlier runs kept as history)
└── tasks.md             # To be regenerated by /speckit-tasks (current file is for the first draft)
```

`follow-ups.md` (the first draft's P01–P07 exceptions and G01–G05 gates) is deleted. The new spec
has no exceptions list, and its open items are in this plan.

### Source Code (repository root)

```text
lib/features/prayer_times/
├── prayer_models.dart            # CHANGE: schema 2 (Place, CalculationSettings, AlertSettings, Alert); drop claim/state enums
├── prayer_calculator.dart        # CHANGE: 11 methods, re-apply method adjustments, offsets, recommended high-latitude default
├── prayer_time_zones.dart        # KEEP: latest_all (latest_10y lacks link zones, R11)
├── prayer_repository.dart        # CHANGE: user.db preferences instead of secure storage
├── prayer_controller.dart        # CHANGE: My location / current place, day navigation, offsets, sound choice; drop acknowledgements and session-only mode
├── prayer_alerts.dart            # NEW (from prayer_reminder_scheduler.dart): build 60-alert list, refill, My location refresh
├── athan_catalogue.dart          # CHANGE: read assets/prayer/athan_catalogue.json; tone/silent choices
├── athan_player.dart             # KEEP: preview / full playback / stop, pauses Quran and memorization
├── prayer_times_screen.dart      # CHANGE: day arrows, moved banner, zone note
├── locations_sheet.dart          # CHANGE: My location row, view vs Use this place
├── location_setup_sheet.dart     # CHANGE: first-time screen; search with Suggested row
├── calculation_sheet.dart        # CHANGE: 11 methods, two-choice Asr, offset steppers
├── reminder_settings.dart        # CHANGE: sound list (recitations/tone/silent), athan length, status lines
├── prayer_notification_open_host.dart  # KEEP; also plays full athan on open (iOS/web)
└── prayer_copy.dart, prayer_services.dart  # trim to remaining failure states
lib/platform/
├── prayer_location.dart          # CHANGE: low accuracy, 2-dp rounding, estimate as suggestion
├── prayer_notifications_io.dart  # CHANGE: replace(alerts, generation), status, iOS foreground full playback
├── prayer_notifications_page.dart / _web.dart  # KEEP: page timers
lib/app/app.dart, lib/main.dart   # CHANGE: post-first-frame PrayerAlerts.refill on start/resume; remove spike init
lib/features/recitation/media_handler.dart  # CHANGE: remove spike channel
lib/app/l10n/app_ar.arb, app_en.arb         # CHANGE: new and trimmed strings
assets/prayer/athan_catalogue.json          # NEW (empty until rights cleared)

android/app/src/main/kotlin/app/mathani/mathani/
├── PrayerNotificationsPlugin.kt  # CHANGE: per-sound channels, generation, inexact fallback
├── PrayerAlarmReceiver.kt        # CHANGE: 15-min lateness, start AthanPlaybackService for full
├── PrayerAlarmStore.kt           # CHANGE: plain SharedPreferences JSON (drop Keystore/claims)
├── AthanPlaybackService.kt       # NEW: mediaPlayback foreground service, MediaPlayer, Stop
├── PrayerMediaBridge.kt          # DELETE
└── MainActivity.kt               # CHANGE: remove bridge registration
android/app/src/main/AndroidManifest.xml    # CHANGE: drop FINE location, add service
android/app/src/main/res/raw/athan_<id>_opening.ogg   # NEW per cleared recording

ios/Runner/Info.plist             # CHANGE: NSLocationDefaultAccuracyReduced, usage text
ios/Runner/AppDelegate.swift      # CHECK: notification delegate registration only (full mode uses the in-app timer)
ios/Runner.xcodeproj/project.pbxproj  # CHANGE: bundle the opening .caf clips and qiyam_tone.caf as resources
ios/Runner/athan_<id>_opening.caf # NEW per cleared recording (bundle resource)

pubspec.yaml                      # CHANGE: remove flutter_secure_storage
functions/                        # NO CHANGE
tool/prayer/                      # CHANGE: fixtures for 6 added methods; catalogue build from prepare_athan.py
docs/store/privacy.md             # CHANGE: approximate location, no precise (R12)

test/features/prayer_times/       # CHANGE: adapt to schema 2; add methods/offsets/My location/alert-list tests
test/platform/                    # CHANGE: adapter tests
integration_test/prayer_times_test.dart       # CHANGE
integration_test/prayer_alarm_spike_test.dart # DELETE
android/app/src/test/.../PrayerAlarmStoreTest.kt  # CHANGE; add receiver decision tests
```

**Structure Decision**: Keep the existing feature folder, the platform facades and the
`ChangeNotifier` pattern. One new Dart file (`prayer_alerts.dart`, mostly moved from the
scheduler) and one new Kotlin file (`AthanPlaybackService.kt`). Everything else is a change or a
deletion.

## Delivery order

Each step leaves the app releasable and maps to spec priorities.

1. **Foundation**:
   - Schema 2, `user.db` storage, remove `flutter_secure_storage` and the spike/bridge.
   - Adapt the existing tests.
2. **Story 1 + Story 2 (P1)**:
   - First-time screen, approximate location with rounding, search with Suggested row, day
     navigation.
   - 11 methods with fixtures, Asr two-choice, high-latitude default, offsets.
3. **Story 3 (P2)**: My location mode and refresh on resume, saved places view vs Use this place,
   delete flows.
4. **Story 4 (P2)**:
   - `PrayerAlerts` refill after the first frame; per-sound Android channels; generation and
     15-minute rules.
   - Tone and silent; status lines.
   - Ships with the tone if no recording is cleared yet.
5. **Story 6 (P3)**: Qiyam on the new alert list. It mostly exists; adapt it.
6. **Story 5 (P3)**:
   - `AthanPlaybackService`, iOS foreground and tap-to-play, full download row.
   - Recordings are added as their rights clear (R10).
7. **Release checks**: the quickstart device scenarios, size and performance, privacy answers
   (R12).

## Open items (not blockers for the design)

| Item | Owner | Blocks |
| --- | --- | --- |
| Rights for two athan recordings (R10) | Product (Hamza) | FR-019 (two recitations), Story 5 with real audio |
| Official timetable samples for Dubai, Kuwait, Qatar, Singapore, Turkey, Moonsighting (R3) | Implementation | SC-002 for those methods |
| App Privacy / Data safety answers and privacy policy (R12) | Product | Store submission |
| Branch: move prayer work off `008-web-app` onto `009-prayer-times` | Product | Clean review and merge |

## Complexity Tracking

| Addition | Why needed | Simpler alternative rejected because |
| --- | --- | --- |
| Native `AthanPlaybackService` on Android, alongside `just_audio` | Full athan must play from a locked phone with the app not running (FR-024). An exact alarm can start a native foreground service without a Flutter engine. | Routing through the existing `audio_service` handler needs a cold Flutter engine at alarm time. It was the first draft's riskiest gate (G01) and was never proven on a device. Notification sounds alone cannot play a multi-minute athan reliably or offer Stop. |
| Android derived alert list in `SharedPreferences` | Alarms must be restored after reboot without starting Flutter | Recomputing in Kotlin would duplicate the calculator. |
