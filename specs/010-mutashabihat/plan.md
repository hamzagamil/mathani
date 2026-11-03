# Implementation Plan: Mutashabihat (Similar Ayat)

**Branch**: `010-mutashabihat` (feature ID; the work so far is on `008-web-app`) |
**Date**: 2026-11-03 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/010-mutashabihat/spec.md`, with the clarifications
of 2026-11-03.

## Summary

The owner writes groups of similar ayat and their explanations in one Markdown file,
`assets/mutashabihat/mutashabihat.md`, which ships inside the app and the web app. The app loads
it at startup, alongside the databases.

- **Colour**: every linked ayah is drawn in a new gold-brown `similar` colour on the Mushaf page
  and in the flowing layout. During a memorization session nothing is coloured.
- **Action and overlay**: long-pressing a linked ayah adds «عرض المتشابه» to the actions sheet.
  It opens a bottom-sheet overlay: the ayah and its similar ayat in the top two thirds, the
  owner's explanation in the bottom third, each part scrolling on its own.
- **Release check**: a plain-Dart check stops CI, the iOS release workflow and the web deploy if
  the file references an ayah that does not exist, has a group of fewer than two ayat, or has an
  empty explanation.

Details: [research.md](./research.md).

## Technical Context

**Language/Version**: Dart 3.13.5 / Flutter 3.47.7 (pinned). The web deploy script is Node.js
(`tool/web_deploy.mjs`).

**Primary Dependencies**: no new packages. Reused: Flutter `rootBundle`, the existing Lucide icon
font (one more glyph) and the existing theme tokens.

**Storage**: one bundled read-only asset, `assets/mutashabihat/mutashabihat.md`, held in memory
after startup. No database changes. See [data-model.md](./data-model.md).

**Testing**:
- **`flutter_test` unit tests**:
  - parser rules;
  - the shipped file has no errors;
  - the ayah-count table matches `quran.db`;
  - colour contrast and hue rules.
- **`flutter_test` widget tests**:
  - action shown and hidden;
  - overlay order, 2:1 split, independent scrolling;
  - group chips;
  - jump on tap;
  - closing.
- **Renderer tests**: linked words get the colour, unlinked words and memorization do not.
- **`dart run tool/check_mutashabihat.dart`**: the release gate.
- **Devices**: the manual checks in [quickstart.md](./quickstart.md), on the reference phones and
  a browser.

**Target Platform**: iOS 15.0+, Android 7.0 (API 24)+, and the supported browsers of feature 008.
Phone portrait.

**Project Type**: Existing Flutter mobile app with a web build.

**Performance Goals**:
- Cold start ≤ 2 s on Galaxy A15 and iPhone SE (2nd gen), changed by less than 50 ms.
- 60 fps paging with no new dropped frames.
- Overlay within 1 s, tap feedback ≤ 100 ms (SC-001).

**Constraints**:
- Works offline (FR-013).
- A bad or missing file never breaks reading (FR-019).
- No release while the check fails (FR-016).
- No per-word compositing layers on the page (R5).

**Scale/Scope**:
- Content: up to about 1,000 groups and 1 MB of text. Starting content is the owner's call.
- Groups up to about 30 ayat.
- UI: one new sheet and one new action row. Two existing views get the colour.

## Constitution Check

Constitution 2.0.0. Checked before research and again after design.

| Principle | Result |
| --- | --- |
| **I. Platform parity** | **Pass.** The same Dart code serves iOS, Android and web. Long-press on phones and right-click on the web open the same sheet. iOS 15.0 and Android API 24 are stated. Back, swipe down and safe areas use each platform's bottom-sheet behaviour. No gaps. |
| **II. Mobile-first** | **Pass.** Portrait bottom sheet within safe areas. ✕, chips and ayah cards are ≥ 44 pt / 48 dp. RTL. Day and night colour values. Both parts scroll under maximum font scaling. Screen-reader labels (R8). Checked in quickstart Q2–Q3. |
| **III. Performance** | **Pass by design, measured before merge.** The file loads in parallel with the databases, not after them (R3). The colour is set at layout, so no frame cost (R5). The overlay uses a lazy list. Quickstart Q1 measures cold start and paging, Q3 the overlay. |
| **IV. Lean** | **Pass.** No new dependencies. Adds a text asset (a few KB at first, about 1 MB at the expected maximum, smaller once compressed in the store package), about 15 KB of code and one icon glyph. Size measured in quickstart Q8. Nothing runs in the background. |
| **V. Simplicity** | **Pass.** One file is both the source and the shipped asset: no generator, no database change, no server. The checks are written once and used by the app, the tool and the tests. No setting to turn the colour off (spec Assumptions). The new sheet reuses the bottom-sheet pattern, `flowingTextStyle`, `flowingAyahText` and `reader.jumpTo`. |
| **Platform and store** | **Pass.** No permissions, no personal data, no network. Store privacy answers do not change. |
| **Workflow** | **Pass.** specify → clarify → plan → tasks → implement. Before merge: device checks on iPhone and Android (quickstart), plus the performance and size checks. |

**Gate result**: passes before and after design. No unresolved clarifications. Complexity
Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/010-mutashabihat/
├── plan.md              # This file
├── research.md          # Phase 0: R1–R10
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1: validation guide
├── contracts/
│   ├── content-file.md      # The owner's file format and the checks
│   └── mutashabihat-ui.md   # Strings, colour, action row, overlay, semantics
├── checklists/
│   └── requirements.md  # From /speckit-specify
└── tasks.md             # Phase 2 (/speckit-tasks, not created here)
```

