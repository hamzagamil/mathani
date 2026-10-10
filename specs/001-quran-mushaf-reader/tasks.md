---

description: "Task list for the Quran Mushaf Reader (Mathani first release)"
---

# Tasks: Quran Mushaf Reader (Uthmani Script)

**Input**: Design documents from `specs/001-quran-mushaf-reader/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: The spec does not request TDD, so there are no per-story test-first tasks. The
verification gates required by the plan and constitution are included: text integrity (SC-003),
performance and size (constitution III and IV), and golden layout tests (risk R-a).

**Organization**: Tasks are grouped by user story so each story can be built and checked on its
own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on unfinished tasks)
- **[Story]**: the user story the task belongs to (US1–US6)
- Paths are relative to the repository root (a single Flutter project, see plan.md › Project
  Structure).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the Flutter project, configure the platforms, and add fonts and licences.

- [X] T001 Install the latest stable Flutter SDK, then create the project at the repository root
  with `flutter create --org app.mathani --project-name mathani --platforms android,ios .`. This
  generates `pubspec.yaml`, `lib/main.dart`, `android/` and `ios/`. Install Android SDK API 36 and
  confirm with `flutter doctor`. JDK 17 is already installed. Confirm the bundle ID
  `app.mathani.mathani` with the owner before the first store upload, because it cannot change
  afterwards.
- [X] T002 Edit `pubspec.yaml`:
  - pin `environment: sdk` and `flutter` to the installed stable version;
  - add runtime dependencies `sqflite`, `wakelock_plus`, `share_plus`, `url_launcher`,
    `flutter_localizations` (sdk) and `intl`. These are the only runtime packages allowed
    (research R8);
  - add dev dependencies: `flutter_lints`, `integration_test` (sdk), `sqlite3` and `xml` (for the
    `tool/` scripts), `crypto` (SHA-256), and `sqflite_common_ffi` (sqflite inside `flutter test`);
  - set `flutter: generate: true`;
  - declare assets `assets/db/` and `assets/images/`;
  - remove the default `cupertino_icons` dependency.
- [X] T003 [P] Create `analysis_options.yaml` that includes `package:flutter_lints/flutter.yaml`,
  with `prefer_const_constructors`, `prefer_final_locals` and `avoid_print` enabled.
- [X] T004 [P] Create `l10n.yaml` with:
  - `arb-dir: lib/app/l10n`, `template-arb-file: app_en.arb`;
  - `output-localization-file: app_localizations.dart`, `output-class: AppLocalizations`;
  - `nullable-getter: false`.

  Then create empty `lib/app/l10n/app_en.arb` and `lib/app/l10n/app_ar.arb` that each hold only
  `appName` ("Mathani" / "مثاني").
- [X] T005 [P] Configure Android:
  - in `android/app/build.gradle.kts`: `minSdk = 24`, `targetSdk = 36`, and for release
    `isMinifyEnabled = true` and `isShrinkResources = true`;
  - in `android/app/src/main/AndroidManifest.xml`: `android:screenOrientation="portrait"` on
    MainActivity, `android:label="@string/app_name"`, and `android:supportsRtl="true"`;
  - add `android/app/src/main/res/values/strings.xml` (app_name "Mathani") and
    `android/app/src/main/res/values-ar/strings.xml` (app_name "مثاني");
  - add no permissions; add a `<queries>` entry for `https` VIEW intents so `url_launcher` can
    open links on Android 11+.
- [X] T006 [P] Configure iOS:
  - set the deployment target to 15.0 in `ios/Podfile` (`platform :ios, '15.0'`) and in
    `ios/Runner.xcodeproj/project.pbxproj`;
  - in `ios/Runner/Info.plist`: portrait-only `UISupportedInterfaceOrientations`,
    `CFBundleLocalizations` = `ar` and `en`, and `CFBundleDisplayName` taken from localised
    `ios/Runner/ar.lproj/InfoPlist.strings` ("مثاني") and
    `ios/Runner/en.lproj/InfoPlist.strings` ("Mathani").
- [X] T007 [P] Download IBM Plex Sans Arabic Regular, Medium, SemiBold and Bold (SIL OFL) and
  Amiri Quran (SIL OFL) into `assets/fonts/`, and declare them in `pubspec.yaml`:
  - family `PlexArabic` with weights 400/500/600/700;
  - family `QuranText` pointing to `assets/fonts/AmiriQuran-Regular.ttf`. The KFGQPC Hafs font
    replaces this file only once permission D1 is granted (research R3).
- [X] T008 [P] Create `docs/licences.md` listing each source and asset with its licence and the
  attribution it requires:
  - Tanzil: CC BY 3.0, verbatim only, credit "Tanzil Project", link to https://tanzil.net;
  - QUL layout and word data: terms unconfirmed, dependency D2;
  - KFGQPC Uthmanic Script HAFS: proprietary, written approval needed, dependency D1;
  - IBM Plex Sans Arabic and Amiri Quran: SIL OFL;
  - Lucide icons: ISC.

  Add a "Permissions" table for D1 and D2 with status `requested / granted / refused` and the
  date.
- [ ] T009 [P] Create a **private** GitHub repository for the project and push `main`. Then
  create `.github/workflows/ci.yml` with four jobs:
  - (a) `ubuntu-latest`: `flutter analyze`, `flutter test` and `dart run tool/verify_quran.dart`;
  - (b) `macos-latest`: `flutter build ios --release --no-codesign`, so iOS builds even though the
    developer machine is Windows (risk R-b);
  - (c) `macos-latest`: boot an iOS simulator (iPhone SE 3rd gen) and run
    `flutter test integration_test`;
  - (d) `ubuntu-latest`: run the same `integration_test` suite on an Android emulator.

  Jobs (c) and (d) are the constitution's "verified on one iOS and one Android device before
  merge" gate (emulated devices allowed). Pin the Flutter version to the one in `pubspec.yaml`.
- [ ] T010 Configure release signing and a single version source:
  - **Android**: `android/key.properties` (gitignored) is read by `signingConfigs.release` in
    `android/app/build.gradle.kts`. The upload keystore is kept outside the repository with an
    offline backup.
  - **iOS**: signing in CI uses an App Store Connect API key stored as CI secrets.
  - **Version**: `version: x.y.z+build` in `pubspec.yaml` is the only version source for both
    platforms.

  Document the procedure in `docs/release.md` (constitution › Platform & Store Requirements).
- [X] T011 Add `tool/size_check.dart` and a CI step in `.github/workflows/ci.yml`:
  - build with `--analyze-size` on both platforms and compare with `docs/size_baseline.json`;
  - fail if any platform exceeds 30 MB, or grows by more than 1 MB without a PR label
    `size-approved`.

  Also add `.github/pull_request_template.md` with a performance checklist (cold start, frame
  metrics on a reference device) required for changes that touch startup, navigation, lists,
  images or dependencies (constitution III, IV and Workflow).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build the verified Quran database, the data layer, the theme, startup and reader
state that every story uses.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### Quran data pipeline (build time, `tool/`)

- [ ] T012 Create `tool/README.md` documenting the exact source files to download into the
  gitignored `tool/sources/`, with download URL, expected filename and SHA-256 for each:
  - QUL "KFGQPC HAFS" Mushaf layout, 604 pages × 15 lines, `qpc-hafs`, SQLite export, from
    https://qul.tarteel.ai/mushaf_layouts;
  - QUL "KFGQPC Hafs (word by word)" script;
  - QUL imla'i word-by-word script;
  - Tanzil `quran-uthmani.xml` and Tanzil `quran-data.xml` (metadata), from
    https://tanzil.net/download/.

  Download them and record the checksums.
- [X] T013 [P] Implement the Arabic search normaliser in
  `lib/features/search/arabic_normalizer.dart`, as a pure Dart function with no Flutter imports so
  `tool/` can reuse it. Exact rules from research R7:
  - strip tashkeel and Quranic annotation marks (U+0610–U+061A, U+064B–U+065F, U+0670,
    U+06D6–U+06ED);
  - unify «أ/إ/آ/ٱ → ا, ى → ي, ؤ → و, ئ → ي, ة → ه»;
  - remove tatweel (U+0640);
  - collapse whitespace.
- [X] T014 Implement `tool/build_quran_db.dart` (depends on T012 and T013). It writes
  `assets/db/quran.db` with exactly the schema in
  [contracts/quran-db.md](./contracts/quran-db.md): `meta`, `surahs`, `ayahs`, `words`,
  `mushaf_lines` and `divisions`, including the CHECK constraints and indexes. It also:
  - fills `name_translit` for all 114 surahs;
  - fills `ayahs.search_text` with the normaliser applied to the joined imla'i words, and
    `words.search_offset` with each word's start offset in that string;
  - fills `divisions.opening_words` with the first 3–4 Uthmani words of the start ayah;
  - writes the meta keys `schema_version`="1.0", `built_at`, `font`, `source_<name>_sha256`,
    `attribution_tanzil`, `attribution_qul` and `attribution_kfgqpc`.
- [ ] T015 Diff the KFGQPC word text against Tanzil Uthmani from `tool/sources/`. Record every
  pair of code points that differ **in encoding only** (the same character written with a
  different code point) in `tool/encoding_map.json`, each with a written justification, and
  document them in `tool/encoding_map.md`. The owner reviews and approves the map before it is
  used. Never include a pair that changes a letter, diacritic or pause mark (FR-002).
- [X] T016 Implement `tool/verify_quran.dart`, the research R10 checks. It applies **only** the
  substitutions in `tool/encoding_map.json` (T015). It exits non-zero on any
  failure and prints `PASS (...)` with the counts otherwise:
  - counts are 114 surahs, 6,236 ayat, 604 pages, 30 juz, 240 hizb quarters and 15 sajdah ayat;
  - every ayah rebuilt from `words` equals Tanzil Uthmani after NFC and the approved
    `tool/encoding_map.json`, and any other difference fails;
  - every word id is in exactly one `ayah` line, in ascending order;
  - there is no `basmallah` line for surah 9 and no separate `basmallah` line for surah 1.

  Print the SHA-256 of `quran.db`.
- [X] T017 Implement `tool/measure_line_widths_test.dart`, run with
  `flutter test tool/measure_line_widths_test.dart` (depends on T007 and T014). It loads the
  `QuranText` font, lays out every `ayah` line of all 604 pages at a 100 px font size with
  `TextPainter`, and writes `meta.max_line_width_em` (widest line ÷ 100) into
  `assets/db/quran.db` (research R4).
- [ ] T018 Check the fallback font early with `tool/font_spike_test.dart`, run with
  `flutter test`. Render pages 1, 2, 50, 187, 255 and 604 with Amiri Quran. Use the KFGQPC font as
  a reference only if it is available locally for evaluation, without bundling or committing it.
  Check that:
  - ayah-end markers show Eastern Arabic numerals;
  - no glyph is missing (no fallback boxes);
  - no diacritics overlap.

  Record the result in research.md R3. **If Amiri Quran fails, T030 waits until D1 is resolved.**

### App foundation (`lib/`)

- [X] T019 [P] Create immutable models in `lib/data/models.dart`: `Surah`, `Ayah`, `Word`,
  `MushafLine`, `Division`, `Bookmark` and `ReaderPreferences`, with fields exactly as in
  [data-model.md](./data-model.md). Use enums `Revelation {makki, madani}`,
  `LineType {ayah, surahName, basmallah}`, `DivisionKind {juz, hizbQuarter}`,
  `ReadingLayout {mushaf, flowing}`, `ThemePref {system, day, night}` and
  `LanguagePref {system, ar, en}`.
- [X] T020 Implement `lib/data/quran_repository.dart` (depends on T019). It:
  - on first launch, or when the bundled `meta.built_at` differs, copies `assets/db/quran.db` to
    the sqflite databases path, then opens it read-only;
  - refuses to open if the major part of `meta.schema_version` is not "1";
  - provides `linesAndWordsForPage(p)`, `ayahsAndWordsForPage(p)`, `allSurahs()`,
    `allDivisions()` (both cached in memory after first load), `pageOf(surah, ayah)`,
    `firstAyahStartingOnPage(p)` and `maxLineWidthEm()`;
  - keeps the per-query budgets in contracts/quran-db.md (page queries ≤ 10 ms).
- [X] T021 Implement `lib/data/user_repository.dart` (depends on T019). It:
  - creates `user.db` schema v1 exactly as in [contracts/user-data.md](./contracts/user-data.md)
    (`bookmarks`, `reading_state` with `CHECK (id = 1)`, `preferences`), with `PRAGMA user_version`
    migrations that are forward-only and never delete bookmarks;
  - provides `loadStartup()`, which returns the anchor (default 1:1) and all preferences in one
    call (≤ 30 ms);
  - provides `saveAnchor(surah, ayah)` and `setPreference(key, value)`;
  - resets out-of-range preference values to their defaults: layout `mushaf`, theme `system`,
    flow_font_size 24 (allowed 18–34), keep_screen_on false, language `system`.
- [X] T022 [P] Read `project/tokens.json` from the Mathani brand design system (claude.ai artifact
  `2b08b81b-3fa4-4d13-8806-2681e820b520`) and transcribe it:
  - every colour token, with its day and night values, into `lib/app/theme/tokens.dart`;
  - spacing, radius, shadow and text styles (`display`, `title-lg`, `appbar-title`, `title-sm`,
    `body`, `caption`, `label`, `quran-page` 24/48, `quran-card` 20/38, `basmala` 22/40).
- [X] T023 Build `lib/app/theme/app_theme.dart` (depends on T022). It provides day and night
  `ThemeData` using `PlexArabic` and a `MathaniColors` `ThemeExtension` exposing the semantic
  tokens: `surface`, `surface-raised`, `surface-sunken`, `bar`, `ink-on-bar`, `ink`, `ink-muted`,
  `accent`, `on-accent`, `accent-ink`, `selected`, `row-selected`, `secondary`, `secondary-soft`,
  `line`, `focus-ring` and `focus-ring-on-bar`. Set the minimum interactive size to 44 pt on iOS
  and 48 dp on Android (contracts/ui-screens.md).
- [X] T024 [P] Implement `lib/shared/numerals.dart` with `toEasternArabic(int)` (٠–٩) and
  `formatNumber(int, Locale)`, which gives Eastern Arabic digits for `ar` and Western digits for
  `en` (contracts/ui-screens.md › Direction rules).
- [X] T025 Implement the `ReaderController` `ChangeNotifier` in `lib/shared/reader_state.dart`
  (depends on T020 and T021). It holds the anchor ayah, layout, selected ayah and highlighted
  ayah, and provides `jumpTo(surah, ayah, {highlight = true})`, which sets the target page and
  clears the highlight after 1.5 s. It saves the anchor with a 500 ms debounce on change and
  immediately when `AppLifecycleState` becomes `paused` or `inactive` (research R6).
- [X] T026 Implement startup in `lib/main.dart` and the app shell in `lib/app/app.dart` (depends
  on T023 and T025):
  - open `quran.db` and `user.db` in parallel and call `loadStartup()` before `runApp`;
  - in `MaterialApp`, set `supportedLocales` to ar and en and resolve the locale: pref `system`
    gives `ar` for Arabic device locales and `en` otherwise;
  - apply the day, night or system theme mode from preferences;
  - set the home to `ReaderScreen`;
  - read no network and run no work in the background.
- [X] T027 [P] Generate the icon font. Put the Lucide (ISC) SVGs in `tool/icons/`: book-open,
  list, search, settings, bookmark, bookmark-check, copy, share-2, chevron-left, chevron-right, x,
  sun, moon, type, rows-3 and info. Run `npx fantasticon` to produce
  `assets/fonts/MathaniIcons.ttf`, declare the family in `pubspec.yaml`, and write
  `lib/shared/mathani_icons.dart` with an `IconData` constant per glyph. Mark back and forward
  chevrons `matchTextDirection: true` and never mirror media icons.
  *Done differently:* used the prebuilt `lucide-static` 1.48.0 font (`assets/fonts/Lucide.ttf`)
  instead of fantasticon. Lucide icons are strokes, which icon-font generators cannot fill.
  Release builds tree-shake the unused glyphs.

**Checkpoint**: `dart run tool/verify_quran.dart` prints PASS. The app launches to an empty
`ReaderScreen` stub with the brand theme in Arabic and English.

---

## Phase 3: User Story 1 - Read the Mushaf in Uthmani script (Priority: P1) 🎯 MVP

**Goal**: The page-faithful 604-page Madinah Mushaf. It works offline, turns pages like a printed
Mushaf, shows surah headers, basmala, ayah markers, a juz/page header and quarter/sajdah markers,
and restores the last page.

**Independent Test**: quickstart scenarios 1–4. Run on a fresh install in airplane mode, page
through several surahs (including pages 1, 187 and 604), force-stop and reopen. The Mushaf is
fully readable and reopens on the same page.

- [X] T028 [P] [US1] Implement `lib/features/reader/mushaf_layout_metrics.dart`. It computes one
  Quran font size per screen geometry: `min(contentWidth / maxLineWidthEm,
  contentHeight / (15 × 2.0))`, where line height is 2.0× (research R4). Cache by size, and
  recompute only when the size changes.
- [X] T029 [P] [US1] Implement `lib/features/reader/surah_header_painter.dart`. It paints the surah
  name frame for `surah_name` lines: an `accent-ink` outline frame with the surah name in
  `QuranText`, using brand colours and no shadows (brand guide: no decoration behind ayah text).
- [X] T030 [US1] Implement `lib/features/reader/mushaf_page_renderer.dart` (depends on T028 and
  T029). It is a `LeafRenderObjectWidget` and `RenderBox` that:
  - lays out 15 line slots; caches one `TextPainter` per word in `QuranText`;
  - justifies `ayah` lines by spreading leftover width evenly between words, and centres them when
    `centered`;
  - draws `basmallah` lines and `surah_name` lines (via the header painter);
  - always lays out RTL;
  - paints the selected or highlighted ayah's words with a `secondary-soft` background;
  - exposes `ayahAt(Offset)` hit-testing that maps a word to its surah:ayah;
  - uses the theme's `ink` and `surface` so the night theme works.
- [X] T031 [US1] Add FR-007 markers to `lib/features/reader/mushaf_page_renderer.dart`: a
  rub'-al-hizb ۞ marker in the line margin at each hizb-quarter start ayah, and the sajdah marker
  ۩ at the 15 sajdah ayat (from `ayahs.sajdah`), in `accent-ink`.
- [X] T032 [US1] Implement `lib/features/reader/mushaf_view.dart`. It is a `PageView.builder` of
  604 pages:
  - wrap it in `Directionality(textDirection: TextDirection.rtl)` whatever the interface language
    is, so the next page lies to the left (FR-004);
  - set `allowImplicitScrolling: true` to preload n±1;
  - load page data from `QuranRepository` with an in-memory cache of the last 5 pages;
  - on page change, set the controller anchor to `firstAyahStartingOnPage(p)`;
  - add semantics label "Page <n>, Surah <name>" in the interface language.
- [X] T033 [US1] Implement `lib/features/reader/reader_screen.dart`:
  - a `bar` header within safe areas, showing the current surah name, juz number and page number
    in Eastern Arabic numerals inside the Mushaf context (FR-008);
  - the body holds `MushafView`;
  - a toolbar row shows only actions that already exist (FR-028; later stories add their buttons);
  - on first build, open the page that contains the startup anchor through
    `ReaderController.jumpTo(..., highlight: false)`.
- [X] T034 [US1] Add the reader strings to `lib/app/l10n/app_en.arb` and
  `lib/app/l10n/app_ar.arb`: header labels (juz, page) and page semantics labels.
- [X] T035 [US1] Verify FR-006 in the running app: no basmala line before surah 9 (page 187), and
  Al-Fatiha's basmala rendered as ayah 1 (page 1). Fix any data or rendering issue found in
  `tool/build_quran_db.dart` or `lib/features/reader/mushaf_page_renderer.dart`.

**Checkpoint**: US1 is fully functional. Quickstart scenarios 1–4 pass on an Android device and
on the iOS simulator in CI.

---

## Phase 4: User Story 2 - Navigate to any surah, juz or page (Priority: P1)

**Goal**: The Index (Surahs and Ajza' tabs) and the Go-to sheet. Any location is reachable in 3
taps or entries or fewer.

**Independent Test**: quickstart scenario 5. Reach Al-Kahf, Juz 30, quarter 120, page 300 and
2:255 in ≤ 3 taps each. Page 605 and 2:300 are rejected with the valid range shown.

- [X] T036 [P] [US2] Implement `lib/features/index/surahs_tab.dart`. It lists all 114 surahs in
  Mushaf order with number, `name_ar` (plus `name_translit` in English), ayah count, Makki/Madani
  and start page (FR-010). Use `ListView.builder` with semantics "<surah name>, <ayah count> ayat,
  page <n>". A tap calls `ReaderController.jumpTo(surah, 1)` and pops.
- [X] T037 [P] [US2] Implement `lib/features/index/ajza_tab.dart` as a `ListView.builder`:
  - the 30 juz are **section headers**, each followed directly by its 8 hizb-quarter rows (240
    total, **no expand or collapse**);
  - each row shows `opening_words` and the start page (FR-011);
  - tapping a header or a row jumps to its start ayah and pops, so any juz or quarter is 3 taps
    away: Index → Ajza' → row (SC-004).
- [X] T038 [P] [US2] Implement `lib/features/index/goto_sheet.dart`. It has a page field (valid
  "1–604"), or a surah picker plus an ayah field (valid "1..ayah_count"). Invalid input shows the
  valid range inline and does not navigate (FR-012). Valid input calls `jumpTo` with a 1.5 s
  highlight.
- [X] T039 [US2] Implement `lib/features/index/index_screen.dart` (depends on T036–T038). It has
  brand ChipTabs Surahs · Ajza' and a go-to button opening the sheet. Add the index button to the
  toolbar in `lib/features/reader/reader_screen.dart`.
- [X] T040 [US2] Add the index, go-to and validation strings (including the range messages) to
  `lib/app/l10n/app_en.arb` and `lib/app/l10n/app_ar.arb`.

**Checkpoint**: US1 and US2 work. This is a usable Mushaf MVP.

---

## Phase 5: User Story 3 - Bookmarks and reading progress (Priority: P2)

**Goal**: Add, list (newest first), open and remove bookmarks, with a page indicator.

**Independent Test**: quickstart scenario 6. Bookmark three places (one twice), restart, see three
rows newest first, open one and delete one.

- [X] T041 [US3] Add bookmark operations to `lib/data/user_repository.dart`:
  - `addBookmark(surah, ayah, page)` uses `INSERT OR IGNORE`, because `UNIQUE (surah, ayah)` makes
    a duplicate a no-op that returns the existing row;
  - `removeBookmark(id)`;
  - `listBookmarks()` uses `ORDER BY created_at DESC`;
  - `isBookmarked(page)`;
  - all of them notify listeners on change.
- [X] T042 [US3] Add the bookmark toggle to the toolbar of `lib/features/reader/reader_screen.dart`
  with an on-page indicator. A page bookmark is stored against `firstAyahStartingOnPage(p)`
  (data-model.md › Bookmark).
- [X] T043 [P] [US3] Implement `lib/features/index/bookmarks_tab.dart`. Each row shows the surah
  name, ayah, page and date added. A tap jumps to the bookmark; a swipe or the delete button
  removes it. Show an empty state with `mathani-mark-navy` and guidance text.
- [X] T044 [US3] Add the Bookmarks tab as the third chip in `lib/features/index/index_screen.dart`
  (FR-009), and add the bookmark strings to `lib/app/l10n/app_en.arb` and
  `lib/app/l10n/app_ar.arb`.

**Checkpoint**: US3 works on its own on top of US1 and US2.

---

## Phase 6: User Story 4 - Comfortable reading (Priority: P2)

**Goal**: The flowing layout with adjustable size, the layout toggle that keeps the ayah, the night
theme, keep-screen-on, the interface language switch, and Settings with About and attributions.

**Independent Test**: quickstart scenarios 7–10. Toggle layouts and stay on the same ayah, change
flowing size 18→34 with no collisions, use night theme and keep-screen-on, switch the language
between English and Arabic, restart, and see that everything persisted.

- [X] T045 [P] [US4] Implement `lib/features/reader/flowing_view.dart`. It is a
  `ListView.builder` with 604 items, one per Mushaf page:
  - each item is one `RichText` of that page's ayat with inline ayah-end markers, and surah header
    plus basmala where surahs begin;
  - `QuranText` size comes from pref `flow_font_size` (18–34, default 24) with `height: 2.0`;
  - always lay out RTL;
  - the anchor is the first ayah visible at the top; the header page number is the topmost item's
    page (research R5).
- [X] T046 [US4] Add the one-tap layout toggle to `lib/features/reader/reader_screen.dart`. It
  swaps between `MushafView` and `FlowingView`, jumps to the page or item containing the current
  anchor, persists pref `layout`, and finishes within 1 s (FR-003, SC-010).
- [X] T047 [P] [US4] Implement `lib/features/settings/settings_screen.dart` with these settings:
  - layout (mushaf/flowing);
  - theme (system/day/night);
  - flowing text size slider 18–34, shown only for the flowing layout;
  - keep-screen-on;
  - language (system/ar/en).

  Each change calls `UserRepository.setPreference` and applies immediately.
- [X] T048 [P] [US4] Implement `lib/features/settings/about_section.dart`. It shows the app version
  and the attributions from `quran.db` meta: Tanzil Project with a tappable https://tanzil.net
  link opened in the system browser via `url_launcher` (required by the Tanzil CC BY 3.0 terms),
  QUL and KFGQPC. It also lists the font and icon
  licences from `docs/licences.md`.
- [X] T049 [US4] Wire preferences into `lib/app/app.dart` so theme mode and locale switch live
  without a restart. Toggle `WakelockPlus` in `lib/features/reader/reader_screen.dart` while the
  reader is visible and `keep_screen_on` is true. Use `name_translit` alongside the Arabic name in
  the header and surahs tab when the locale is `en` (FR-025).
- [X] T050 [US4] Add the settings button to the toolbar in
  `lib/features/reader/reader_screen.dart`, and add the settings and about strings to
  `lib/app/l10n/app_en.arb` and `lib/app/l10n/app_ar.arb`.

**Checkpoint**: US4 works. Both layouts and both languages keep the reader on the same ayah.

---

## Phase 7: User Story 5 - Copy or share an ayah (Priority: P3)

**Goal**: Long-press an ayah to copy, share or bookmark it, using the exact text and reference
format.

**Independent Test**: quickstart scenario 11. Long-press 2:255 and share it to a messaging app;
the text matches the contract format exactly.

- [ ] T051 [P] [US5] Implement `formatAyahForShare(words, surah, ayah, locale)` in
  `lib/features/reader/ayah_actions.dart`, exactly as in
  [contracts/ui-screens.md](./contracts/ui-screens.md):
  - Arabic: `﴿<Uthmani text without ayah-end marker>﴾` + newline + `سورة <name_ar>: <ayah in
    Eastern Arabic numerals>`;
  - English: the same first line + newline + `Surah <name_translit> <surah>:<ayah>`.
- [ ] T052 [US5] Add the action sheet in `lib/features/reader/ayah_actions.dart` (depends on T051).
  It offers Copy (`Clipboard.setData`), Share (`share_plus`) and Bookmark (calls
  `UserRepository.addBookmark`; hide it if US3 is not built), and shows a short confirmation.
- [ ] T053 [US5] Wire long-press selection:
  - in `lib/features/reader/mushaf_view.dart`, use `ayahAt(Offset)` from the renderer;
  - in `lib/features/reader/flowing_view.dart`, add a `LongPressGestureRecognizer` per ayah
    `TextSpan`.

  Both set `ReaderController.selected`, highlight the ayah and open the action sheet (FR-020).
  Add the strings to `lib/app/l10n/app_en.arb` and `lib/app/l10n/app_ar.arb`.

**Checkpoint**: US5 works in both layouts and both languages.

---

## Phase 8: User Story 6 - Search the Quran text (Priority: P3)

**Goal**: Arabic search that ignores diacritics and spelling variants, shows highlighted results
with a count, and opens the result in the Mushaf.

**Independent Test**: quickstart scenario 12. «الرحمن الرحيم» typed without diacritics returns
highlighted results and a count in under 1 s, and a tap opens the ayah. «زززز» shows "no results".

- [ ] T054 [US6] Implement `lib/features/search/search_index.dart`:
  - on first use, lazily load all `ayahs.search_text` and `words.search_offset` from
    `QuranRepository` (≤ 150 ms) and cache them;
  - `search(query)` normalises the query with `arabic_normalizer.dart` and runs a substring scan
    over all 6,236 strings;
  - map match character ranges to word ids through `search_offset`;
  - return results (surah, ayah, matched word ids) plus the total count (research R7).
- [ ] T055 [US6] Implement `lib/features/search/search_screen.dart` (depends on T054):
  - a query field debounced 200 ms, with the result count;
  - results in `ListView.builder` using the `quran-card` style (20/38), with matched Uthmani words
    on a `selected`/accent background and the surah name and ayah number;
  - an empty-query hint and a "no results" message;
  - a tap calls `ReaderController.jumpTo(surah, ayah)` with a 1.5 s highlight and pops.
- [ ] T056 [US6] Add the search button to the toolbar in `lib/features/reader/reader_screen.dart`,
  and add the search strings to `lib/app/l10n/app_en.arb` and `lib/app/l10n/app_ar.arb`.

**Checkpoint**: All six user stories work.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Brand assets, store compliance, verification gates and release readiness.

- [ ] T057 [P] Download the brand logos (`mathani-app-icon.svg`, `mathani-mark-gold.svg`,
  `mathani-mark-navy.svg`, `mathani-lockup-navy.svg`) from the brand design system's Logos asset
  group into `tool/brand/`. Render PNGs at @1x/@2x/@3x into `assets/images/` with
  `npx @resvg/resvg-js-cli`, without redrawing or changing proportions (brand guide).
- [ ] T058 [P] Generate the app icons from `tool/brand/mathani-app-icon.svg`:
  - `android/app/src/main/res/mipmap-*/` (including an adaptive icon foreground on a `bar` navy
    background);
  - `ios/Runner/Assets.xcassets/AppIcon.appiconset/` (1024×1024 full-bleed).
- [ ] T059 [P] Configure native launch screens with `mathani-mark-gold` on `bar` navy `#183159`:
  - `android/app/src/main/res/drawable/launch_background.xml` and the `values-v31/styles.xml`
    splash attributes;
  - `ios/Runner/Base.lproj/LaunchScreen.storyboard`.

  Add no runtime splash package.
