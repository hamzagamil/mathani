# Validation summary: spec v2 implementation

**Date**: 2026-11-02. **Spec**: rewritten 2026-11-02. **Tasks**: [tasks.md](../tasks.md).

The earlier summary for the first draft is in git history. The other files in this folder record
first-draft work and are kept as history.

## Status

The code for all six stories is written. Automated checks pass, apart from 2 failures outside the
prayer code (below). **No Android, iOS or browser device result exists yet.** The workstation is
Windows, with no connected phone, no emulator in use and no Mac. The device checkpoints of every
story are therefore open, and this is not release approval.

| Area | Result |
| --- | --- |
| `flutter analyze` (whole project) | No issues |
| Prayer Dart tests (`test/features/prayer_times`, `test/platform`) | 74 passed |
| Android JVM tests (`PrayerAlarmStoreTest` 8, `PrayerAlarmReceiverTest` 9) | 17 passed, 0 failed; Kotlin main sources compile |
| Location endpoint tests (`node --test tool/prayer/location_api_test.mjs`) | 10 passed; server code unchanged |
| Full VM suite (`flutter test --exclude-tags golden,web`) | 416 passed, 2 failed, both outside prayer times (see Not related) |
| Web release build, Android debug build | Both built (see Builds) |

## What the automated tests cover

- **SC-002**:
  - The existing 1,800-case independent reference (10 cities, 5 methods, both Asr settings,
    both latitude rules) agrees within 1 minute.
  - All 11 methods give six times.
  - The Dubai and Turkey Asr minutes are kept.
  - Offsets work; the latitude default is correct.
  - Oslo in June is adjusted; polar days are unavailable.
  - Umm al-Qura is unavailable outside its table.
  - Daylight-saving days are correct.
  - **Open**: official timetable samples for the six added methods (T025/T026).
- **SC-004** (logic):
  - At most 60 alerts, all in the future, in time order, never Sunrise, more than 7 days ahead.
  - Ids are stable across refills; a place change leaves no stale id or time.
  - Unavailable times are skipped.
  - Android: an older generation is ignored; delivery is once only; 14 minutes late posts and
    16 minutes late is dropped; reboot restores future alerts only.
  - Web page timers: missed alerts are never replayed.
- **SC-005** (logic): Use this place vs viewing, delete with a replacement or alerts off, delete
  the last place, rename rules, delete all.
- **SC-006**: five places or dates within 1 minute of the last-third formula after offsets; no
  Qiyam without valid boundaries.
- **"My location"** (R4):
  - Moves of 5 km are ignored; 10 km or more is resolved.
  - A chosen method is kept; a suggested one follows the new country.
  - Without permission there is no lookup; at most one refresh per 30 minutes; a fixed city is
    never refreshed.
- **Screens** (Arabic and English, 320 px wide, 1.5× text):
  - First-time screen with no permission request before a tap.
  - Six rows, Sunrise marked, day arrows.
  - Suggested row with no confirm step.
  - Alerts sheet with 5 switches plus Qiyam and the blocked status line.
  - An alert tap opens Prayer Times.
  - The large-text test found trailing buttons taking a status row's full width; fixed by moving
    actions below the text.

## Changes found during implementation

- `timezone` `latest_10y` lacks 253 link zones that GeoNames returns, so `latest_all` is kept
  (T003, research R11).
- `flutter_local_notifications` on iOS reports "not enabled" before the first prompt. Turning on
  an alert now asks whenever alerts are not granted; the OS prompts only once.
- The first draft's secure storage, fallback acknowledgements and alarm spike are removed (T001,
  T002).

## Not related to this feature (pre-existing)

- `test/unit/version_test.dart`: `lib/app/version.dart` says `1.5.0+10`, pubspec says
  `1.5.2+15`. `version.dart` was last changed in `da14b3f`, before these prayer commits.
- `test/unit/download_queue_test.dart`: failed once under the full parallel run and passed when
  run alone. Recitation code, not touched here.

## Builds

- `flutter build web --wasm --release --no-web-resources-cdn`: built (`build/prayer-v2-web-build.log`).
- `node tool/web_deploy.mjs --prepare-only`: 689 files prepared, version 1.5.2+15. **Not deployed.**
- `flutter build apk --debug`: built (`build/prayer-v2-apk-build.log`). This is a compile check,
  not a device run.
- The web checks in a browser (quickstart W1–W2, `wrangler pages dev`) are **not done**, and nor
  is the removal of the old browser storage (T068 stays open).

## Open (needs devices, decisions or rights)

| Task | What is missing |
| --- | --- |
| T005, T066 | Cold start and size on the Galaxy A15 / iPhone SE; release size delta via `tool/size_check.dart` |
| US1–US6 checkpoints, T065, T067 | Quickstart device scenarios, the 20-alert timing trial, the 7-day and reboot checks, TalkBack and VoiceOver |
| T025, T026 | Official timetable samples for Dubai, Kuwait, Qatar, Singapore, Turkey and Moonsighting |
| T058 | Athan recordings with redistribution rights (research R10); until then the sound list is the tone and silent |
| iOS | Nothing built or run on iOS: no Mac. The `project.pbxproj` resource entries and `Info.plist` keys are unbuilt. |
| Store | App Privacy and Data safety answers, published policy (`docs/store/privacy.md`) |
