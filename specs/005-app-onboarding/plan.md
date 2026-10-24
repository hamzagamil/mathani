# Implementation Plan: Onboarding

**Branch**: `005-app-onboarding` | **Date**: 2026-10-24 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/005-app-onboarding/spec.md`

## Summary

A first-run onboarding. The reader first picks their language, theme, layout (and text size for
flowing) and reciter, with each choice applied live. A tour then teaches the app:

- illustrated, animated **gesture stops**: turning pages, tapping for the controls, and
  press-and-hold on an ayah;
- **button hints** over the real reading screen: index, search, player, Settings.

Skip ends it from any step in one tap. Readers updating from 1.3.0 see it once, with their saved
choices selected. Settings can replay the tour.

1. **Flow** (research R1, R2): one pure function gives the step sequence. A small
   `OnboardingController` holds the position, and `MaterialApp.home` shows `OnboardingScreen` or
   `ReaderScreen` from its phase. One new preference, `onboarding_done`, has no schema change and
   covers fresh installs, updates and closing midway. The old one-time controls hint is removed,
   because the onboarding supersedes it.
2. **Gestures** (R3): a `CustomPaint` miniature in the reader's own layout and theme tokens, with
   an animated touch dot. It uses no assets and no dependency, and respects reduce motion.
3. **Button hints** (R4): a custom overlay that punches a hole around the real toolbar buttons
   (`GlobalKey` rects). It absorbs taps and forces the controls visible. The reading views hold
   page jumps while it is up, so a recitation never turns the page under a hint.
4. **Reciter samples** (R5): `RecitationController.previewReciter` plays Al-Fatiha 1:1 through the
   existing fetcher and engine. It creates no session, bar, highlight or lock-screen controls. A
   network pre-check and a 5 s timeout show the offline note.

## Technical Context

**Language/Version**: Dart 3.13.5 / Flutter 3.47.7 (pinned). No platform code.

**Primary Dependencies**: Existing only: `sqflite`, `just_audio` and `audio_service`, through
`RecitationController`, plus `intl`. **No new dependency.**

**Storage**:
- `user.db` › `preferences`: one key, `onboarding_done`. The key `controls_hint_shown` is no
  longer read or written.
- No schema change, and no new files on disk.

**Testing**:
- `flutter_test` unit tests for the step sequence, the controller and the reciter preview (fake
  engine and the existing `fake_audio_server`).
- Widget tests for the onboarding screen, the button tour and accessibility.
- The integration first-run pass in `app_flow_test.dart`.
- Device scenarios Q-1 to Q-18 in [quickstart](./quickstart.md).

**Target Platform**: iOS 15.0+ and Android 7.0 (API 24)+, target API 36. Phones, portrait.

**Project Type**: mobile app (single Flutter project, no backend).

**Performance Goals**:
- First onboarding screen usable within the existing ≤ 2 s cold-start budget (SC-006).
- Step changes respond within 100 ms.
- Gesture animations at 60 fps.
- Reader paging unchanged.

**Constraints**:
- Works fully offline except samples.
- No data sent and no analytics.
- No permissions requested.
- Readers updating keep their position, bookmarks, downloads and preferences.
- Store growth under 1 MB.

**Scale/Scope**:
- 4–5 setup steps and 7 tour stops.
- 37 new strings per language.
- New: 1 screen, 1 overlay, 1 illustration widget, 1 controller, 1 Settings row.
- Changes to the app shell, preferences, reader screen, two reading views, recitation
  controller and Settings.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution v2.0.0.

| Principle | Gate | Pre-research | Post-design |
| --- | --- | --- | --- |
| I. Cross-Platform Parity | Same on iOS and Android; platform conventions | ✅ | ✅ Pure Flutter, with no platform code. System back follows Android convention: back steps, and the first step leaves the app. iOS uses the on-screen Back button. Q-9 and Q-10 run on both stores' update paths. Every scenario runs on both phones plus API 24. |
| II. Mobile-First Design | Phone portrait; 44 pt / 48 dp; safe areas; dark mode; font scaling; screen readers | ✅ | ✅ Navigation sits in a bottom bar within one-handed reach, and the hint card sits just above the toolbar. Steps scroll inside, so the bar never clips, and it wraps at large text. Day and night come from tokens. VoiceOver and TalkBack: radio semantics, focus on titles, and the scrim excluded under hints (Q-15, Q-16). Reduce motion is honoured (Q-17). |
| III. Performance (NON-NEGOTIABLE) | ≤ 2 s cold start; 60 fps; ≤ 100 ms feedback; no UI-thread blocking | ✅ | ✅ No work added before the first frame: `onboarding_done` arrives in the existing single startup query. The first onboarding frame is lighter than the reader's. Animations are a single `CustomPaint` in a `RepaintBoundary`. Audio initialises only when a sample is played. Reader paging is untouched; the hold check is one boolean read. |
| IV. Lean by Default | Dependencies justified; > 1 MB growth called out; on-demand content; minimal background | ✅ | ✅ No dependency and no assets; coach-mark and animation packages were rejected (R3, R4). The dead controls-hint code is removed. Samples stream on demand into the existing capped cache. Expected growth is about 25–40 KB. |
| V. Simplicity | Simplest solution; reuse; complexity justified | ✅ | ✅ One step-list function drives order, progress and back. It reuses `updatePreferences`, `setReciter`, the fetcher and engine, `MathaniColors`, `MathaniIcons` and the Settings controls' bounds. The only new cross-cutting hook is `holdsReader`, read by two views; it is required by the spec's edge case and costs about 2 lines each. |
| Store & privacy | Policies; permissions only when needed; graceful degradation | ✅ | ✅ No new permissions and no data collected. The sample uses the audio host already disclosed for 004. Offline degrades to a note (FR-010). |

**Result**: PASS. Nothing goes in Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/005-app-onboarding/
├── plan.md              # This file
├── research.md          # R1–R9: flow, status/updates, gestures, button hints, samples, previews, replay, tests, perf/size
├── data-model.md        # onboarding_done, steps and sequence, controller states, reciter preview
├── quickstart.md        # tests, 18 device scenarios, perf/size gates
├── contracts/
│   ├── onboarding-flow.md   # controller API, app shell, preferences, reader/views hooks, preview API, Settings, tests
│   └── onboarding-ui.md     # onboarding screen and steps, button tour, Settings row, strings (ar/en), a11y
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks; not created here)
```