- [ ] T060 [P] Add `ios/Runner/PrivacyInfo.xcprivacy`, declaring no tracking and no collected data
  plus the required-reason API entries Flutter plugins use. Write `docs/store/privacy.md` with the
  App Store "Data Not Collected" and Play Data safety "No data collected / shared" answers
  (FR-027).
- [ ] T061 [P] Write the store listings in `docs/store/listing_ar.md` (name «مثاني: تلاوة وتدبر
  المتشابه») and `docs/store/listing_en.md` (name to be decided by the owner; the suggestion is
  "Mathani: Quran & Mutashabihat"). Each has a short description, full description and screenshot
  plan in the brand tone: plain Modern Standard Arabic, no exclamation marks.
- [ ] T062 [P] Add golden tests for the Mushaf renderer at 3 screen widths (320, 375 and 412 dp)
  for pages 1, 2, 187 and 604 in `test/widget/mushaf_page_renderer_golden_test.dart`. They cover
  risk R-a: justified lines with no overflow or clipping.
- [ ] T063 [P] Add `integration_test/app_flow_test.dart` covering quickstart scenarios 1, 2, 4, 5,
  6, 7 and 10: offline launch, paging, restore after restart, navigation, bookmarks, layout toggle
  keeping the ayah, and language switch.
- [ ] T064 [P] Add `integration_test/paging_perf_test.dart` and `test_driver/perf_driver.dart`.
  They page through 50 Mushaf pages and scroll the flowing layout under `flutter drive --profile`,
  write a timeline summary, and fail on any frame over 16 ms at the 90th percentile or on missed
  frames during paging (constitution III).
