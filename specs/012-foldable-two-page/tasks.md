---

description: "Tasks for Two-Page Spread on Foldable Phones"
---

# Tasks: Two-Page Spread on Foldable Phones

**Input**: Design documents from `specs/012-foldable-two-page/`. Read these before starting a
phase:
- [plan.md](./plan.md)
- [spec.md](./spec.md)
- [research.md](./research.md)
- [data-model.md](./data-model.md)
- [contracts/two-page-ui.md](./contracts/two-page-ui.md)
- [quickstart.md](./quickstart.md)

**Prerequisites**: plan.md and spec.md (required).

**Tests**: plan.md (Technical Context › Testing) lists the automated tests, so test tasks are
included. Device checks are in [quickstart.md](./quickstart.md).

**Organization**: Tasks are grouped by user story. All four stories are P1, and US1 is the MVP.
US2 and US3 build on the US1 view. US4 is a regression guard that runs alongside them.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on unfinished tasks).
- **[Story]**: US1–US4 from spec.md.

## Path Conventions

Single Flutter project:
- **Dart**: `lib/`, tests in `test/`.
- **CI**: `.github/workflows/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: The iOS 27 build tools, which gate the iPhone Duo part of the feature (research R5).

- [ ] T001 On a Mac with Xcode 27, run `flutter build ios --no-codesign` and `flutter run` on the
  iPhone Duo simulator with the pinned Flutter 3.47.7. Record in `specs/012-foldable-two-page/research.md`
  R5 whether it builds and whether the app fills the open inner screen. If it does not build,
  stop. Raise a Flutter upgrade as its own task before continuing with iOS. Android and web work
  can go ahead.
- [X] T002 [P] Select Xcode 27 explicitly on the `macos-latest` jobs in `.github/workflows/ci.yml`
  and `.github/workflows/ios-release.yml` (a `sudo xcode-select -s /Applications/Xcode_27*.app`
  step before the Flutter steps). Keep `IPHONEOS_DEPLOYMENT_TARGET = 15.0`,
  `TARGETED_DEVICE_FAMILY = 1` and the portrait-only `UISupportedInterfaceOrientations` in
  `ios/Runner/Info.plist` unchanged.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The decision rule, the spread arithmetic, the preference and the strings, which
every story uses.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T003 [P] Write `test/unit/spread_fits_test.dart`. Expect `PageGeometry.spreadFits` to give
  every row of the research R1 table: one page for 375×667, 393×852, 466×678, 445×626, 412×915,
  800×1280 and 600×400; two pages for 890×626, 750×832, 832×750, 714×831, 690×829 and 1440×900. Also
  check the spread arithmetic for every page from 1 to 604: right-hand page `p.isOdd ? p : p - 1`,
  index `(p - 1) ~/ 2` from 0 to 301, and 302 spreads.
- [X] T004 [P] Add `twoPages` to `ReaderPreferences` in `lib/data/models.dart`: `bool`, default
  `true`, included in `copyWith`. In `lib/data/user_repository.dart`, read the `preferences` key
  `two_pages` so that `'false'` turns it off and any other value or a missing key reads as the
  default (`true`), and write it as `'${p.twoPages}'`. Add a round-trip test, including a store
  with no `two_pages` key, in `test/unit/two_pages_pref_test.dart`.
- [X] T005 [P] Add the strings from `contracts/two-page-ui.md` › Strings to
  `lib/app/l10n/app_ar.arb` and `lib/app/l10n/app_en.arb`:
  - `pagesLabel(first, second)`: «صفحة {first}–{second}» / "Pages {first}–{second}";
  - `twoPagesSetting`: «عرض صفحتين عند الاتساع» / "Two pages when there is room";
  - `twoPagesHint`: «تظهر صفحتان متقابلتان حين تتسع الشاشة لهما، كالمصحف المفتوح.» / "Shows two facing pages, like an open Mushaf, when the screen is wide enough.".

  Add `@` metadata for the placeholders, then regenerate `lib/app/l10n/app_localizations*.dart`
  with `flutter gen-l10n`.
- [X] T006 Implement `static bool spreadFits(Size area)` in `lib/features/reader/page_geometry.dart`,
  reusing `blockRatio`, `bandLines`, `linesPerPage` and `markerMarginFraction`.
  `block(w, h) = min((1 - 2 × markerMarginFraction) × w, h / (blockRatio × (1 + 2 × bandLines / linesPerPage)))`.
  It returns true when `block(W / 2, H) ≥ 0.7 × block(W, H)` and `block(W / 2, H) ≥ 240`. Add
  the static helpers `spreadRightPage(int page)`, `spreadIndex(int page)` and
  `spreadCount = 302` beside it. Make T003 pass.
- [X] T007 In `lib/features/reader/mushaf_view.dart`, add the top-level `bool showsSpread(BuildContext context)`
  (contracts/two-page-ui.md › Decision). It is true when the layout is `ReadingLayout.mushaf`,
  `preferences.twoPages` is on, and `PageGeometry.spreadFits` holds for the screen area. The area
  is the whole screen: `ScreenArea.sizeOf(context)`, which is the size `PhoneColumn` passes down on
  the web (the window) and the `MediaQuery` size elsewhere. Nothing is subtracted (research R1). Also add `bool spreadFitsScreen(BuildContext context)`, the same area check without the
  layout and preference conditions, for Settings.

**Checkpoint**: The rule and the preference exist. Nothing visible has changed yet.

---

## Phase 3: User Story 1 - Read two facing pages on the open phone (Priority: P1) 🎯 MVP

**Goal**: On a wide screen the Mushaf shows two facing pages: odd on the right, binding in the
middle, two pages per swipe. This covers the open Duo, an open Z Fold and wide browser windows.

**Independent Test**: At 890×626 with insets, open page 50 and see 49 (right) and 50 (left).
Swipe forward to 51–52. Pages 1 and 604 show 1–2 and 603–604.

### Tests for User Story 1

- [X] T008 [P] [US1] Write `test/widget/two_page_spread_test.dart`, using `openTestReader` from
  `test/support/harness.dart` and a view of 890×626 at device pixel ratio 3 with top and bottom
  insets. Check:
  - at page 50, two `MushafPageRenderer`s show, page 49's rect is right of page 50's, and both
    are the same size;
  - a left-to-right fling shows 51–52, and the reverse fling from 49–50 shows 47–48;
  - jumping to 1 shows 1–2, and jumping to 604 shows 603–604;
  - the `PaperSheet`s of the right page and the left page have `bindingOnRight` `false` and
    `true` respectively.
- [X] T009 [P] [US1] Add a spread golden for pages 49–50 at 890×582 to
  `test/widget/mushaf_page_renderer_golden_test.dart`, as `test/widget/goldens/spread_49_890.png`.
  Do not regenerate the existing 21 single-page goldens.
- [X] T010 [P] [US1] Extend `test/widget/wide_window_test.dart`. With a `ReaderScope` in the
  Mushaf layout and `twoPages` on, a 1440×800 window gives a column of `min(W, max(960, 1.15 × H))`.
  With `twoPages` off, or the flowing layout, the column stays 480. A 600×400 window keeps
  today's behaviour.

### Implementation for User Story 1

- [X] T011 [US1] In `lib/features/reader/mushaf_view.dart`, add a required `bindingOnRight`
  parameter to `_MushafPageItem` and pass it to both `PaperSheet`s, the loading one and the
  loaded one. The single-page path passes `page.isOdd`, so it is unchanged.
- [X] T012 [US1] In `lib/features/reader/mushaf_view.dart`, implement two-page mode (research R2).
  `_MushafViewState.build` reads `showsSpread(context)`:
  - When it is false, it returns today's `PageView` unchanged.
  - When it is true, it returns a `PageView.builder` with `key: const ValueKey(true)` (the
    single one gets `ValueKey(false)`), its own `PageController` created at
    `spreadIndex(reader.page)`, `itemCount: spreadCount` and `allowImplicitScrolling: true`.
  - Each spread item is a `Row` in RTL `Directionality` with
    `Expanded(_MushafPageItem(page: 2i + 1, bindingOnRight: false))` and
    `Expanded(_MushafPageItem(page: 2i + 2, bindingOnRight: true))`, keyed
    `ValueKey((_cache.printed, page))`.
  - Dispose the controller that is not in use when the mode switches.
- [X] T013 [US1] In `lib/features/reader/mushaf_view.dart`, make two-page mode's jump handling use
  the spread. The target is `spreadIndex(reader.page)`, and there is no jump when that spread is
  already on screen. Prefetch pages `2i - 1` to `2i + 4` on `onPageChanged` and after jumps, and
  call `widget.onPageTurned` as the single path does. Keep `_PageCache._capacity` at 7.
- [X] T014 [US1] In `lib/app/app.dart`, `PhoneColumn.build` uses
  `showsSpread(context) ? min(W, max(2 × phoneColumnWidth, 1.15 × H)) : phoneColumnWidth` as
  the column width (research R7). Below `wideWindowMin` it still returns the child as it is.
  Update the doc comment to mention specs/012. Make T010 pass.
- [X] T015 [US1] In `lib/app/app.dart`, add an Android-only orientation sync in the
  `MaterialApp` builder for non-web builds (research R6). When the shortest side of
  `MediaQuery.sizeOf` is under 600, call
  `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])`; otherwise call it with
  `[]`. Call the platform only when the answer changes, guard with
  `defaultTargetPlatform == TargetPlatform.android`, and do nothing on iOS or the web. Leave
  `android:screenOrientation="portrait"` in `android/app/src/main/AndroidManifest.xml`. Add a
  widget test in `test/widget/two_page_spread_test.dart` that records the `SystemChrome` calls on
  `SystemChannels.platform` for 412×870 and 750×790 under `debugDefaultTargetPlatformOverride = TargetPlatform.android`.

**Checkpoint**: US1 is complete. T008–T010 pass, and quickstart Q1, Q2 and Q11 pass.

---

## Phase 4: User Story 2 - Fold and unfold without losing the place (Priority: P1)

**Goal**: Folding or opening the phone, resizing a window, or switching the setting never
changes the reader's page.

**Independent Test**: Open at page 77, fold (resize to a phone size): page 77. Open again: 77–78.
Long-press on 78, close, fold: page 78.

### Tests for User Story 2

- [X] T016 [P] [US2] Write `test/unit/reader_spread_place_test.dart` for
  `ReaderController.onMushafSpreadShown`, covering the data-model.md rules:
  - "page ∈ {r, r+1} → no change";
  - "selected/highlighted ayah on r or r+1 → page = that ayah's page, anchor = that ayah";
  - "otherwise → page = r, anchor = first ayah on r".

  Also check that a save is scheduled, and that `notifyListeners` fires only on a change.
- [X] T017 [P] [US2] In `test/widget/two_page_spread_test.dart`, change `tester.view.physicalSize`
  between the folded and open sizes and check:
  - 77 → 77–78 → 77;
  - with an ayah on 78 selected, folding shows 78;
  - `reader.page` and the saved anchor are unchanged by the resize;
  - switching `twoPages` off and on keeps the page;
  - a resize during a drag leaves no half-turned page.

### Implementation for User Story 2

- [X] T018 [US2] Add `void onMushafSpreadShown(int rightPage)` to `ReaderController` in
  `lib/shared/reader_state.dart`, with the three rules of data-model.md › Reader's page. Schedule
  the save and notify only on a change. Call it from the two-page `onPageChanged` in
  `lib/features/reader/mushaf_view.dart`. Make T016 pass.
- [X] T019 [US2] Add the setting row to `lib/features/settings/settings_screen.dart`: a
  `SwitchListTile` titled `l10n.twoPagesSetting` with subtitle `l10n.twoPagesHint`, placed after
  the printed-lettering row. Its value is `prefs.twoPages`, and `onChanged` calls
  `set((p) => p.copyWith(twoPages: v))`. It shows only while `spreadFitsScreen(context)` is true
  (FR-017). Add widget tests in `test/widget/two_page_spread_test.dart`: the row is present at
  890×626, absent at 393×852, and turning it off shows one page at the same `reader.page`.

**Checkpoint**: US2 is complete. Quickstart Q3, Q9 and Q10 pass.

---

## Phase 5: User Story 3 - Everything that works on one page works on two (Priority: P1)

**Goal**: Actions, selection, recitation, memorization, mutashabihat, bookmarks, the header and
the keyboard work on both pages.

**Independent Test**: Long-press an ayah on the left page and its actions open. A recitation
crossing from the right page to the left page does not turn, and it turns after the left page.

### Tests for User Story 3

- [X] T020 [P] [US3] In `test/widget/two_page_spread_test.dart`, at 890×626:
  - a long-press on the left page opens the ayah actions for an ayah on that page, which shows
    as selected;
  - a tap on either page toggles the controls;
  - after `reader.jumpTo` to an ayah on the left page, the same spread stays on screen with no
    turn, `reader.page` is the left page, and the ayah is highlighted;
  - a `jumpTo` two pages ahead shows the next spread;
  - the header reads «صفحة ٤٩–٥٠» in Arabic and "Pages 49–50" in English;
  - with a bookmark on page 50 only, the toggle shows as filled, and tapping it removes it; with
    none, tapping adds one at `reader.page`;
  - semantics order: page 49's label comes before page 50's.
- [X] T021 [P] [US3] Extend `test/widget/recitation_highlight_test.dart`, using the fakes in
  `test/support/fake_recitation.dart`, at 890×626. A recitation that moves from the last ayah on
  page 49 to the first on page 50 does not change the `PageView` index and keeps following. When
  it moves on to page 51, the next spread shows.
- [X] T022 [P] [US3] Extend `test/widget/keyboard_test.dart` at 1440×800 with `twoPages` on.
  ArrowLeft from 49–50 shows 51–52, and ArrowRight shows 47–48. From 603–604 nothing happens,
  and from 1–2 nothing happens backwards.

### Implementation for User Story 3

- [X] T023 [US3] In `lib/features/reader/reader_screen.dart`, when `showsSpread(context)`,
  `_ReaderHeader` shows
  `l10n.pagesLabel(formatNumber(r, locale), formatNumber(r + 1, locale))`, with
  `r = PageGeometry.spreadRightPage(reader.page)`. Otherwise it shows today's `pageLabel`.
- [X] T024 [US3] In `lib/features/reader/reader_screen.dart`, when `showsSpread(context)`,
  `_BookmarkToggle` collects `bookmarksOnPage(r)` and `bookmarksOnPage(r + 1)`. It is filled if
  either is non-empty. Tapping removes all of them, or adds a bookmark at
  `reader.quran.firstAyahOnPage(reader.page)` for `reader.page`.
- [X] T025 [US3] In `lib/features/reader/reader_screen.dart`, `_withKeys.turn(delta)` in the
  Mushaf layout with `showsSpread(context)` jumps with
  `reader.jumpToPage((spreadRightPage(reader.page) + 2 × delta).clamp(1, 603))`. It returns
  without jumping when the target spread is the current one. Make T022 pass.
- [X] T026 [US3] Run T020 and T021. Fix any gap in `lib/features/reader/mushaf_view.dart`
  (per-page `_rendererKey`, `pick`, semantics) without changing the single-page path.
  Recitation, memorization and similar-ayat code should need no change (research R3). If one
  does, record why in `specs/012-foldable-two-page/research.md` R3.

**Checkpoint**: US3 is complete. Quickstart Q4 and Q5 pass.

---

## Phase 6: User Story 4 - Regular phones and the folded phone see no change (Priority: P1)

**Goal**: The single page is pixel-identical, and paging and memory are unchanged.

**Independent Test**: The full test suite, including the 21 single-page goldens, passes
unchanged, and the reference phones behave as before.

- [X] T027 [P] [US4] In `test/widget/two_page_spread_test.dart`, at 393×852, 375×667 and the
  folded Duo size 466×678:
  - one `MushafPageRenderer` shows and the `PageView` has 604 items;
  - no two-pages settings row shows;
  - `SystemChrome.setPreferredOrientations` is never called on iOS;
  - at 445×626 (the open Duo in Split View), one page shows.
- [X] T028 [US4] Run `flutter test` and confirm that `test/widget/reader_page_view_test.dart`,
  `test/widget/mushaf_typesetting_test.dart`, `test/widget/navigation_test.dart`,
  `test/widget/memorization_session_test.dart` and the single-page goldens in
  `test/widget/goldens/` pass with no golden or expectation changed.

**Checkpoint**: All stories are complete.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T029 [P] Update `specs/008-web-app/spec.md` FR-012 and `specs/008-web-app/research.md` R13
  with a note that the column widens for two pages since specs/012. Update the doc comment on
  `wideWindowMin` in `lib/app/app.dart`.
- [X] T030 [P] Note the Xcode 27 requirement for iOS builds in `docs/release.md`.
- [X] T031 Run `flutter analyze` with no new issues, then run the full `flutter test`.
- [ ] T032 Run the device checks Q1–Q12 in `specs/012-foldable-two-page/quickstart.md`:
  - the iPhone Duo simulator;
  - a Galaxy Z Fold emulator on Android 14 and 16;
  - iPhone SE (2nd gen) and Galaxy A15 for the performance comparison;
  - desktop Chrome.

  Record the Duo's measured reading area in research R1. Record frame timings and the store
  size change in the merge notes (constitution III and IV).

---

## Dependencies & Execution Order

- **Setup (T001–T002)**: T001 gates only the iOS device checks. Dart work can start alongside it.
- **Foundational (T003–T007)**: T006 needs T003's test file. T007 needs T004 and T006. This
  phase blocks every story.
- **US1 (T008–T015)**: T011 → T012 → T013. T014 needs T007. T015 is independent.
- **US2 (T016–T019)**: T018 needs T012. T019 needs T004, T005 and T007.
- **US3 (T020–T026)**: T023–T025 need T005 and T012. T026 comes last.
- **US4 (T027–T028)**: can be written any time after T012. It is run again at the end.
- **Polish (T029–T032)**: after all stories.

## Parallel Example

```text
# Foundational, together:
T003 spread_fits_test.dart   T004 preference + test   T005 strings

# US1 tests, together, before T011–T015:
T008 two_page_spread_test.dart   T009 spread golden   T010 wide_window_test.dart

# US3 tests, together:
T020 two_page_spread_test.dart   T021 recitation_highlight_test.dart   T022 keyboard_test.dart
```

Tasks that edit `lib/features/reader/mushaf_view.dart` (T011–T013, T018) or
`lib/features/reader/reader_screen.dart` (T023–T025) are sequential.

## Implementation Strategy

1. **MVP**: Setup, Foundational and US1. Two pages show on the open Duo, the Z Fold and wide
   browsers, and one page shows elsewhere.
2. **Add US2**: the place survives folding, and the setting.
3. **Add US3**: controls and sessions on both pages.
4. **US4 and Polish**: the regression run, docs and device checks, then merge.

Do not ship the MVP alone. US2 and US3 are P1, and the spec needs all four stories for release.
