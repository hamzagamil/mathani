# Quickstart Validation: Prayer Times

**Feature**: [spec.md](./spec.md) | **Design**: [plan.md](./plan.md) | **Model**: [data-model.md](./data-model.md)

This is the implementation validation guide. Planned test paths and feature screens below are to be created by the subsequent tasks/implementation phases; they are not already runnable feature tests. Planning did not run notification/device trials.

## Prerequisites

- Repository-pinned Flutter 3.47.7 / Dart 3.13.5, Android Java 17 toolchain, Chrome and Node with built-in test runner; use the existing Wrangler major 4 deployment tooling.
- macOS/Xcode and a physical iPhone for iOS builds and notification tests. The Windows planning workstation cannot establish iOS playback results.
- Galaxy A15 and iPhone SE (2nd gen) performance reference phones. Include Android API24, API31+, API33+ and API36 for notification/capability coverage and supported iOS15+. Use physical locked/Doze trials, not only emulators.
- Current/previous supported Chrome, Edge, Firefox and Safari major versions per feature 008, including mobile Safari/Chrome. Use secure HTTPS preview for actual geolocation and notification capability.
- Configured enabled GeoNames username in local uncommitted bindings and Pages preview/production bindings. Do not use demo, commit credentials or print existing auth stores. No paid subscription is required merely to begin implementation validation.
- Two prepared/licensed recordings and authentic complete opening clips, source/hash/license manifest, generated Ramadan interval table and independent calculation fixtures. See research R3/R7 and follow-ups G02/G04.

## Build and focused checks after implementation

Run from repository root. Use a selected flutter device ID in place of MATHANI_DEVICE_ID. The commands describe planned checks, not test results from planning.

```powershell
flutter pub get
flutter analyze
flutter test test/features/prayer_times
flutter test --platform chrome test/platform/prayer_notifications_web_test.dart
node --test tool/prayer/location_api_test.mjs
flutter devices
flutter run -d $env:MATHANI_DEVICE_ID
flutter test integration_test/prayer_times_test.dart -d $env:MATHANI_DEVICE_ID
flutter build web --wasm --release --no-web-resources-cdn
node tool/web_deploy.mjs --prepare-only
npx wrangler@4 pages dev build/web
```

Configure the local API base URL for development; browser builds use same-origin endpoints. Device localhost is not the workstation; use an explicit reachable development URL. Native calls must succeed without a browser Origin header. Pages functions and _routes.json must be included by build/deploy preparation. Local IP approximation uses fixtures because request.cf may be absent. Do not use a local success fixture as evidence of production IP accuracy.

If an authorized preview deployment is needed during implementation, `node tool/web_deploy.mjs --dry-run` creates a Pages preview. Test the actual preview API responses, headers, GeoNames bindings, routing and browser permissions there. This planning command does not deploy anything.

## G01: Full Android playback feasibility, before dependent UI work

1. Build the smallest exact-alarm -> native receiver -> existing single audio handler route. Run with the app active, backgrounded, locked, process absent and in Doze. Do not equate swipe dismissal with Android Settings force-stop; force-stop is a separately disclosed unsupported state.
2. Schedule a near-future test event. Confirm timely foreground promotion, one acknowledged event token, selected full/opening audio, one media notification, working Stop, no duplicate preview/Quran playback and no automatic Quran resume.
3. Kill during command queuing and race startup/fallback. A late handler must not play after a fallback or Stop won the token. Update/delete location while an event is pending; obsolete generation must not play.
4. Revoke exact-alarm access and POST_NOTIFICATIONS. Check blocked/approximate effective state, preserved preferences and recovery action. Test reboot restores future alarms and does not immediately start a media service or replay missed prayers.
5. Preserve logs with event tokens/times only, no location data. Record API/device, app lifecycle, system grants, due/start instants and outcome. Failure keeps full mode disabled and requires plan/spec revision before release; do not substitute a successful foreground demo.

## G02: Recording and iOS sound acceptance

1. Review both full recordings by listening. Confirm complete recitation and correct four-opening-takbir boundaries; preserve the file revision, license, author/recorder credit, transformation commands and SHA-256.
2. Inspect duration/format using ffprobe or an equivalent media inspector. Both iOS clips must contain the four complete takbirs and be <30 seconds; copies in Library/Sounds must play as CAF notifications. Never speed up/truncate words merely to pass.
3. On a physical iPhone, exercise foreground full/opening playback and background/locked/terminated opening notifications. Verify no unsupported background full setting appears active. Open the notification and explicitly start full playback.
4. While Quran recitation is playing, trigger app-controlled and system-owned alerts. App-controlled playback must pause Quran. Record actual system interruption/ducking and Stop limitations under P02; settings must disclose them before activation.
5. Download a full recording, go offline, verify playback. Corrupt/delete the file or interrupt a download; readiness must be false until checksum validation succeeds, with an acknowledged available notification fallback.

## End-to-end acceptance scenarios