- [ ] T065 Add `docs/release.md` with the release build commands:
  - `flutter build appbundle --release --obfuscate --split-debug-info=symbols/android
    --analyze-size`;
  - `flutter build ipa --release --obfuscate --split-debug-info=symbols/ios --analyze-size`.

  Include the release checklist: verify_quran PASS with the SHA-256 recorded, D1 and D2
  resolved, size ≤ 30 MB per platform, and the reference-device numbers.
- [ ] T066 Resolve the font for release. If D1 is granted, place
  `assets/fonts/UthmanicHafs.ttf` (KFGQPC, unmodified) as the `QuranText` family, set `meta.font`
  to `kfgqpc-hafs`, and rebuild `quran.db` and the line widths (T014, T017). Otherwise keep Amiri
  Quran. Then re-run the golden tests (T062) and record the decision in `docs/licences.md`.
- [ ] T067 Run every scenario in [quickstart.md](./quickstart.md) on the Galaxy A15 (or an
  equivalent) and the iPhone SE (2nd gen) (or an equivalent) using release builds. Record cold
  start (≤ 2 s), frame metrics, search time (≤ 1 s) and download sizes (≤ 30 MB) in
  `docs/release.md`, and fix any regression before submission.

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: no dependencies. T001 comes first; T002–T009 follow it and can run in
  parallel. T010 and T011 follow T009, because they need the repository and CI.
