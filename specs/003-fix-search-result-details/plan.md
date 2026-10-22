# Implementation Plan: Fix Search Result Details

**Branch**: `003-fix-search-result-details` | **Date**: 2026-10-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/003-fix-search-result-details/spec.md`

## Summary

Three fixes to the search screen of feature 001:
1. **Rows show their own ayah.** Result rows keep the previous search's ayah text because rows
   are reused by position. Key each row by its ayah (research S1).
2. **A count that matches the list.** Report ayat and occurrences separately, with correct Arabic
   plurals (research S4).
3. **Whole-word matching with prefixes.** Replace the substring scan with matching on searchable
   words and their prefix-stripped stems (research S3). It is checked on the real data: «يا ايها
   الذين امنوا» gives 89 ayat, «من» no longer matches inside «المؤمنين», and each query takes a
   few milliseconds.

No database, dependency or build-tool changes.

## Technical Context

**Language/Version**: Dart 3.13.5 / Flutter 3.47.7 (pinned in `pubspec.yaml`)

**Primary Dependencies**: unchanged. Flutter SDK, `flutter_localizations`, `intl`; no new
packages.

**Storage**: unchanged. `quran.db` (read-only) provides search text and word offsets; nothing is
written.

**Testing**: `flutter_test` unit tests on the real corpus (`test/unit/search_index_test.dart`,
new); widget tests (`test/widget/search_test.dart`, extended).

**Target Platform**: iOS 15.0+ and Android 7.0 (API 24)+, phones, portrait (as in 001).

**Project Type**: mobile app (single Flutter project, no backend)

**Performance Goals**:
- Search results within 1 s (001 SC-006); each query ≤ 100 ms after the index is built.
- Stems built once per session, ≤ 150 ms (80 ms measured in debug mode on the dev machine).
- 60 fps scrolling through the longest result list.

**Constraints**: offline; Quran text shown verbatim; no change to normalisation; no download
size growth.

**Scale/Scope**: 6,236 ayat, about 77,800 searchable words, about 113,000 stems. One screen
(Search), two files of code, two `.arb` files, and tests.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Pre-research | Post-design |
| --- | --- | --- | --- |
| I. Cross-Platform Parity | Works on iOS and Android | ✅ pure Dart and Flutter widgets | ✅ No platform code. Verified on one iOS and one Android device (quickstart). |
| II. Mobile-First Design | Touch targets, screen readers, font scaling | ✅ layout unchanged | ✅ Summary stays a live region with correct plurals in both languages. Rows unchanged in size. |
| III. Performance (NON-NEGOTIABLE) | ≤ 2 s cold start, 60 fps, ≤ 100 ms feedback | ✅ search runs off the startup path | ✅ Stems are built lazily when search first opens (80 ms measured), not at startup. Queries 2–9 ms. Rows still virtualised. Cold start untouched. |
| IV. Lean by Default | No new dependencies; size | ✅ | ✅ No packages. No database or asset changes. About 3 MB of memory for stems, only while search is open. |
| V. Simplicity | Simplest fix; reuse | ✅ | ✅ The row bug is fixed by keys. The matching rule reuses the existing search text and offsets. Build-time stems and morphology rejected (research S3). |
| Store & privacy | No new permissions or data | ✅ | ✅ None. |

**Result**: PASS. No violations, so Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/003-fix-search-result-details/
├── plan.md              # This file
├── research.md          # S1–S5: bug cause, stale results, matching rule, summary, tests
├── data-model.md        # in-memory search entities and invariants
├── quickstart.md        # automated and manual checks, performance gate
├── contracts/
│   ├── search-matching.md   # the matching rule, examples, regression counts, budgets
│   └── search-screen.md     # summary line, result row, query field
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks; not created here)
```

### Source Code (repository root)

```text
lib/
├── features/search/
│   ├── search_index.dart      # searchable words + stems at load; token matching; per-hit occurrences
│   ├── search_screen.dart     # ValueKey per row; summary line from ayat and occurrences
│   └── arabic_normalizer.dart # unchanged
└── app/l10n/
    ├── app_ar.arb             # searchSummary, searchAyatCount; remove searchResultCount
    └── app_en.arb             # same keys, English
test/
├── unit/search_index_test.dart   # new: contract examples, regression counts, invariants
└── widget/search_test.dart       # extended: 50 query changes, row text vs title, tap, summary
```

**Structure Decision**: changes stay inside the existing `lib/features/search/` folder and the
`.arb` files. No new folders, layers or packages.

## Design Notes

- **Where stems are built**: in `SearchIndex.load`, after `quran.searchCorpus()`. The screen
  already awaits the index future, so the first search simply waits about 80 ms more.
- **Word mapping**: a searchable word's Uthmani word id is found by walking the ayah's word
  offsets once while splitting, with no per-query lookups.
- **Highlight**: `matchedWordIds` keeps its meaning (Uthmani word ids), so the row widget needs
  no change beyond the key.
- **001 docs**: research R7 in feature 001 described substring matching. This feature's
  [search-matching contract](./contracts/search-matching.md) supersedes that part. 001's files are
  left as they are, as a record.

## Risks

| ID | Risk | Impact | Mitigation |
| --- | --- | --- | --- |
| R1 | Prefix stripping creates false matches beyond those listed (for example, «لم» → «كلم») | Extra results for short queries | Accepted in the spec. The 2-letter minimum and the Allah rule remove the worst cases. Regression counts catch drift. |
| R2 | Arabic plural wording reads awkwardly in some counts | Polish | Plural table in research S4; native review of both strings before release. |
| R3 | Stem building is slower on the reference Android phone than measured | First search delay | Budget 150 ms; if exceeded, build stems in an isolate when search opens (no new dependency). **Measured 2026-10-22**: `SearchIndex.load` (corpus query + stems) 169–201 ms in debug tests on the Windows dev machine; queries 2–9 ms. Profile timing on the Galaxy A15 is still to do (tasks T022). |

## Complexity Tracking

> Fill ONLY if Constitution Check has violations that must be justified

None.
