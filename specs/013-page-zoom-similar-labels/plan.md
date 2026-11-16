# Implementation Plan: Surah Header Width, Sideways Scrolling Page, Named Similar-Ayah Tabs

**Branch**: `013-page-zoom-similar-labels` | **Date**: 2026-11-11 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/013-page-zoom-similar-labels/spec.md`, with the
clarifications of 2026-11-11, including the two made during planning.

## Summary

Three changes to the reader, and one part of the spec that needs no code.

- **Margins** (R1): no change. The page details already sit against the text and the text
  already uses the full width. The owner chose to keep the empty paper above and below the page
  on tall phones. Existing goldens guard it.
- **Surah header** (R2): the header glyph is sized by the text block's width only, so its ink
  spans the block. Today a height limit keeps it at 86%. It becomes 5% taller than its line,
  which fits in the clear space around the line. Where it is the first or last line of a page,
  the page details beside it move away slightly so that they do not touch it.
- **Rotation** (R3): Android's manifest moves from `portrait` to `user`, and iOS lists the two
  landscape orientations. The run-time orientation switch of specs/012 is deleted.
- **Sideways page** (R4–R6): one decision function, `scrollsPage`. When it is true, a page item
  wraps today's page tree in a vertical scroll view at full width. The renderer is unchanged. A
  new `ayahRect` lets the page scroll to the recited, highlighted or expected ayah.
- **Other screens** (R7): no redesign. One test finds overflows at a sideways phone size; fixes
  are limited to scrolling and safe areas.
- **Tabs** (R8, R9): a pure function works out each tab's wording from the pressed ayah: the
  longest run it shares with at least half of the group's other ayat, or with one of them when
  that is under two words. The rule in the first draft of the spec (wording in every ayah) gave
  one common word or nothing on 9 of the 32 tabs in the published content. The chosen rule gives
  two or more words on 31.

Details: [research.md](./research.md).

## Technical Context

**Language/Version**: Dart 3.13.5 / Flutter 3.47.7 (pinned).

**Primary Dependencies**: no new packages. Reused: `SingleChildScrollView`, `PageView`,
`ChoiceChip`, `normalizeArabic` (search), `QuranRepository.wordsOf`, and the existing
`MushafPageRenderer`, `PageGeometry`, `PaperSheet` and `ScreenArea`.

**Storage**: none. No preference, table, asset or content-file change. See
[data-model.md](./data-model.md).

**Testing**:
- **`flutter_test` unit tests**:
  - the tab label rules (half, any, number fallback, five-word cut, pause marks, duplicates);
  - the labels on the bundled content and database (SC-006, SC-007);
  - `PageGeometry.scrollPageHeight` gives a width-limited block.
- **`flutter_test` widget tests**:
  - all 114 surah headers: width and no overlap (SC-010);
  - the sideways page at 780 × 360: scroll range, page turns start at the top, rotation keeps
    the page, long-press, following, no scrolling on spread-sized screens or the web;
  - every screen and sheet at 780 × 360, text scale 1.0 and 1.3, both languages: no overflow;
  - the similar-ayah sheet's tabs and their screen-reader labels.
- **Golden**: one new sideways golden. Single-page goldens without a surah title stay
  unchanged (SC-002); those that draw the header glyph are regenerated.
- **Devices**: the checks in [quickstart.md](./quickstart.md) on one iOS and one Android phone,
  an Android 7 emulator, a foldable simulator and a desktop browser.

**Target Platform**: iOS 15.0+, Android 7.0 (API 24)+, and the supported browsers of feature
008. iPhone only on iOS. Phones now turn sideways; the web is unchanged apart from the header
and the tabs.

**Project Type**: Existing Flutter mobile app with a web build.

**Performance Goals**:
- 60 fps while scrolling the sideways page and while turning pages on it (SC-004).
- The reader's page is on screen within 1 s of a rotation (SC-005).
- The similar-ayah sheet gives feedback within 100 ms (SC-009): the ayah is selected before the
  labels are computed.
- Portrait cold start, paging and memory are unchanged.

**Constraints**:
- `PageGeometry.of` must return the same geometry for the same size (SC-002).
- The spread of specs/012 and the web's wide-window behaviour must not change (FR-015).
- `scrollsPage` must not flip when a bar docks or the controls show (R4).
- No screen sets its own orientation (R3).

**Scale/Scope**: 604 pages, 114 headers, 72 groups today. One new source file
(`shared_wording.dart`), changes in five existing source files, two platform files, and a
number of small overflow fixes found by the R7 test. No new screen, string or setting.

## Constitution Check

Constitution 2.0.0. Checked before research and again after design.

| Principle | Result |
| --- | --- |
| **I. Platform parity** | **Pass.** The same Dart code serves iOS and Android. Rotation is declared in each platform's own file, with the same result: portrait and both landscapes, system lock respected. iOS 15.0 and Android API 24 are stated. The web gets the header and the tabs; it does not get rotation, which FR-024 states. |
| **II. Mobile-first** | **Pass, with the opt-in this principle requires.** The spec opts into landscape for the Mushaf page on phones and nothing else (FR-013). Portrait stays the first design. Safe areas are respected on the sideways page, including a side camera cut-out. Tab chips keep the 48 × 48 target. Screen readers get the tab wording and the standard scroll actions. System font scaling is covered by the R7 test at 1.3 and by quickstart Q8. |
| **III. Performance** | **Pass by design, measured before merge.** Startup is untouched. The portrait page keeps its widget tree. The sideways page is the same renderer at a larger size, inside a repaint boundary, so a scroll does not re-run layout or paint. Label computation is a few thousand comparisons on local data, after the selection feedback. Quickstart Q6 measures frame times and memory on the reference Android phone. |
| **IV. Lean** | **Pass.** No dependencies and no assets. `syncOrientation` and its test are removed. About 6 KB of code. Nothing runs in the background. |
| **V. Simplicity** | **Pass.** One decision function beside `showsSpread`. The scrolling page reuses the page item and renderer unchanged. Rotation is two declarative platform lines. Labels are one pure function that reuses the search normaliser. No setting, no cache, no new abstraction. |
| **Platform and store** | **Pass.** No permissions and no data. Store screenshots stay portrait. |
| **Workflow** | **Pass.** specify → clarify → plan → tasks → implement. Before merge: device checks on one iOS and one Android phone (quickstart), plus the performance and size checks, since this touches lists and navigation surfaces. |

**Gate result**: passes before and after design. No unresolved clarifications. Complexity
Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/013-page-zoom-similar-labels/
├── plan.md              # This file
├── research.md          # Phase 0: R1–R9
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1: validation guide
├── contracts/
│   └── reader-ui.md     # Header, decision, scrolling page, rotation, tabs
├── checklists/
│   └── requirements.md  # From /speckit-specify
└── tasks.md             # Phase 2 (/speckit-tasks, not created here)
```

