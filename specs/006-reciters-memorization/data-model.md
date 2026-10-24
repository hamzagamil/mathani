# Data Model: All EveryAyah Reciters and Memorization Mode

**Feature**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)

What is stored where:
- **`quran.db`** (bundled, read-only) gains reciters and changes how recording sizes are stored.
- **`user.db`** gains one preference key.
- **Model files** live in the app support directory.
- **Memorization** state lives only in memory. Nothing about a session, and no audio, is ever
  written (FR-019, FR-026).

## Reciter (changed, `quran.db › reciters`)

Same table as feature 004 ([recitation-catalogue](../004-ayah-recitations/contracts/recitation-catalogue.md)),
with three new columns. Research: R0, R18.

| Field | Change |
| --- | --- |
| `id` | 51 rows. `husary` and `minshawy` are unchanged (FR-006); new ids are lower-case slugs (`alafasy`, `abdulbasit_mujawwad`, `bandar_baleela`, …) |
| `source` | **New**. `everyayah` \| `qul_ayah` \| `qul_surah`. Shown in About credits; decides how URLs are formed |
| `file_pattern` | **New**. `{sss}{aaa}.mp3` for the two ayah sources; for `qul_surah`, the host's file name with `{sss}` or `{s}` (`{sss}.mp3`, `{s}.mp3`) |
| `basmala_in_ayah1` | **New**. 0 \| 1. 1 for `qul_surah`: the basmala is inside ayah 1's clip, so no separate basmala item plays (R18) |
| `mirror_url` | Now nullable: QUL hosts have no mirror |
| `style` | `murattal` \| `mujawwad` \| `muallim` (research R3) |
| `short_ar`, `short_en` | Include the style when the same reciter has more than one entry («الحصري · معلّم») |
| `sort` | Kept for the build's order; the list sorts by name in the interface language (R5) |

Validation (build tool):
- ids are unique, match `^[a-z0-9_]+$`, and are never renamed once released;
- both names are non-empty;
- `style` is one of the three values;
- `base_url` + `file_pattern` is unique;
- `qul_surah` rows have `basmala_in_ayah1 = 1` and a CBR check on every surah (R19).

## Recording sizes (replaces `recitation_files`)

```sql
CREATE TABLE recitation_sizes (
  reciter      TEXT NOT NULL REFERENCES reciters(id),
  surah        INTEGER NOT NULL,       -- 1..114
  sizes        BLOB NOT NULL,          -- ayahCount(surah) × 3 bytes, little-endian, ayah order
  range_start  INTEGER,                -- qul_surah only: byte of the first audio frame
  PRIMARY KEY (reciter, surah)
) WITHOUT ROWID;
```

- 51 × 114 = 5,814 rows.
- `length(sizes) == 3 × ayahCount(surah)` for every row. The build fails otherwise, and also
  fails if any size is ≥ 16,777,216 or 0.
- **Ayah sources**: `sizes` are file sizes and `range_start` is NULL.
- **`qul_surah`**: `sizes` are the exact clip lengths, so ayah `a` is bytes
  `range_start + Σ sizes[1..a−1]` up to and excluding `+ sizes[a]`. The sum of all sizes plus
  `range_start` equals the surah file's length (build check).
- `QuranRepository.recordingBytes(reciter, surah)` decodes the BLOB into `List<int>` and caches
  it per (reciter, surah), as before. No caller changes.
- New: `QuranRepository.clipRange(reciter, surah, ayah)` returns `(start, endExclusive)` for
  `qul_surah`, and null otherwise.
- `recitation_files` is dropped.

## Reader Preferences (changed, `user.db › preferences`)

| Key | Values | Default | Notes |
| --- | --- | --- | --- |
| `reciter` | any `reciters.id` | `husary` | Unchanged. An unknown id falls back to `husary`, as before |
| `mistake_signal` | `vibrate` \| `sound` \| `none` | `vibrate` | New (FR-015). An unknown value reads as `vibrate` |

`ReaderPreferences` gains `mistakeSignal: MistakeSignal`, with `copyWith` and persistence through
the existing key/value table. No schema migration is needed.

## Recognition Model (new, files)

`<app support>/asr/tarteel-tiny-v1/`:

