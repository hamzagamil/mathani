# Implementation Plan: Quran Mushaf Reader (Uthmani Script)

**Branch**: `001-quran-mushaf-reader` | **Date**: 2026-10-10 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-quran-mushaf-reader/spec.md`

## Summary

Mathani's first release is an offline Quran reader for iOS and Android. It offers a page-faithful
604-page Madinah Mushaf layout and a resizable flowing layout. Readers get navigation by surah,
juz, quarter, page and ayah, plus bookmarks, night theme, keep-screen-on, copy and share, Arabic
search, and an Arabic/English interface.

Technical approach:
- **App**: one **Flutter** codebase.
- **Data**: a **read-only Quran database built at build time** from licensed sources: QUL's
  KFGQPC-Hafs 15-line layout and word text, plus Tanzil for verification and metadata.
- **Fonts**: one Uthmani font, KFGQPC Hafs, with Amiri Quran as the fallback.
- **Mushaf rendering**: a custom word-level page renderer.
- **Search**: in-memory, over normalised text.
- **User data**: a tiny on-device database.
- **Footprint**: five runtime packages; estimated download about 12 MB on Android and 20 MB on
  iOS.

## Technical Context

**Language/Version**: Dart 3.13 / Flutter 3.47 stable (pin the exact version in `pubspec.yaml` at
project creation)

**Primary Dependencies**: Flutter SDK (`flutter_localizations`, `intl`), `sqflite`,
`wakelock_plus`, `share_plus`, `url_launcher`. Nothing else at runtime; justified in research R8.

**Storage**: SQLite. `quran.db` is bundled and read-only (see
[contracts/quran-db.md](./contracts/quran-db.md)). `user.db` holds on-device bookmarks, reading
state and preferences (see [contracts/user-data.md](./contracts/user-data.md)).

**Testing**:
- `flutter_test` for unit and widget tests.
- `integration_test` for end-to-end tests on devices.
- `flutter drive --profile` for frame metrics.
- `tool/verify_quran.dart` for text integrity (SC-003).

**Target Platform**: iOS 15.0+ and Android 7.0 (API 24)+, targeting API 36. Phones, portrait only.

**Project Type**: mobile app (single Flutter project, no backend)

**Performance Goals**:
- Cold start to readable Mushaf in ≤ 2 s on Galaxy A15 and iPhone SE (2nd gen).
- 60 fps paging and scrolling.
- Visible tap feedback in ≤ 100 ms.
- Search results in ≤ 1 s.
- Layout or language switch in ≤ 1 s.
- Page data query in ≤ 10 ms.

**Constraints**:
- Fully offline from first launch.
- Store download ≤ 30 MB per platform.
- No account, no network calls, and no analytics in v1.
- Quran text reproduced verbatim.
- Mushaf area always RTL.

**Scale/Scope**:
- Data: 604 pages, 6,236 ayat, about 83k words.
- Screens: 6 (Reader, Index, Go-to, Search, Settings, Ayah actions).
- Languages: 2.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Pre-research | Post-design |
| --- | --- | --- | --- |
| I. Cross-Platform Parity | Every feature on iOS and Android; platform conventions respected; min OS stated | ✅ single Flutter codebase | ✅ Identical shaping engine on both platforms (R1). Native share sheet and system back. Min OS iOS 15 / Android API 24 (R11). |
| II. Mobile-First Design | Phone portrait; 44 pt / 48 dp targets; safe areas; dark mode; font scaling; screen readers | ✅ spec FR-029 | ✅ Portrait locked. Android targets set to 48 dp, overriding the brand's 44 ([ui-screens](./contracts/ui-screens.md)). Night theme. Labelled controls. |
| III. Performance (NON-NEGOTIABLE) | ≤2 s cold start, 60 fps, ≤100 ms feedback, cached content, virtualised lists | ✅ spec SC-001/002/006 | ✅ No startup network or parsing. One startup query (≤30 ms). Pages preloaded (n±1). Cached word painters. Virtualised flowing list. Measured on reference devices ([quickstart](./quickstart.md)). |
| IV. Lean by Default | Every dependency justified; shrinking; ≤30 MB; efficient assets; no background work | ✅ | ✅ 5 runtime packages (R8). R8 shrink, obfuscation, icon tree-shaking. Icon font instead of an SVG runtime. Estimate about 12/20 MB (R12). No background work. |
| V. Simplicity | Simplest solution; reuse; complexity justified | ✅ | ✅ Feature folders, no repository interfaces, no state or routing libraries. Two justified items in Complexity Tracking. |
| Store & privacy | Store policies; no unneeded permissions; secure storage for sensitive data | ✅ | ✅ No permissions requested. No personal data, so secure storage is not needed. Privacy forms declare "no data collected". |

**Result**: PASS. Licence dependencies D1 (KFGQPC font) and D2 (QUL data) block release but not
design (see Risks).

## Project Structure

### Documentation (this feature)

```text
specs/001-quran-mushaf-reader/
├── plan.md              # This file
├── research.md          # Phase 0: decisions R1–R12, sources
├── data-model.md        # Phase 1: entities, rules, reader state
├── quickstart.md        # Phase 1: setup, validation scenarios, perf/size gates
├── contracts/
│   ├── quran-db.md      # bundled Quran database schema and query budgets
│   ├── user-data.md     # on-device user database schema and operations
│   └── ui-screens.md    # screens, direction rules, share format, store presence
└── tasks.md             # Phase 2 (/speckit-tasks; not created here)
```

### Source Code (repository root)

```text
pubspec.yaml
l10n.yaml
lib/
├── main.dart                    # startup: open DBs, load prefs + anchor, runApp
├── app/
│   ├── app.dart                 # MaterialApp, locale/direction, theme mode
│   ├── theme/                   # brand tokens → ThemeData + ThemeExtension (day/night)
│   └── l10n/                    # app_ar.arb, app_en.arb (gen-l10n)
├── data/
│   ├── quran_repository.dart    # read-only queries on quran.db (contract budgets)
│   ├── user_repository.dart     # bookmarks, reading state, preferences on user.db
│   └── models.dart              # Surah, Ayah, Word, MushafLine, Division, Bookmark
├── features/
│   ├── reader/
│   │   ├── reader_screen.dart   # header, toolbar, layout switch, anchor tracking
│   │   ├── mushaf_view.dart     # RTL PageView of 604 pages
│   │   ├── mushaf_page_renderer.dart  # custom RenderBox: word painters, justification
│   │   ├── flowing_view.dart    # virtualised per-page RichText list
│   │   └── ayah_actions.dart    # copy / share / bookmark sheet, share formatting
│   ├── index/                   # surahs, ajza', bookmarks tabs, go-to sheet
│   ├── search/                  # search screen + arabic_normalizer.dart
│   └── settings/                # settings + about/attributions
└── shared/                      # reader state (ChangeNotifier), common widgets, numerals
assets/
├── db/quran.db                  # generated by tool/build_quran_db.dart
├── fonts/                       # KFGQPC Hafs (or Amiri Quran), IBM Plex Sans Arabic ×4, icon font
└── images/                      # logo PNGs @1x/2x/3x, surah header frame
tool/
├── build_quran_db.dart          # sources → quran.db
├── verify_quran.dart            # integrity checks (R10)
└── sources/                     # downloaded source files (gitignored)
test/
├── unit/                        # normalizer, share format, anchor mapping, repositories
└── widget/                      # index tabs, go-to validation, settings, page renderer
integration_test/                # offline launch, paging, restore, layout/language switch, perf
android/  ios/                   # platform projects: launch screens, icons, portrait lock
docs/licences.md                 # source licences, permissions received (D1, D2)
```

**Structure Decision**: a single Flutter project at the repository root, organised in feature
folders (`lib/features/*`) with a thin shared `data/` layer. There is no backend and no separate
packages. The build-time data pipeline lives in `tool/` and does not ship in the app.

## Risks & Open Dependencies

| ID | Risk | Impact | Mitigation |
| --- | --- | --- | --- |
| D1 | The KFGQPC Hafs font licence needs written approval to embed | **Release blocker** | Request permission from KFGQPC now. The font is swappable (`meta.font`); fall back to Amiri Quran (OFL) and re-verify line fit. |
| D2 | QUL layout and word data reuse terms are unstated | **Release blocker** | Ask QUL/Tarteel in writing. Fallback is to derive line data from KFGQPC/Tanzil sources (research R2). |
| R-a | Justified lines do not exactly match print on some screen widths | Visual fidelity | Lines come from the official layout, so only inter-word spacing varies. Golden tests on 3 screen widths. |
| R-b | No Mac for iOS builds | iOS parity, schedule | Set up cloud macOS CI (Codemagic / GitHub Actions) in the first sprint. |
| R-c | English store listing name undecided | Store submission | Owner decision before submission (suggestion in spec). |

## Complexity Tracking

> Not violations: listed to justify added complexity under Principle V.

| Item | Why Needed | Simpler Alternative Rejected Because |
| --- | --- | --- |
| Custom `MushafPageRenderer` (RenderBox) | Exact per-line justification, per-word hit testing for ayah selection, and about 1 render object per page instead of about 150 widgets (R4) | A `Text` per line cannot justify single lines or report word positions |
| Build-time data pipeline (`tool/`) | Turns several licensed sources into one verified, query-ready database; enables the SC-003 integrity proof | Parsing raw sources at runtime costs startup time and size, and cannot be verified ahead of release |
