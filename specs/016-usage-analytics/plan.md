# Implementation Plan: Usage Analytics

**Branch**: `016-usage-analytics` | **Date**: 2026-11-21 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/016-usage-analytics/spec.md`

## Summary

Firebase Analytics on Android, iOS and the web, feeding the owner's GA4 property 539746070, always
on with no switch (spec Clarifications). Every event goes through one allowed-events list
(`lib/features/analytics/usage.dart`, [contracts/usage-events.md](contracts/usage-events.md)):
14 screen names, 12 actions and `setting_changed` with values from enums or the app's catalogues.
Nothing about what is read, recited, searched or written is sent. Collection is enabled only in
release builds (and on `get.mthani.app` for the web), starts after the first frame, and shares the
Firebase start with announcements. No advertising identifier, no tracking, no automatic screen
names. Store answers, the iOS privacy manifest, the listings, About and the published policy are
updated.

## Technical Context

**Language/Version**: Dart 3.13 / Flutter 3.47.7

**Primary Dependencies**: new `firebase_analytics` 13.1.0 (research R1); existing `firebase_core`
5.2.0

**Storage**: none in `user.db`; the library's own id and queue

**Testing**: `flutter test` (usage facade, settings diff, sink queue, privacy import test); manual
checks in [quickstart.md](quickstart.md) with Realtime and DebugView

**Target Platform**: iOS 15.0+, Android 7.0 (API 24)+, web (get.mthani.app)

**Project Type**: mobile app (Flutter) with a web build on Cloudflare Pages

**Performance Goals**: no cold-start regression over 50 ms (SC-005): nothing before `runApp`, sink
starts after the first frame

**Constraints**: FR-004 never-sent list; FR-005 no ad id; release-only collection (FR-013); web CSP

**Scale/Scope**: 1 new dependency, 2 new Dart files plus a platform file, ~14 screens tagged, ~12
call sites, 1 About sentence, manifest/plist/CSP/privacy-manifest edits, docs

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
| --- | --- | --- |
| I. Parity | Same events on Android and iOS (and web) | Pass |
| II. Mobile-first | One sentence and a link in the existing About section; no new UI | Pass |
| III. Performance | Started after the first frame; logging is fire-and-forget; queue capped at 50 | Pass |
| IV. Lean | New dependency justified below; size measured (research R9) and called out if > 1 MB | Pass, with justification |
| V. Simplicity | One facade, one sink interface, one mixin; no consent machinery (owner decision) | Pass |
| Store requirements | App Privacy, Data safety, privacy manifest and policy updated (research R10) | Pass, owner confirms in consoles |

## Project Structure

### Documentation (this feature)

```text
specs/016-usage-analytics/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/usage-events.md
└── tasks.md (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/features/analytics/usage.dart          # allowed-events list, Usage facade, UsageSink, NoUsage, ScreenTracking
lib/platform/firebase_app.dart             # firebaseReady(): one Firebase start for all
lib/platform/usage_firebase.dart           # FirebaseUsage sink (phones and web)
lib/platform/announcements_io.dart         # uses firebaseReady(); logs announcement_opened
lib/main.dart                              # installs the sink, starts it after the first frame
lib/app/app.dart                           # RouteObserver in MaterialApp
lib/shared/reader_state.dart               # setting_changed diffs
lib/features/**                            # ScreenTracking on screens; action calls
lib/features/settings/about_section.dart   # privacy sentence and link
lib/firebase_options.dart                  # + web (flutterfire configure)
android/app/src/main/AndroidManifest.xml   # collection off by default, no AD_ID, no ad signals, no auto screens
ios/Runner/Info.plist, PrivacyInfo.xcprivacy
web/_headers                               # CSP hosts
test/features/analytics/
docs/store/privacy.md, docs/store/listing_*.md; Mathani-landing privacypolicy.html
```

**Structure Decision**: Follows specs/015: a feature folder for the logic, a platform file for
Firebase, nothing in `user.db`.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
| --- | --- | --- |
| New dependency `firebase_analytics` (+ Google App Measurement natively, ~0.5–2 MB) | The owner's GA4 property and dashboard are fed by it (spec input) | Measurement Protocol through a function needs an owner-created secret and session handling; other tools do not feed GA4 |
| Third-party scripts on the web (gstatic, googletagmanager) and wider CSP | Firebase JS SDK and gtag are how the web stream reports | Same as above |

## Post-design Constitution Check

Unchanged: Pass. The allowed-events list and the import test keep the privacy boundary
reviewable; collection is release-only; size is measured before release.
