# Implementation Plan: Two-Page Spread on Foldable Phones

**Branch**: `012-foldable-two-page` | **Date**: 2026-11-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/012-foldable-two-page/spec.md`, with the
clarifications of 2026-11-04.

## Summary

The Mushaf layout shows two facing pages when the screen is wide enough, and one page otherwise.

- **The rule** (R1): one pure function, `PageGeometry.spreadFits(Size)`, compares the text size
  of one page and of two pages on the same screen. Two pages show when each keeps at least 70% of
  the one-page size and at least a 240 px text block. It reads the whole screen (or browser
  window), never the device model. System bars and the docked recitation bar do not count, so
  hiding the controls never flips it.
- **The view** (R2): `MushafView` keeps today's page-by-page `PageView` for one page, unchanged.
  For two pages it builds a second `PageView` with 302 items. Each item is a right-to-left row of
  two existing `_MushafPageItem`s: the odd page on the right, binding shades meeting in the middle.
  Switching between one and two pages rebuilds the `PageView` at the reader's page.
- **The reader's place** (R3): `ReaderController` gets `onMushafSpreadShown(rightPage)`. It keeps
  `page` as one page: the right-hand page, or the left one when the selected, jumped-to or
  recited ayah is there. Recitation following, bookmarks, Listen and Memorize keep using
  `reader.page` unchanged, so they behave right on both pages.
- **Controls** (R4): the header shows «صفحة ٤٩–٥٠». The bookmark button looks at both pages. The
  keyboard turns two pages. A new Settings switch, «عرض صفحتين عند الاتساع», on by default, shows
  only on screens where two pages fit.
- **Platforms** (R5–R7): iOS builds move to Xcode 27 (the iOS 27 SDK), so the app fills the
  Duo's inner screen. Android unlocks rotation on large screens only. In browsers, the centred
  phone column of specs/008 widens to hold two pages.

Details: [research.md](./research.md).

## Technical Context

**Language/Version**: Dart 3.13.5 / Flutter 3.47.7 (pinned). Xcode 27 for iOS builds (R5).

**Primary Dependencies**: no new packages. Reused: `PageView`, `MediaQueryData.fromView`,
`SystemChrome.setPreferredOrientations`, and the existing `PaperSheet`, `MushafPageRenderer` and
`PageGeometry`.

**Storage**: one new reading preference, `two_pages` (`true` by default), in the existing
preferences table. No migration: a missing key reads as the default. See
[data-model.md](./data-model.md).

**Testing**:
- **`flutter_test` unit tests**:
  - `spreadFits` on the reference screen sizes of R1;
  - spread arithmetic (index and right-hand page of every page from 1 to 604);
  - `onMushafSpreadShown` keeps the place rules of FR-010;
  - the `two_pages` preference round-trip.
- **`flutter_test` widget tests**, at the open-Duo size (890 × 626, with insets):
  - order and binding sides;
  - swipe two pages at a time;
  - resizing between folded and open keeps the place;
  - header range and bookmark;
  - long-press on the left page;
  - recitation following does not turn within a spread;
  - keyboard turns;
  - the setting hides on a phone and turns the spread off;
  - the web column widens.
- **Golden**: one new spread golden (pages 49–50). The 21 single-page goldens stay unchanged
  (SC-005).
- **Devices**: the manual checks in [quickstart.md](./quickstart.md) on the iPhone Duo simulator,
  a Galaxy Z Fold emulator (or device), the reference phones and a desktop browser.

**Target Platform**: iOS 15.0+, Android 7.0 (API 24)+, and the supported browsers of feature 008.
iPhone only on iOS. Phone portrait, plus large-screen open foldables in either orientation.

**Project Type**: Existing Flutter mobile app with a web build.

**Performance Goals**:
- 60 fps while swiping a spread on the open Duo and Z Fold. Two renderers are laid out per item.
- No blank frame on a spread turn (SC-004).
- Folding or opening shows the reader's page within 1 s (SC-002).
- The single page's cold start, paging and memory are unchanged (SC-005).

**Constraints**:
- The single-page path must stay pixel-identical (FR-003). It keeps today's widget tree.
- The decision must not flip when the recitation or memorization bar docks (FR-001).
- The saved position must not change because the screen changed size (FR-011).

**Scale/Scope**: 302 spreads. One view, one controller method, one preference, three new strings,
and a builder change on the web. No new screen.

## Constitution Check

Constitution 2.0.0. Checked before research and again after design.

| Principle | Result |
| --- | --- |
| **I. Platform parity** | **Pass.** The same Dart code serves iOS, Android and web. The same rule applies on the iPhone Duo, Android book-style foldables and wide browser windows (FR-016). On Android, rotation is unlocked on large screens, so an open Z Fold held either way gets the feature (R6). iOS 15.0 and Android API 24 are stated. Older OS versions run on regular phones, where the rule never triggers. No gaps. |
| **II. Mobile-first** | **Pass, with the opt-in this principle requires.** The spec opts into one large-screen layout, the two-page Mushaf, and nothing else (FR-015). Safe areas are respected: the rule and both pages work inside them. Touch targets are unchanged. Each page keeps its own screen-reader label, right page first. Day and night themes use the existing paper colours. The new setting is a standard switch row. |
| **III. Performance** | **Pass by design, measured before merge.** Startup is untouched. The single page keeps its widget tree. A spread item lays out two pages, which uses the same renderer and cache. It prefetches the neighbouring spreads within the existing 7-page cache (R2). Quickstart Q6 measures spread swiping on the Duo simulator and a Z Fold. Q7 compares single-page paging and memory with the previous build. |
| **IV. Lean** | **Pass.** No dependencies and no assets. About 5 KB of code and three strings in each language. Nothing runs in the background. |
| **V. Simplicity** | **Pass.** One decision function, reused by the reader, the header, the bookmark button, the keyboard, Settings and the web column. Spread items reuse `_MushafPageItem`. The binding side becomes a parameter. The reader's place stays one page, so recitation, memorization, bookmarks and search need no change. The setting is the one the owner asked for. |
| **Platform and store** | **Pass.** No permissions and no data. App Store screenshots for the inner screen are a follow-up once App Store Connect offers the slot (R5). |
| **Workflow** | **Pass.** specify → clarify → plan → tasks → implement. Before merge: device checks on the iPhone Duo simulator, an Android foldable and a regular phone on each platform (quickstart), plus the performance and size checks. |

**Gate result**: passes before and after design. No unresolved clarifications. Complexity
Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/012-foldable-two-page/
├── plan.md              # This file
├── research.md          # Phase 0: R1–R8
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1: validation guide
├── contracts/
│   └── two-page-ui.md   # Rule, layout, place, controls, strings, semantics
├── checklists/
│   └── requirements.md  # From /speckit-specify
└── tasks.md             # Phase 2 (/speckit-tasks, not created here)
```