- **Foundational (Phase 2)**: depends on Setup and blocks all stories. The data pipeline is
  T012 → T013 → T014 → T015 → T016, and T014 → T017 → T018. T018 gates T030 (the Mushaf
  renderer). The app foundation is T019 → T020/T021 → T025 → T026.
  T022 → T023, T024 and T027 can run in parallel with the pipeline.
- **User stories (Phases 3–8)**: all depend on Foundational.
- **Polish (Phase 9)**: T057–T061 can start any time after Setup. T062–T067 need the stories they
  check.

### User story dependencies

| Story | Depends on | Notes |
| --- | --- | --- |
| US1 (P1) | Foundational | The MVP core. Every other story lands on its reader. |
| US2 (P1) | US1 | Navigation targets the reader (`jumpTo` from T025, rendered by T032). |
| US3 (P2) | US1, US2 | The Bookmarks tab lives in the Index (T039); the toolbar toggle needs only US1. |
| US4 (P2) | US1 | The flowing layout and settings are independent of US2 and US3. |
| US5 (P3) | US1 | The Bookmark action is optional and hidden without US3. |
| US6 (P3) | US1 | Uses the T013 normaliser and `quran.db` search columns from Foundational. |

After US1, the stories US2, US4, US5 and US6 can proceed in parallel. US3 follows US2.