| File | Size (estimated) | Check |
| --- | --- | --- |
| `encoder.int8.onnx` | ≈ 12 MB | SHA-256 pinned in `asr_model.dart` |
| `decoder.int8.onnx` | ≈ 28 MB | SHA-256 pinned |
| `tokens.txt` | ≈ 0.8 MB | SHA-256 pinned |
| `silero_vad.onnx` | ≈ 0.6 MB | SHA-256 pinned |

States (derived from the files on disk, as for surah downloads; there is no table):

```text
absent ──download──▶ downloading(bytes, total) ──all files verified──▶ ready
   ▲                      │  interrupted / failed                        │
   │                      ▼                                              │ delete (Settings)
   └──── delete ◀── partial (resumable: .part files kept) ◀──────────────┘
```

- `ready` only when all four files exist and their hashes match. The hashes are checked once
  after download, and again only when a load fails.
- A version bump (new folder name) leaves `ready` false until the new model is downloaded. The
  old folder is deleted after the new one is ready.
- The folder is excluded from iCloud and Android backup (`excludeFromBackup`, feature 004).

## Memorization Range (in memory)

| Field | Type | Rule |
| --- | --- | --- |
| `surah` | int 1..114 | — |
| `from` | int | 1 ≤ from ≤ ayahCount(surah) |
| `to` | int | from ≤ to ≤ ayahCount(surah) (FR-009) |

Defaults (FR-009):
- **From the reading screen**: the surah where the current page starts. `from` is the first ayah
  of that surah that starts on the page, and `to` is its last ayah that starts on the page.
- **From a long-press**: that ayah to the last ayah of its surah that starts on its page.

## Memorization Session (in memory, `MemorizationController`)

| Field | Type | Notes |
| --- | --- | --- |
| `range` | Memorization Range | Fixed for the session |
| `expected` | AyahRef? | The ayah being recited; null once the range is done |
| `cursor` | int | Index of the next reference word in `expected` |
| `ayat` | `Map<AyahRef, AyahProgress>` | One per ayah of the range |
| `phase` | `preparing` \| `listening` \| `paused(reason)` \| `ended` | |
| `pausedReason` | `user` \| `silence` \| `interruption` \| `background` \| `routeLost` | Drives the paused message |

`AyahProgress`:

| Field | Type | Notes |
| --- | --- | --- |
| `outcome` | `hidden` \| `noMistake` \| `corrected` \| `hinted` \| `revealed` \| `notReached` | |
| `mistakes` | `List<AyahMistake>` | |
| `hints` | `Set<int>` | Word positions shown with "Next word" |

`outcome` transitions (FR-014 to FR-016, FR-024; the weakest outcome wins):

```text
hidden ──all words matched, no mistake, no hint──────────▶ noMistake
hidden ──all words matched, ≥1 mistake, no hint──────────▶ corrected
hidden ──all words matched or hinted, ≥1 hint────────────▶ hinted
hidden ──"Show this ayah"────────────────────────────────▶ revealed
hidden ──session ends before this ayah became expected───▶ notReached
hidden (expected) ──session ends mid-ayah────────────────▶ notReached (*)
```

(*) An ayah the reader was in the middle of when they ended counts as not reached. It is not
scored and is shown as "not finished" in the review. This follows the spec's rule that ayat not
reached do not lower the score.

`AyahMistake`:

| Field | Type | Notes |
| --- | --- | --- |
| `position` | int | 1-based word position in the ayah (FR-025) |
| `kind` | `missed` \| `wrong` \| `added` | `added` sits before `position` |
| `heard` | String? | Normalised token heard, for `wrong`/`added`. Kept only in memory, for the review |

## Session Result (in memory)

| Field | Rule (FR-023, FR-024) |
| --- | --- |
| `reached` | count of outcomes ≠ `notReached` |
| `noMistake`, `corrected`, `hinted`, `revealed`, `notReached` | counts |
| `score` | `round(100 × (1·noMistake + 0.5·corrected + 0.25·hinted + 0·revealed) / reached)`; `null` when `reached == 0` (shown as "—") |
| `review` | the range's ayat with their `AyahProgress` |

Rounding is half away from zero (`(x).round()` in Dart). Check: User Story 3's example gives
5.75 / 8 × 100 = 71.875, which rounds to 72.

The result is discarded when its screen closes (FR-026). "Try again" builds a new session with
the same range.