### Source Code (repository root)

```text
lib/
├── features/onboarding/                  # NEW feature folder
│   ├── onboarding_steps.dart             # OnboardingStep, kinds, steps(...) (pure Dart)
│   ├── onboarding_controller.dart        # OnboardingController + OnboardingScope
│   ├── onboarding_screen.dart            # setup steps and gesture stops, bottom bar
│   ├── setup_steps.dart                  # language, theme, layout, text size, reciter step bodies
│   ├── tour_illustration.dart            # CustomPaint miniature + animated touch dot
│   └── button_tour.dart                  # scrim with hole, callout card, TourTargets
├── app/
│   ├── app.dart                          # _Home; OnboardingScope; `onboarding` parameter
│   └── l10n/app_{ar,en}.arb              # new strings; controlsHint removed
├── data/
│   ├── models.dart                       # ReaderPreferences.onboardingDone; controlsHintShown removed
│   └── user_repository.dart              # onboarding_done read/write
├── features/reader/
│   ├── reader_screen.dart                # ButtonTour while phase == buttons; TourTargets keys; hint removed
│   ├── mushaf_view.dart                  # hold jumps while holdsReader
│   └── flowing_view.dart                 # hold jumps while holdsReader
├── features/recitation/
│   ├── recitation_controller.dart        # previewReciter / stopPreview / preview
│   └── recitation_bar.dart               # accepts the player tour key
├── features/settings/settings_screen.dart  # "See the tour again" row
└── main.dart                             # builds OnboardingController

test/
├── support/harness.dart                  # openTestReader({onboarded = true})
├── unit/onboarding_steps_test.dart
├── unit/onboarding_controller_test.dart
├── unit/reciter_preview_test.dart
├── widget/onboarding_screen_test.dart
├── widget/button_tour_test.dart
├── widget/onboarding_a11y_test.dart
└── widget/reader_page_view_test.dart     # controls-hint expectations removed

integration_test/
├── app_flow_test.dart                    # first-run pass; existing passes set onboardingDone
├── paging_perf_test.dart                 # onboardingDone: true
└── store_screenshots_test.dart           # onboardingDone: true
```

**Structure Decision**: One new feature folder, `lib/features/onboarding/`, follows the existing
`features/<name>/` layout. Changes elsewhere are limited to the hooks listed in
[onboarding-flow](./contracts/onboarding-flow.md).

## Complexity Tracking

No constitution violations, so nothing to justify.
