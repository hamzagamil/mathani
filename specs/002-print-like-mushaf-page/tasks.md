---

description: "Task list for the print-like Mushaf page"
---

# Tasks: Print-Like Mushaf Page

**Input**: Design documents from `specs/002-print-like-mushaf-page/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Included. The spec's success criteria are automated checks over all 604 pages (SC-001
to SC-004, SC-008), and the plan lists the tests.

**Organization**: Tasks are grouped by user story. User Story 4 (replica pack) is **gated** by D3
(KFGQPC permission) and spikes S-1 and S-2. Its tasks after the gate must not start until
the gate tasks pass.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4)

## Path Conventions

Single Flutter project at the repository root: `lib/`, `test/`, `tool/`, `android/`, `ios/`.

## Shared conventions

- Tests that need the real Quran data use `openTestReader()` and `loadAppFonts()` from
  `test/support/harness.dart` inside `testWidgets`, wrapping database work in
  `tester.runAsync(...)`.
- Kashida exists only in display strings. Never modify `Word.text` (spec FR-005).
- Numbers from the research and contracts are constants with names, in one place each:
  text-block ratio `1.77`, band height `0.6 × lineHeight`, page-detail text `0.32 × lineHeight`,
  gap limits `0.5`–`1.5 × space`, minimum line scale `0.95`, at most `2` tatweels per join point.

---

## Phase 1: Setup

- [X] T001 Run `flutter analyze` and `flutter test` from the repository root and confirm both pass on `main` before any change (baseline). Record the current Quran font size at 320, 375, 390 and 430 pt reader widths: content width `(width − 16) × (1 − 2 × 0.045)` divided by `meta.p98_line_width_em`. Note them at the top of `test/widget/mushaf_typesetting_test.dart` (created in T005) as the FR-012 baseline constants.

---

## Phase 2: Foundational

**Purpose**: the target line width every story's layout depends on.

- [X] T002 Extend `tool/measure_line_widths_test.dart` to also compute and write `meta.justify_target_em`: for each `ayah` line, `(natural − gaps × space × 0.4) × 0.95`, where `natural = Σ word widths + gaps × space`. Take the maximum over all lines, in em at the probe size, and write it with `INSERT OR REPLACE INTO meta VALUES ('justify_target_em', ?)` to 4 decimals (research P2: expected about 22.27 for Amiri Quran). Run `flutter test tool/measure_line_widths_test.dart` to regenerate `assets/db/quran.db` and `assets/db/quran.version`.
- [X] T003 In `lib/data/quran_repository.dart`, read `meta.justify_target_em` into a new `final double justifyTargetEm` (fallback: `p98LineWidthEm × 1.034` if absent), next to `p98LineWidthEm`, and also read `meta.space_width_em` into `spaceWidthEm` if not already exposed.

**Checkpoint**: `quran.db` carries the target width; stories can start.

---

## Phase 3: User Story 1 - Read lines that look like the printed Mushaf (Priority: P1) 🎯 MVP

**Goal**: every justified line is full width with normal word spacing, filled by kashida in the
display text (spec FR-001 to FR-007; [page-typesetting](./contracts/page-typesetting.md)).

**Independent Test**: open pages 3, 50, 300 and 604 with no pack. Every full line spans the text
width, and no word gap looks wider than a normal space. Copying an ayah gives text with no
tatweel.

### Tests for User Story 1

> Write these first and confirm they fail.

- [X] T004 [P] [US1] Create `test/unit/kashida_test.dart` (pure `test`, no fonts) for `joinPoints(String word)` and `justifyLine(...)` from `lib/features/reader/kashida.dart`.
  - `joinPoints`:
    - «بِسْمِ» has a point after «س» with priority 0.
    - «ٱلْكِتَـٰبُ» has no point next to its existing tatweel.
    - «لَا» and «قَالَ» have no point between «ل» and the alef form.
    - «ٱللَّهِ», «لِلَّهِ» and «وَٱللَّهُ» have no points.
    - «مَا» and «بِهِ» (2 letters) have no points.
    - Points sit after a letter's combining marks, never between a letter and its mark.
  - `justifyLine`, with synthetic widths:
    - A centred line gets gap 1 × space, no tatweels and scale 1.
    - A one-word line is centred.
    - A short line gets tatweels round-robin across words, never more than 2 per point, and its gap ends between 0.5 and 1.5 × space.
    - A line wider than the target first tightens gaps to 0.5 × space, then scales, never below 0.95.
    - A line whose join points run out keeps a gap above 1.5 × space and reports it with `overGap: true`.
    - Results are deterministic: same input, same output.
- [X] T005 [P] [US1] Create `test/widget/mushaf_typesetting_test.dart`, which lays out all 604 pages with `MushafPageRenderer` at widths 320, 375, 390 and 430 pt and a page height of 700 pt. For every `ayah` line that is not centred, assert:
  - the drawn width is within 1% of the text-block width (SC-001);
  - the line scale is ≥ 0.95 (FR-004);
  - the word gap is ≤ 1.5 × space unless the line is flagged `overGap`.

  Count the `overGap` lines and assert the count is ≤ a constant `maxOverGapLines`, set from the first passing run and commented (research P2, risk R-2). Expose what the test needs through `@visibleForTesting` getters on `RenderMushafPage`: `lineReports` returning per-line `(width, targetWidth, gap, space, scale, overGap, centered)`.
- [X] T006 [P] [US1] In `test/widget/mushaf_typesetting_test.dart`, add a test that for pages 3, 50 and 300 the text used for copy and semantics is unchanged. `reader.quran.wordsOf(ref)` text contains no tatweel that the source doesn't, and the ayah action sheet's copy text (via `lib/features/reader/ayah_actions.dart`'s share or copy formatter) equals the source (FR-005).

### Implementation for User Story 1

- [X] T007 [US1] Create `lib/features/reader/kashida.dart` with:
  - `class JoinPoint { final int offset; final int priority; }`: offset is the index in the word string after which a tatweel goes, after the letter's combining marks. Priority is 0 after «س ش ص ض», 1 before the last letter, 2 otherwise.
  - `List<JoinPoint> joinPoints(String word)`, following the rules in the contract's "Join points" section exactly. Combining marks are U+0610–061A, U+064B–065F, U+0670 and U+06D6–06ED. Dual-joining letters are «بتثجحخسشصضطظعغفقكلمنهيئى». Right-joining letters are «اأإآٱدذرزوؤة». Exclusions:
    - lam followed by «ا أ إ آ ٱ»;
    - any word containing «لله» once marks are removed;
    - points next to U+0640;
    - words with ≤ 2 letters;
    - ayah-end markers (the caller passes none).
  - `LineJustification justifyLine({required List<double> wordWidths, required double space, required double tatweel, required List<List<JoinPoint>> points, required double target, required bool centered})`, implementing the contract's "Line justification" steps 1–6. It returns per-word `Map<int, int>` tatweel counts keyed by point offset, plus `gap`, `scale`, `width` and `overGap`.
  - `String withKashida(String word, Map<int, int> counts)`, which inserts U+0640 × count at each offset.
- [X] T008 [US1] In `lib/features/reader/mushaf_page_renderer.dart`, use `kashida.dart` in `performLayout`:
  - **Font size:** set it from `justifyTargetEm` instead of `lineWidthEm` (rename the widget field to `targetEm`, and update `lib/features/reader/mushaf_view.dart` to pass `quran.justifyTargetEm`).
  - **Measuring:** measure each word's natural width (painter cache keyed by word id). Get `joinPoints` for non-ayah-end words, cached per word id, and the tatweel width as `width('بـب') − width('بب')` (research P2).
  - **Painting:** call `justifyLine` per `ayah` line, then build painters for stretched words from `withKashida(word.text, counts)`, cached by display string. Place words right-to-left with the returned gap and scale.
  - **Unchanged:** ayah-end markers, centred lines, surah headers, basmala and margin marks keep today's drawing.
  - **Test getters:** replace `minLineScale` and `allLinesFit` with the `lineReports` getter from T005, keeping `allLinesFit` for the existing golden test.
- [X] T009 [US1] Update `test/widget/mushaf_page_renderer_golden_test.dart`: pass `targetEm: reader.quran.justifyTargetEm`, change the minimum scale expectation from 0.8 to 0.95, and add pages 3, 50 and 300 to the golden list. Regenerate with `flutter test --tags golden --update-goldens test/widget/mushaf_page_renderer_golden_test.dart`, and open the new PNGs in `test/widget/goldens/` to review them by eye against the reference screenshot (research P2) before accepting.
- [X] T010 [US1] Run `flutter test test/unit/kashida_test.dart test/widget/mushaf_typesetting_test.dart test/widget/mushaf_page_renderer_golden_test.dart`. All pass; record `maxOverGapLines` in T005's test with a comment giving the date and count.

**Checkpoint**: lines are filled by kashida with normal gaps. Spacing is fixed at today's page size.

---

## Phase 4: User Story 2 - The same page on every screen size (Priority: P2)

**Goal**: a fixed-ratio text block, centred, with spare space as margins (FR-008, FR-012;
[page-typesetting](./contracts/page-typesetting.md) › Page geometry).

**Independent Test**: page 3 at 320, 375, 390 and 430 pt widths and heights of 560, 700 and 900
pt. The block ratio is 1.77 ± 2%, opposite margins are equal within 2 pt, and the Quran font is ≥
the T001 baseline.

### Tests for User Story 2

- [X] T011 [P] [US2] In `test/widget/mushaf_typesetting_test.dart`, add a geometry test for page 3 over widths {320, 375, 390, 430} × heights {560, 700, 900}. Read `RenderMushafPage.geometry` (`@visibleForTesting`) and assert:
  - `textBlock.height / textBlock.width` is within 1.77 ± 2%;
  - left and right margins are equal within 2 pt, and top and bottom margins too;
  - `lineHeight == textBlock.height / 15`;
  - `fontSize ≥` the T001 baseline for that width. The baseline is at the reader's full width, since T013 removes the 8 pt padding.

  Add one tall case (390 × 900) asserting the line height does not grow beyond `1.77 × width / 15`.

### Implementation for User Story 2

- [X] T012 [US2] Create `lib/features/reader/page_geometry.dart` with `class PageGeometry`, built by `PageGeometry.of(Size sheet, double targetEm)` and cached per size, with these fields:

  | Field | Rule |
  | --- | --- |
  | `textBlock` | `height ÷ width = 1.77`; centred; as large as fits |
  | `fontSize` | `textBlock.width ÷ targetEm` |
  | `lineHeight` | `textBlock.height ÷ 15` |
  | `headerBand`, `footerBand` | page details above and below the block; 0.6 × lineHeight each, inside the sheet; text at 0.32 × lineHeight |
  | `markerMargin` | outside the block on the right, within the sheet |

  Sizing: the block fits inside the sheet minus a marker margin of 4.5% of the sheet width on each side, minus the two bands. If the width allows a taller block than the height does, the block is height-bound and its width follows. Delete `lib/features/reader/mushaf_layout_metrics.dart` and replace its uses in `lib/features/reader/mushaf_page_renderer.dart` (`metrics.sideMargin` → block and marker margin; `metrics.lineHeight` → `geometry.lineHeight`; line tops = `textBlock.top + i × lineHeight`). Pages with fewer than 15 slots are centred vertically in the block.
- [X] T013 [US2] In `lib/features/reader/reader_screen.dart`, remove the horizontal `Padding(Space.s2)` around `MushafView` only (keep it for `FlowingView`). Then run T011 and the US1 tests: all pass at the baseline font size or larger.

**Checkpoint**: same page, same proportions on every screen. US1 and US2 can ship together as a
release.

---

## Phase 5: User Story 3 - A full-screen paper page (Priority: P3)

**Goal**: the page fills the screen; surah, juz and page number are drawn on the page; controls
appear on tap; the sheet has a page edge and texture (FR-009 to FR-013;
[reader-page-view](./contracts/reader-page-view.md)).

**Independent Test**: open the reader. Controls show; a page turn hides them, and the hint shows
once; tap shows them and tap hides them; long-press opens the ayah sheet. Surah and juz sit at
the top of the page and the page number at the bottom, in day and night.

### Tests for User Story 3

- [X] T014 [P] [US3] Create `test/widget/reader_page_view_test.dart` covering the contract's transition table:
  - opening in Mushaf layout shows the header and toolbar;
  - a page turn (`tester.fling` on the `PageView`) hides them;
  - the first hide shows the snackbar «اضغط على الصفحة لإظهار الأدوات» once and stores `controls_hint_shown = true`; a second hide shows no snackbar;
  - tapping the page shows the controls within one frame plus 200 ms of animation, and tapping again hides them;
  - with an ayah selected, a tap clears the selection and leaves the controls as they were;
  - long-press opens the ayah action sheet;
  - with `MediaQuery(data: MediaQueryData(accessibleNavigation: true))`, the controls stay visible after a page turn;
  - switching to the flowing layout shows today's bars.

  Record `SystemChrome.setEnabledSystemUIMode` calls through `TestDefaultBinaryMessengerBinding` on `SystemChannels.platform` and assert immersive on hide and restored on show and leave.
- [X] T015 [P] [US3] In `test/widget/mushaf_typesetting_test.dart`, add page-details checks via a `@visibleForTesting` `pageDetails` getter on `RenderMushafPage`:
  - page 3 header shows «سورة البقرة» (right) and «الجزء ١» (left), and the footer «٣», all inside the header and footer bands;
  - page 1 shows «سورة الفاتحة», «الجزء ١» and «١»;
  - the English interface still shows the Arabic details (Mushaf-area rule).
- [X] T016 [P] [US3] Create `test/unit/paper_sheet_test.dart`: the generated noise tile is 128 × 128, deterministic for the fixed seed, and its alpha at 3% keeps the Quran `ink` against the darkest textured `surface` at a contrast ratio ≥ 4.5:1, in day and night colours from `MathaniColors.forBrightness`.

### Implementation for User Story 3

- [X] T017 [P] [US3] Add strings to `lib/app/l10n/app_ar.arb` and `lib/app/l10n/app_en.arb`, then run `flutter gen-l10n`:
  - `controlsHint`: «اضغط على الصفحة لإظهار الأدوات» / "Tap the page to show controls";
  - `showControls`: «إظهار الأدوات» / "Show controls" (semantic action);
  - `juzOnPage`: «الجزء {n}» (Arabic only, used inside the Mushaf area in both languages; add the same Arabic text to the English file with a description saying it is intentionally Arabic).
- [X] T018 [P] [US3] In `lib/data/models.dart`, add `controlsHintShown` (bool, default `false`) to `ReaderPreferences` with `copyWith`. In `lib/data/user_repository.dart`, parse and save the key `controls_hint_shown`, `true` / `false` like `keep_screen_on`, default `false`.
- [X] T019 [P] [US3] Create `lib/features/reader/paper_sheet.dart`: `PaperSheet` (a widget painting behind the page) draws:
  - the `surface` colour;
  - a 128 × 128 noise tile generated once per process with `math.Random(1421)` into a `ui.Image` (per-pixel ink alpha 0–255 scaled to an overall 3%), drawn with `ImageShader` repeat;
  - a 12 pt horizontal gradient from ink at 6% to transparent on the binding side: the right edge for odd pages and the left for even pages.

  Night uses the night `surface` and `ink`. It exposes `static Future<ui.Image> noiseTile()` for T016.
- [X] T020 [US3] In `lib/features/reader/mushaf_page_renderer.dart`, paint the page details using `PageGeometry.headerBand` and `footerBand`, in the Quran font at `0.32 × lineHeight` and `accentInk`:
  - header: «سورة {name}» right-aligned to the text block's right edge, and `juzOnPage` with Eastern Arabic digits left-aligned to its left edge;
  - footer: the page number in Eastern Arabic digits, centred.

  The surah and juz are those of `quran.firstAyahOnPage(page)`, passed in by `lib/features/reader/mushaf_view.dart` as new renderer fields `headerSurah` and `juz`. Expose `pageDetails` for T015.
- [X] T021 [US3] In `lib/features/reader/mushaf_view.dart`, wrap each page in `PaperSheet` (T019). Add callbacks `onTapPage` and `onPageTurned` to `MushafView`:
  - a tap with no selection calls `onTapPage`, and with a selection clears it as today;
  - `onPageChanged` calls `onPageTurned`.

  Add a `Semantics(customSemanticsActions: {CustomSemanticsAction(label: l10n.showControls): onTapPage})` on the page.
- [X] T022 [US3] In `lib/features/reader/reader_screen.dart`, for `ReadingLayout.mushaf` only:
  - **Layout:** replace `appBar` and `bottomNavigationBar` with a `Stack`: the page body full screen within safe areas, plus `_ReaderHeader` and `_ReaderToolbar` in `AnimatedSlide` + `AnimatedOpacity` (200 ms), driven by a `bool _controlsVisible` that starts `true`.
  - **Toggling:** `onTapPage` toggles it; `onPageTurned` sets it to `false`.
  - **System bars:** when the controls hide, call `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`; when they show, `SystemUiMode.edgeToEdge`.
  - **Restore:** restore `edgeToEdge` in `dispose` and when switching to flowing.
  - **Screen readers:** if `MediaQuery.of(context).accessibleNavigation` is true, keep the controls visible and the system bars shown.
  - **Hint:** on the first hide with `controlsHintShown == false`, show a 4 s `SnackBar(content: Text(l10n.controlsHint))` and save `controlsHintShown: true` via `reader.updatePreferences`.
  - **Flowing layout:** keeps today's `Scaffold` with app bar and toolbar.
- [X] T023 [US3] Run `flutter test test/widget/reader_page_view_test.dart test/widget/mushaf_typesetting_test.dart test/unit/paper_sheet_test.dart` and the existing `test/widget/navigation_test.dart`, `bookmarks_test.dart` and `comfort_test.dart`, then fix any test that relied on the always-visible toolbar. Prefer tapping the page to show controls in those tests over changing app behaviour. Regenerate and review the page goldens (now with page details and sheet) as in T009, in day and night.

**Checkpoint**: the full print-like experience with built-in lettering. Shippable.

---

## Phase 6: User Story 4 - Download an exact replica of the printed Mushaf (Priority: P4) ⛔ Gated

**Goal**: an optional pack that draws every page in the printed lettering (FR-014 to FR-021;
[replica-pack](./contracts/replica-pack.md)).

**Independent Test**: on a fresh install, download the pack on Wi-Fi, then go offline. Pages 1, 3,
300 and 604 show the printed lettering with the same line breaks. Delete the pack: the built-in
lettering returns and the storage is freed.

### Gate: must pass before T027 onwards

- [X] T024 [US4] **Spike S-1, layout match.** Obtain QUL's 15-line layout databases for the KFGQPC V2 (1421) and V4 editions, along with their per-word glyph-code scripts, into `tool/sources/` (gitignored). Write `tool/compare_layouts.dart`, a pure Dart `sqlite3` script that compares each candidate's `(page, line)` for every word id against `assets/db/quran.db` `mushaf_lines`. Report per edition the number of words on a different page or line. Write the result into `specs/002-print-like-mushaf-page/research.md` § P6. **Pass** = an edition with 0 differences whose lettering has no tajweed colours. Otherwise stop and ask the owner to choose (research P6 decision 1).
- [X] T025 [US4] **Spike S-2, font format and memory.** On one Android device or emulator (API 24+) and one iOS device or simulator (iOS 15+), in a debug-only screen behind `kDebugMode` in `lib/features/settings/settings_screen.dart`:
  - load page 3's font from WOFF2 bytes and from TTF bytes with `FontLoader`;
  - render the page's glyph strings and compare widths;
  - then load 100 page fonts and record the process memory growth.

  Write the results into `research.md` § P6. **Pass** = both formats are known for both platforms and the memory growth is recorded. Choose `format` = `woff2` if it loads on both, else `ttf.gz`. Remove the debug screen after the spike.
- [X] T026 [US4] **Gate D3/D4.** Confirm in `docs/licences.md` that KFGQPC permission to redistribute the page lettering has been received, and record the chosen host URL for `REPLICA_PACK_URL`. If not received, stop here: Phase 6 stays open and Phases 3–5 ship without it.

### Tests for User Story 4 (after the gate)

- [X] T027 [P] [US4] **Withdrawn 2026-10-23 (bundled, no download or network).** Create `test/unit/replica_pack_test.dart` using a fake HTTP server (`HttpServer.bind` on loopback serving a 3-page fixture pack from `test/fixtures/replica/`) and a temp directory. Cover the [data-model](./data-model.md) state machine:
  - `notInstalled` → `downloading` → `verifying` → `installed`;
  - a stop mid-download leaves `paused` with finished files kept and `.part` deleted on resume;
  - a corrupted file (wrong CRC32) leads to `damaged`, and repair re-downloads only that file;
  - free space below `totalBytes × 1.1` refuses to start;
  - a manifest whose `layout_sha256` differs from `quran.db` `source_qul_layout_sha256` is refused;
  - delete removes `replica/` and reports the bytes freed.
- [X] T028 [P] [US4] Create `test/widget/replica_settings_test.dart`:
  - the Settings "Printed Mushaf" section shows the size before download, asks to confirm on mobile data (inject a connectivity flag), shows progress, offers use or delete when installed, and offers repair when damaged;
  - switching lettering keeps `reader.anchor`.

### Implementation for User Story 4 (after the gate)

- [X] T029 [US4] Create `tool/build_replica_pack.dart` per the contract's "Build tool" section:
  - check that every word id in `quran.db` has a glyph and that its page and line match (100% or exit non-zero);
  - write `glyphs.json`, copy the page fonts in the format chosen in T025, and write `manifest.json` with `version`, `edition`, `format`, `layout_sha256` (= `source_qul_layout_sha256`), `totalBytes` and `files[]` (`name`, `bytes`, `crc32`), plus `latest.json`;
  - write output to `build/replica/<version>/`.
- [X] T030 [P] [US4] In `lib/data/models.dart`, add `enum Lettering { builtin, replica }` and `ReaderPreferences.lettering` (default `builtin`). In `lib/data/user_repository.dart`, parse and save the key `lettering` (`builtin` / `replica`). `replica` takes effect only while the pack is `installed`. Otherwise use `builtin` and leave the stored value alone.
- [X] T031 [US4] **Withdrawn 2026-10-23 (bundled, no download or network).** Create `lib/features/settings/replica_pack.dart`: `ReplicaPack` (a `ChangeNotifier`) with states `notInstalled`, `downloading`, `paused`, `verifying`, `installed`, `damaged` and `updateAvailable`, derived from disk at startup.
  - Paths: `getApplicationSupportDirectory()`/`replica/<version>/`; `path_provider` is already a transitive dependency, so confirm it in `pubspec.lock` and add it as a direct dependency only if missing, with a note in the plan.
  - Download: `HttpClient` from `REPLICA_PACK_URL` (`String.fromEnvironment`), one file at a time to `.part`, then rename. It runs only while the app is in the foreground and stops on `AppLifecycleState.paused`.
  - Verification: sizes and CRC32 (a small table-based CRC32 in the same file) against the manifest.
  - Repair, delete and free-space check (`totalBytes × 1.1`).
  - No request is made unless the user starts download, update or repair (FR-020).
- [X] T032 [US4] Create `lib/features/reader/replica_lettering.dart`:
  - load `glyphs.json` once;
  - load page *n*'s font with `FontLoader('qcf_p${n.toString().padLeft(3, '0')}')` the first time page *n* is shown, prefetching n ± 2. For `ttf.gz`, inflate with `GZipCodec().decode`;
  - expose `glyphFor(wordId)` and `familyFor(page)`.

  In `lib/features/reader/mushaf_page_renderer.dart`, when the lettering is `replica` and the page font is loaded, paint each word's glyph string in that family at the same word placements, scaled so the line fills the block, with no kashida. Until the font is loaded, draw the built-in lettering. Hit testing and highlights use the same word rectangles (FR-021).
- [X] T033 [US4] In `lib/features/settings/settings_screen.dart`, add the "Printed Mushaf" section per the contract's "App behaviour" table, with strings added to both `.arb` files: size, download, progress, pause or resume, use built-in or printed lettering, delete with the bytes freed, repair, and the mobile-data confirmation dialog.
- [X] T034 [US4] **Withdrawn 2026-10-23 (bundled, no download or network).** Add `<uses-permission android:name="android.permission.INTERNET"/>` to `android/app/src/main/AndroidManifest.xml`. Update the store privacy notes in `docs/` (Data safety and App Privacy: still "no data collected"; the network is used only to download optional files on request) and the attribution for the page lettering in the About section (`lib/features/settings/about_section.dart`), per the D3 permission terms.
- [X] T035 [US4] Run `flutter test test/unit/replica_pack_test.dart test/widget/replica_settings_test.dart`, then the replica scenarios in [quickstart.md](./quickstart.md) § Replica pack on one Android and one iOS device.

**Checkpoint**: the optional exact replica works offline and can be removed.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T036 [P] Update `specs/001-quran-mushaf-reader/contracts/ui-screens.md`'s Reader row to point to [reader-page-view](./contracts/reader-page-view.md) for the Mushaf layout, and add a note in `specs/001-quran-mushaf-reader/research.md` R4 that justification and font sizing are superseded by [page-typesetting](./contracts/page-typesetting.md).
- [ ] T037 Measure page layout time: add a `Stopwatch` around `performLayout` in a profile-mode integration run (`integration_test/`, existing perf harness) over pages 1–50 on the reference Android phone. Assert ≤ 8 ms per page and 60 fps paging; record the numbers in `plan.md` Risks.
- [X] T038 Run `dart run tool/size_check.dart` (or `flutter build appbundle --analyze-size` and `flutter build ipa --analyze-size` in CI) and confirm growth ≤ 0.5 MB against `main` (SC-007).
- [X] T039 Run `flutter analyze` and the full `flutter test`; fix any failure introduced by this feature.
- [ ] T040 Run the manual scenarios 1–6 in [quickstart.md](./quickstart.md) on one Android and one iOS device, in Arabic and English, day and night, and in a side-by-side review of 10 pages against the printed Mushaf (SC-005).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** → **Foundational (Phase 2)** → user stories.
- **US1 (Phase 3)**: after Phase 2.
- **US2 (Phase 4)**: after US1 (T012 changes the same renderer that T008 changes).
- **US3 (Phase 5)**: after US2 (it draws in the bands that `PageGeometry` reserves).
- **US4 (Phase 6)**: gate tasks T024–T026 can run any time after Phase 2. T027 onwards needs all
  three gates passed and US1–US3 done.
- **Polish (Phase 7)**: after the stories being shipped.

### Within Each Story

- Tests first, and confirm they fail.
- `kashida.dart` (T007) before the renderer (T008); `page_geometry.dart` (T012) before T013.
- Strings, preferences and sheet (T017–T019) before the renderer and screen changes (T020–T022).

### Parallel Opportunities

- US1: T004, T005 and T006 (different test files or groups).
- US3: T014, T015 and T016; then T017, T018 and T019.
- US4: T027 and T028; T030 alongside T029.
- Gate spikes T024 and T025 alongside Phases 3–5.
- Polish: T036 alongside T037 and T038.

---

## Parallel Example: User Story 3

```bash
Task: "Reader page view tests in test/widget/reader_page_view_test.dart"        # T014
Task: "Page details checks in test/widget/mushaf_typesetting_test.dart"         # T015
Task: "Paper sheet contrast test in test/unit/paper_sheet_test.dart"            # T016
# then
Task: "Hint and juz strings in lib/app/l10n/*.arb"                              # T017
Task: "controls_hint_shown preference in lib/data/*.dart"                       # T018
Task: "PaperSheet in lib/features/reader/paper_sheet.dart"                      # T019
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. T001–T003: baseline and target width.
2. T004–T010: kashida justification with tests and reviewed goldens.
3. **Stop and validate**: quickstart scenarios 1 and 2. The worst defect (wide gaps) is gone.

