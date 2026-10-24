# Implementation Plan: Print-Like Mushaf Page

**Branch**: `002-print-like-mushaf-page` | **Date**: 2026-10-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-print-like-mushaf-page/spec.md`

## Summary

Make the Mushaf layout look like the printed page.

1. **Lines filled by kashida, not gaps** (User Story 1). Unicode Quran fonts set the KFGQPC lines at
   widths from 0.65 to 1.0 of the widest, so today the gaps absorb the difference: 2.8× a space
   at the median, up to 12.6×. A small justification engine inserts tatweel into the *display*
   text at proper join points, round-robin across words, and gaps keep to 0.5–1.5× a space
   (research P1–P3). It was prototyped on all 604 pages, and the rendered pages read as print.
2. **Print proportions on every screen** (User Story 2). A fixed-ratio text block (height ÷ width
   1.77, from the reference). The font size comes from the widest line, and spare space becomes
   margins (research P4).
3. **Full-screen paper page** (User Story 3). Bars and controls hide while reading and appear on
   tap. Surah, juz and page number are drawn on the page. The sheet has a page edge and a
   generated paper texture (research P5).
4. **Optional exact-replica pack** (User Story 4). Designed here, but **gated**: D3 (KFGQPC
   permission), spike S-1 (the lettering's line breaks must match ours 100%; a 2-page sample
   of the API's default layout differed on 15 of 289 words) and spike S-2 (WOFF2 support and
   memory on devices) (research P6).

## Technical Context

**Language/Version**: Dart 3.13.5 / Flutter 3.47.7 (pinned)

**Primary Dependencies**: unchanged. Flutter SDK, `sqflite`, `wakelock_plus`, `share_plus`,
`url_launcher`. The replica pack uses `dart:io` (`HttpClient`, `GZipCodec`) and `FontLoader`, so
no new package.

**Storage**:
- `quran.db`: one new meta key, `justify_target_em`, written by
  `tool/measure_line_widths_test.dart`. No schema change.
- `user.db`: two keys in the existing `preferences` table (`controls_hint_shown`, `lettering`).
- Replica pack: files under the app support directory (optional).

**Testing**: `flutter_test` unit tests (`kashida_test`), widget tests over all 604 pages at 3
widths (`mushaf_typesetting_test`), reader view tests, golden tests for 5 pages × 2 themes, and
integration and profile runs on the reference phones.

**Target Platform**: iOS 15.0+ and Android 7.0 (API 24)+, phones, portrait.

**Project Type**: mobile app (single Flutter project, no backend)

**Performance Goals**:
- 60 fps paging; page layout ≤ 8 ms on the reference phones.
- Controls appear ≤ 100 ms after a tap.
- Cold start ≤ 2 s (unchanged).

**Constraints**:
- Quran text verbatim (kashida only in display strings).
- Line and page breaks unchanged.
- Store download growth ≤ 0.5 MB.
- Offline-first; the pack is the only network use, and only on request.

**Scale/Scope**: 604 pages, 8,791 justified lines; 3 reference widths; 1 screen reworked (Reader,
Mushaf layout), 1 settings section added (pack), 1 new build tool (pack).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Pre-research | Post-design |
| --- | --- | --- | --- |
| I. Cross-Platform Parity | Same on iOS and Android; platform conventions | ✅ | ✅ Typesetting is pure Dart. Immersive mode uses each platform's convention (sticky on Android, hidden status bar on iOS). Pack format proven on both platforms first (S-2). |
| II. Mobile-First Design | Phone portrait; 44 pt / 48 dp; safe areas; dark mode; screen readers | ✅ | ✅ The page stays within safe areas. Controls keep their sizes. Night sheet. With a screen reader on, controls stay visible, and a semantic "show controls" action exists. Contrast ≥ 4.5:1 checked. |
| III. Performance (NON-NEGOTIABLE) | ≤ 2 s cold start, 60 fps, ≤ 100 ms feedback | ✅ | ✅ Justification is O(words) per line, run once per page layout, ≤ 8 ms budget, measured in profile. Texture generated once (128 × 128). Page fonts load lazily with n ± 2 prefetch. |
| IV. Lean by Default | Dependencies justified; ≤ 30 MB; no background work | ✅ | ✅ No new packages. No new assets: the texture is generated, kashida is code. Growth ≤ 0.5 MB, checked. The pack is opt-in and outside the store download. It downloads only while the app is open. |
| V. Simplicity | Simplest solution; complexity justified | ✅ | ⚠️ Two justified additions; see Complexity Tracking. |
| Store & privacy | Store policies; permissions only when needed | ✅ | ⚠️ The pack adds the app's first network use and Android's `INTERNET` permission. No personal data, so the privacy answers stay "no data collected", rechecked before release. Not needed until the pack ships. |

**Result**: PASS, with two items justified in Complexity Tracking. The pack phase may not start
until D3, S-1 and S-2 are resolved (Risks).

## Project Structure

### Documentation (this feature)

```text
specs/002-print-like-mushaf-page/
├── plan.md              # This file
├── research.md          # P1–P6: cause, kashida, engine, proportions, paper page, replica pack
├── data-model.md        # join points, justification, geometry, prefs, pack files and states
├── quickstart.md        # automated checks, device scenarios, perf/size gates
├── contracts/
│   ├── page-typesetting.md   # geometry, justifyLine, joinPoints, budgets
│   ├── reader-page-view.md   # reading / controls states, hint, sheet, accessibility
│   └── replica-pack.md       # host layout, manifest, build tool, app behaviour (gated)
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks; not created here)
```

### Source Code (repository root)

```text
lib/
├── features/reader/
│   ├── kashida.dart               # NEW: joinPoints(), justifyLine() — pure Dart
│   ├── page_geometry.dart         # NEW: replaces mushaf_layout_metrics.dart (text block 1.77, bands)
│   ├── mushaf_page_renderer.dart  # kashida display strings, geometry, header/footer page details
│   ├── paper_sheet.dart           # NEW: generated noise texture + page-edge gradient
│   ├── mushaf_view.dart           # tap → toggle controls; page turn → hide
│   ├── reader_screen.dart         # overlay header/toolbar in Mushaf layout; immersive mode; hint
│   └── replica_lettering.dart     # NEW (pack phase): page font loading, glyph drawing
├── features/settings/
│   ├── settings_screen.dart       # "Printed Mushaf" section (pack phase)
│   └── replica_pack.dart          # NEW (pack phase): state, download, verify, delete
├── data/
│   ├── models.dart                # Lettering enum; ReaderPreferences.lettering
│   ├── user_repository.dart       # controls_hint_shown, lettering keys
│   └── quran_repository.dart      # justifyTargetEm from meta
├── app/l10n/app_ar.arb, app_en.arb   # hint, pack strings
tool/
├── measure_line_widths_test.dart  # also writes meta.justify_target_em
└── build_replica_pack.dart        # NEW (pack phase): layout check, glyphs.json, manifest
test/
├── unit/kashida_test.dart
├── widget/mushaf_typesetting_test.dart
├── widget/reader_page_view_test.dart
└── widget/mushaf_page_renderer_golden_test.dart   # updated goldens
android/app/src/main/AndroidManifest.xml   # INTERNET (pack phase only)
```

**Structure Decision**: everything stays in the existing feature folders. The justification
engine is one pure file, so it can be tested without fonts. Pack code is separate files, added
only in the gated phase.

## Delivery Order

1. **Typesetting** (User Stories 1 and 2): `kashida.dart`, `page_geometry.dart`, renderer,
   measure tool, tests and goldens. Shippable alone.
2. **Paper page** (User Story 3): overlay controls, immersive mode, page details on the page,
   sheet, hint. Shippable alone. It also provides the width that keeps FR-012 at ≥ 100%. If
   User Stories 1–2 ship first, they must keep today's 8 pt padding out of the content width
   to stay ≥ 100%; the typesetting test checks it in both configurations.
3. **Spikes S-1 and S-2** (can run any time, need devices and the QUL V2 layout).
4. **Replica pack** (User Story 4): after D3, S-1 and S-2 pass.

## Risks & Open Dependencies

| ID | Risk | Impact | Mitigation |
| --- | --- | --- | --- |
| D3 | KFGQPC permission to redistribute page lettering | **Blocks User Story 4** | Request with D1. Stories 1–3 don't depend on it. |
| D4 | Pack host not chosen | Blocks User Story 4 | Static HTTPS host (for example the project's release storage); URL via `--dart-define`. |
| S-1 | The plain V2 lettering's line breaks may differ from our V4 layout (15 of 289 words differed on a 2-page sample of the API's default layout) | Pack cannot meet FR-017 | Compare full layouts first. If V2 differs: the owner chooses V4 lettering (tajweed colours) or rebuilding the built-in layout from V2. |
| S-2 | WOFF2 may not load on one platform; registered fonts can't be unloaded (memory) | Pack size 93 → 140–200 MB; memory growth | Fall back to gzip TTF; measure memory over 100 pages; cap or switch to path drawing in a later plan. |
| R-1 | Kashida looks mechanical (Amiri's tatweel is a straight bar) | Visual quality | Rules spread kashida at ≤ 2 per point, skip short words. Goldens reviewed by eye. Font swappable when D1 allows KFGQPC Hafs. |
| R-2 | A few lines have too few join points and keep wider gaps | FR-002 on those lines | Counted by test; the count must not grow. Tune priorities if the count is high. |
| R-3 | Immersive mode differs across Android versions and OEMs | Bars flicker or stay | Use `SystemUiMode.immersiveSticky`; restore on route pop and layout switch. Test on API 24 and 35 emulators. |
| R-4 | Font size margin is thin (100.1% on iPhone SE) | FR-012 | Test at 320, 375, 390 and 430 pt. Bands are the tuning knob. |

## Complexity Tracking

> Not violations: listed to justify added complexity under Principle V.

| Item | Why Needed | Simpler Alternative Rejected Because |
| --- | --- | --- |
| Kashida justification engine (`kashida.dart`) | The only way to fill lines like print with Unicode fonts. Gaps alone are the defect (research P1, P2) | Gap-only justification is today's behaviour. Horizontal glyph scaling distorts letters. DigitalKhatt needs a layout engine Flutter lacks. |
| ~~Replica pack download and verification~~ | Withdrawn 2026-10-23: the printed lettering is bundled instead | — |

### Constitution violation (2026-10-23)

| Principle | Violation | Why | Status |
| --- | --- | --- | --- |
| IV. Lean by Default: "Initial store download size MUST stay ≤ 30 MB per platform" (removed by constitution v2.0.0, 2026-10-24; no longer a violation) | The bundled page fonts add **128.4 MB** (604 gzip-compressed TTF files) | Owner decision to bundle the exact printed lettering rather than download it. The Flutter engine cannot load WOFF2 (the 93 MB form), so TTF is required | **Needs a constitution amendment** (`/speckit-constitution`) before release; CI's size check fails until then |