### Source Code (repository root)

```text
assets/mutashabihat/
└── mutashabihat.md                 # NEW: the owner's content (format guide at the top)

lib/
├── main.dart                       # load Mutashabihat in parallel with the databases
├── app/
│   ├── l10n/app_ar.arb, app_en.arb # new strings (contracts/mutashabihat-ui.md)
│   └── theme/
│       ├── tokens.dart             # SemanticColors.similar
│       └── app_theme.dart          # MathaniColors.similar
├── features/
│   ├── mutashabihat/               # NEW
│   │   ├── mutashabihat_content.dart   # plain Dart: parser, checks, ayahCounts, Mutashabihat
│   │   ├── mutashabihat_loader.dart    # loadMutashabihat() from rootBundle; empty on failure
│   │   └── similar_sheet.dart          # showSimilarSheet: the overlay
│   └── reader/
│       ├── ayah_actions.dart       # «عرض المتشابه» row for linked ayat
│       ├── mushaf_view.dart        # pass `similar` (null during memorization); page semantics
│       ├── mushaf_page_renderer.dart   # colour at layout; palette.similar; stretched-painter key
│       └── flowing_view.dart       # span colour and end-marker semantics label
└── shared/
    ├── mathani_icons.dart          # similar (Lucide git-compare)
    └── reader_state.dart           # ReaderController.similar

tool/
└── check_mutashabihat.dart         # NEW: the release check (exit code 1 on error)

test/
├── unit/
│   ├── mutashabihat_content_test.dart  # NEW: rules, shipped file, ayahCounts vs quran.db
│   └── similar_colour_test.dart        # NEW: contrast and hue
└── widget/
    ├── similar_sheet_test.dart         # NEW: overlay
    ├── ayah_actions_test.dart          # action shown and hidden
    └── mushaf_typesetting_test.dart    # linked words coloured; not during memorization

pubspec.yaml                        # assets/mutashabihat/
.github/workflows/ci.yml            # run the check
.github/workflows/ios-release.yml   # run the check before building
tool/web_deploy.mjs                 # run the check in prepare()
docs/release.md                     # checklist line before Android builds
```

**Structure Decision**: The feature gets its own folder, `lib/features/mutashabihat/`, like
`recitation/` and `memorization/`. The reader files change only where they draw ayat or list
actions. `mutashabihat_content.dart` imports nothing from Flutter, so `tool/` can use it with
`dart run` (R2). `mutashabihat_loader.dart` holds the Flutter-dependent asset read.

## Complexity Tracking

No violations.