### Within each story

Models and data first, then views, then screen wiring and the toolbar button, then strings.
`reader_screen.dart` and the `.arb` files are shared, so edits to them across stories are
sequential (no [P]).

---

## Parallel Example: Foundational + User Story 1

```text
# Foundational, after T012:
Task: "T013 Arabic normaliser in lib/features/search/arabic_normalizer.dart"
Task: "T019 Models in lib/data/models.dart"
Task: "T022 Brand tokens in lib/app/theme/tokens.dart"
Task: "T024 Numerals in lib/shared/numerals.dart"
Task: "T027 Icon font in assets/fonts/MathaniIcons.ttf + lib/shared/mathani_icons.dart"

# User Story 1, together:
Task: "T028 Layout metrics in lib/features/reader/mushaf_layout_metrics.dart"
Task: "T029 Surah header painter in lib/features/reader/surah_header_painter.dart"

# After US1, different developers or sessions:
Task: "T036–T038 Index tabs and go-to sheet (US2)"
Task: "T045 Flowing view (US4)"
Task: "T051 Share formatter (US5)"
Task: "T054 Search index (US6)"
```

---

## Implementation Strategy

### MVP first (US1, then US2)

1. Phase 1 Setup, then Phase 2 Foundational. Stop when `verify_quran` prints PASS.
2. Phase 3 (US1): validate quickstart scenarios 1–4 on Android, and on iOS through CI or a Mac.
3. Phase 4 (US2): this gives a usable Mushaf with navigation, an internal beta via TestFlight and
   the Play internal testing track.

### Incremental delivery

4. US3 bookmarks, then US4 comfort and language. This is the public 1.0 candidate.
5. US5 share, then US6 search. Ship with 1.0 if they are ready, or in 1.1.
6. Phase 9 polish and release gates (T065–T067) before every store submission.

### Release blockers to start now (outside the code)

- **D1**: request written permission from KFGQPC for the Hafs font (affects T066).
- **D2**: confirm the QUL data reuse terms (affects T012 and T014).
- Choose the English store name (T061) and confirm the bundle ID (T001).

---

## Notes

- [P] tasks touch different files and have no unfinished dependencies.
- The Quran text must never be edited by hand. Fix sources or the build script, then re-run T016.
- Commit after each task or logical group, on branch `001-quran-mushaf-reader`.
- Stop at any checkpoint to validate a story on its own.