| Scenario | Procedure | Expected result |
| --- | --- | --- |
| Automatic setup | Fresh prayer state, open Prayer Times, choose detection, grant foreground permission | No startup prompt; confirmed location/zone, six-event schedule and next prayer. |
| Denial and manual selection | Deny location; search similarly named cities and select one | No repeated prompt; region/country disambiguation; valid selected place without GPS. |
| IP fallback | Choose approximate action online; also test VPN and absent metadata | Explicit disclosure/approximate label/confirmation; no silent activation; failure offers manual selection. |
| Multiple places | Save Cairo, New York and Sydney; inspect, activate, rename, delete, restart | Per-place preferences persist; viewing differs from activating; removing active place requires replacement or disables reminders. |
| Methods and madhahib | Exercise all five methods and four labels against fixtures | Correct named convention, two Asr factors, preserved labels, recalculated future alerts. |
| Time/date boundaries | DST spring/fall, device zone changes, after Isha, Ramadan first/last evening | Location-zone date, next Fajr, correct interval convention, no duplicate/missed logical event. |
| Polar/high latitude | Explicit middle/seventh rule and unresolvable polar date | Adjustment identified; unavailable events never appear as 00:00 or generate invented Qiyam. |
| Qiyam | Enable independently for known Maghrib/next-Fajr interval, then disable | Last-third start computed by elapsed duration, labelled short reminder, daily switches unchanged. |
| Offline | Save places/prepare audio, disconnect, restart and inspect/schedule | Valid local calculation; no fresh detection or network needed for saved places; unavailable resources accurately shown. |
| Permission/capability changes | Deny/revoke grants, edit channel settings, silence device | Effective blocked/limited status, preserved intent; no bypass or false guarantee. |
| Horizon | Inspect pending queue, advance past horizon, reopen | iOS <=60 total, Android <=30 days, visible scheduled-through, refill only future events, no backlog. |
| Delete/privacy | Remove locations/clear prayer state; inspect storage and sanitized diagnostics | Reminders cancelled, location data deleted, no plaintext coordinates in user.db/payloads/logs; reader bookmarks unchanged. |
| Web | Chrome/Firefox/Edge/Safari, reject autoplay, suspend/close/reopen | Schedule/settings persist when storage allows; Play action on rejection; no closed-page automatic athan claim. |
| Accessibility | Arabic/English, RTL, dark mode, large fonts and screen readers | All actions/state/time labels usable, safe areas intact, minimum touch targets met. |

## Endpoint tests

Implement Node tests using injected GeoNames/Cloudflare responses, not live service dependence. Verify method/body/query validation, allowed origins and native no-Origin requests, bounded upstream host/call count/timeouts, empty results, missing timezone, provider quota/status errors, no raw upstream echo, no-store and no sensitive logs. Search results without timezone must be explicitly unresolved and resolve before confirmation. Verify build output routes /api/prayer-* to Functions and static assets bypass them.

On HTTPS preview, confirm `Permissions-Policy` allows self geolocation, CSP permits only the intended API/audio host, /api replies are JSON rather than SPA HTML, service worker/CDN do not cache them, and application logs omit personal values. Confirm configured GeoNames account/attribution and the ten reference cities. Do not call an external provider with real precise GPS data without the feature's explicit disclosure/action.

## Calculation, timing and usability evidence

- SC-002: freeze expected results from the independent reference implementation with exact angles, offsets, rounding, zone, Asr factor, high-latitude rule and Ramadan table version. Test all five methods across the ten research cities, plus DST/Ramadan/polar cases. <=1 minute discrepancy for every available result; investigate mismatches rather than changing fixtures to match production.
- SC-004: at least 30 timed trials per supported mobile playback mode, per platform, under documented granting/system conditions. >=95% begin within 60 seconds, all correct recitation/duration, zero stale/duplicate alerts. Unsupported iOS/web full-background paths are disclosed exceptions, not omitted failing trials represented as passes.
- SC-001/007: representative Arabic/English users including screen-reader tasks; >=90% first schedule within two minutes and >=90% unassisted recitation/mode/Qiyam tasks. Report participant count, actual successes and permission-route coverage rather than asserting percentages without a study.
- SC-003/005/006: exhaustive state, Qiyam and recoverable-failure scenarios in focused tests and the matrix above; keep trial evidence with implementation review.

## Performance, release size and regression

```powershell
flutter test
flutter drive --profile -d $env:MATHANI_DEVICE_ID --driver test_driver/perf_driver.dart --target integration_test/paging_perf_test.dart
flutter build appbundle --release --analyze-size --target-platform android-arm64
flutter build ios --release --analyze-size --target-platform ios-arm64
```

The iOS command runs on macOS. Use each build's reported analysis JSON path with the existing size tool (substitute the path variables):

```powershell
dart run tool/size_check.dart android $env:MATHANI_ANDROID_SIZE_JSON
dart run tool/size_check.dart ios $env:MATHANI_IOS_SIZE_JSON
```

Do not supply --approved without the actual review decision. Record dependency/assets deltas and explain growth >1 MB. Measure cold start on Galaxy A15 and iPhone SE (2nd gen), <=2 seconds, 60fps and <=100ms visible feedback. Check reader navigation, ayah playback, memorization interruption and offline web behaviour after integration. Existing paging tests do not by themselves measure schedule scrolling; add a targeted profile scenario.

Before release, update docs/licences.md/About credits, privacy policy/store disclosures, API operational configuration, notification limitations and follow-ups. All G01-G05 evidence is required; this guide does not certify that it has been collected.