### Source Code (repository root)

```text
lib/
├── app/
│   ├── app.dart                    # PhoneColumn widens for a spread on the web (R7);
│   │                               # orientation sync on phones (R6)
│   └── l10n/app_ar.arb, app_en.arb # pagesLabel, twoPagesSetting, twoPagesHint
├── data/
│   ├── models.dart                 # ReaderPreferences.twoPages
│   └── user_repository.dart        # 'two_pages' read and write
├── features/
│   ├── reader/
│   │   ├── page_geometry.dart      # PageGeometry.spreadFits(Size) (R1)
│   │   ├── mushaf_view.dart        # showsSpread(context); spread PageView; binding side (R2)
│   │   └── reader_screen.dart      # header range, bookmark on both pages, keyboard ±2 (R4)
│   └── settings/
│       └── settings_screen.dart    # the two-pages switch, shown only where it fits
└── shared/
    └── reader_state.dart           # onMushafSpreadShown (R3)

ios/                                # unchanged (Info.plist keeps portrait for the outer screen)
android/app/src/main/AndroidManifest.xml  # unchanged; rotation unlocked at run time (R6)
.github/workflows/ci.yml, ios-release.yml # select Xcode 27 (R5)

test/
├── unit/
│   ├── spread_fits_test.dart       # NEW
│   └── reader_spread_place_test.dart   # NEW
└── widget/
    ├── two_page_spread_test.dart   # NEW
    ├── mushaf_page_renderer_golden_test.dart  # + spread golden
    ├── keyboard_test.dart          # + two-page turns
    └── wide_window_test.dart       # + widened column
```

**Structure Decision**: The feature lives in the existing reader feature folder. It adds no new
source files except tests.

## Complexity Tracking

No violations to justify.