### Source Code (repository root)

```text
lib/
├── app/
│   └── app.dart                      # remove syncOrientation and its call (R3)
├── features/
│   ├── reader/
│   │   ├── page_geometry.dart        # scrollPageHeight(width) (R5)
│   │   ├── mushaf_page_renderer.dart # header sized by width (R2); ayahRect, surahHeaderRects (R6)
│   │   ├── mushaf_view.dart          # scrollsPage(context); scroll view in _MushafPageItem;
│   │   │                             # reset to top; follow target (R4–R6)
│   │   └── reader_screen.dart        # unchanged unless the R7 test finds an overflow
│   ├── mutashabihat/
│   │   ├── shared_wording.dart       # NEW: tabLabels(...) — plain Dart (R8)
│   │   └── similar_sheet.dart        # labels computed before opening; chips show them (R9)
│   └── onboarding/, memorization/, … # overflow fixes found by the R7 test only
android/app/src/main/AndroidManifest.xml  # screenOrientation: portrait → user (R3)
ios/Runner/Info.plist                     # + LandscapeLeft, LandscapeRight (R3)

test/
├── unit/
│   ├── shared_wording_test.dart          # NEW
│   └── shared_wording_content_test.dart  # NEW: bundled content and database
└── widget/
    ├── surah_header_width_test.dart      # NEW
    ├── sideways_page_test.dart           # NEW
    ├── sideways_screens_test.dart        # NEW
    ├── similar_sheet_test.dart           # + wording tabs
    ├── mushaf_page_renderer_golden_test.dart  # + sideways golden; header goldens regenerated
    └── two_page_spread_test.dart         # − syncOrientation cases
```

**Structure Decision**: The feature lives in the existing reader and mutashabihat feature
folders. It adds one source file, `shared_wording.dart`, kept free of Flutter so the unit tests
and any later tool can use it.

## Complexity Tracking

No violations to justify.