### Incremental Delivery

1. US1 + US2 → release 1: print-like lines at print proportions (T013 keeps the font size ≥
   today's).
2. US3 → release 2: the full-screen paper page.
3. Gate spikes in parallel; US4 → release 3 once D3, S-1 and S-2 pass.
4. Polish with each release.

---

## Notes

- 40 tasks: Setup 1, Foundational 2, US1 7, US2 3, US3 10, US4 12 (3 gates), Polish 5.
- No new packages for US1–US3. US4 may promote `path_provider` to a direct dependency (T031).
- Commit after each checkpoint.

## Implementation notes (2026-10-22)

- **T008 tuning**: a tatweel adds about 0.8 of its measured width, so the renderer re-justifies
  with the width really added; the cap is **4 per join point, best point first** (research P2,
  revised). 86 of 8,791 lines keep gaps over 1.5 × space; `maxOverGapLines` holds that count.
- **T011**: the "never smaller than before" check uses each reference phone's full-screen size
  (320 × 548, 375 × 647, 390 × 763, 430 × 839). The 560 pt height was today's body between bars
  and does not apply to the full-screen page. Proportions are still checked at 560/700/900.
- **T017**: no `juzOnPage` string. The page details are drawn in Arabic in the renderer, like the
  surah headers, because the Mushaf area is always Arabic.
- **T022**: showing the controls dismisses the one-time hint, which would otherwise sit over the
  toolbar.
- **T023**: reader tests and integration tests use a `tapToolbar` helper that taps the page first
  when the controls are hidden (`test/support/harness.dart`, `integration_test/toolbar.dart`).
- **T038**: Android bundle (as CI measures it) 10.34 MB vs baseline 10.32 MB. iOS is measured in CI.
- **Open**: T024–T035 (User Story 4, gated by D3, S-1 and S-2) and T037, T040 (need a phone).

## Printed lettering, bundled (2026-10-23)

Owner decision: bundle the King Fahd Complex page fonts in the app instead of a download, and drop
the host. What was built for User Story 4:

- **T024 (S-1)**: `tool/compare_layouts.dart` compared all 83,668 words with the V2 (1421 AH)
  edition through the Quran.com API: 0 on another page, 3,585 on another line (377 pages), and 36
  pages with a surah title at the foot of the previous page. The printed lettering therefore uses
  the V2 edition's own lines (spec FR-017 revised). Printed words spanning two of ours («بَعْدَ مَا»)
  are aligned by letters; 574 ayah-end markers the source put on a neighbouring line follow their
  word.
- **T025 (S-2)**: the Flutter engine does not load WOFF2 (glyphs fell back to boxes), so fonts ship
  as gzip-compressed TTF and are inflated with `dart:io`. Memory over a long session is still to be
  measured on a phone (with T037).
- **T026**: D3 recorded as granted by the owner in `docs/licences.md`; host dropped.
- **T029**: `tool/build_replica_lettering_test.dart` writes `assets/qcf/p001…p604.ttf.gz`
  (128.4 MB), the `replica_lines` and `replica_glyphs` tables, and `meta.replica_target_em`
  (17.51) and `replica_space_em`. All page fonts are registered before measuring.
- **T030, T033**: `Lettering { printed, builtin }`, default printed; Settings switch "Printed Mushaf
  lettering".
- **T032**: `PrintedFonts` loads a page font on first view (n ± 2 prefetched); the renderer draws
  glyphs at the printed edition's lines with no kashida. Hit-testing allows 0.2 em of slack, since
  printed lines have almost no word gaps.
- **T028, T035**: `test/widget/printed_lettering_test.dart` checks all 604 pages (same words, every
  word has a glyph, full lines, widest gap 0.69 em, 81 centred lines) and the settings switch.
