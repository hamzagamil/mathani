# Data Model: Print-Like Mushaf Page

**Feature**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)

`quran.db` does not change. `user.db` gains two preference keys in its existing key-value
`preferences` table (no schema change). The replica pack adds files on disk. Everything else lives
in memory during layout.

## In memory (layout)

### JoinPoint

A place inside a word where a tatweel may be inserted (research P2).

| Field | Meaning | Rule |
| --- | --- | --- |
| `offset` | index in the word's display string after which tatweel goes | after a letter's combining marks |
| `priority` | 0 = after «س ش ص ض», 1 = before the last letter, 2 = other | lower first |

Excluded: lam followed by an alef form (ligature); any join in the name of Allah; next to an
existing tatweel; words of 2 letters or fewer; ayah-end markers.

### LineJustification (output of `justifyLine`)

| Field | Meaning | Rule |
| --- | --- | --- |
| `tatweels` | per word, per join point: number of tatweels | ≤ 4 per point; round-robin across words; best point first |
| `gap` | space between words, in em | 0.5 × space ≤ gap ≤ 1.5 × space, unless the line has too few points |
| `scale` | shrink factor for the line | 0.95 ≤ scale ≤ 1; < 1 only after gaps reach 0.5 × space |
| `width` | resulting width in em | equals the target (± 0.01 em) for justified lines |

Centred lines (`MushafLine.centered`) are not justified: gap = 1 × space, no tatweel, scale 1.

### PageGeometry (replaces `MushafLayoutMetrics`)

| Field | Meaning | Rule |
| --- | --- | --- |
| `textBlock` | rectangle holding the 15 lines | height ÷ width = 1.77; centred; as large as fits |
| `fontSize` | Quran font size | `textBlock.width ÷ targetEm` (targetEm = 22.27 for Amiri Quran) |
| `lineHeight` | line pitch | `textBlock.height ÷ 15` |
| `headerBand`, `footerBand` | page details above and below the block | 0.6 × lineHeight each, inside the sheet; text at 0.32 × lineHeight |
| `markerMargin` | space for hizb and sajdah marks | outside the block on the right, within the sheet |

`targetEm` is computed once per font at build time by `tool/measure_line_widths_test.dart` (widest
line with gaps at 0.6 × space, then
× 0.95) and stored as `meta.justify_target_em`. It falls back to a constant if absent.

## Preferences (user.db `preferences`, existing table)

| Key | Values | Default | Used by |
| --- | --- | --- | --- |
| `controls_hint_shown` | `true` / `false` (as `keep_screen_on`) | `false` | one-time "tap to show controls" hint (FR-010) |
| `lettering` | `builtin` / `replica` | `builtin` | which lettering the Mushaf uses (FR-019) |

`ReaderPreferences` gains `lettering` (enum `Lettering { builtin, replica }`). `replica` takes
effect only while the pack is `installed`. Otherwise the app uses `builtin` and leaves the stored
value alone.

## Replica Pack (files on disk, optional)

Located in the app support directory under `replica/<version>/`.

| File | Content |
| --- | --- |
| `manifest.json` | `version`, `edition` (e.g. `kfgqpc-v2-1421`), `format` (`woff2` or `ttf.gz`), `files[]` with `name`, `bytes`, `crc32`, and `totalBytes` |
| `glyphs.json` | word id → glyph string, for all words including ayah-end markers |
| `p001…p604.<ext>` | one font per page |

### Pack state

```text
notInstalled ──download──▶ downloading ──all files ok──▶ verifying ──ok──▶ installed
     ▲                         │  ▲                             │
     │                     stop│  │resume                   fail│
     │                         ▼  │                             ▼
     └────────delete─────── paused ◀────────repair────────── damaged
installed ──delete──▶ notInstalled
installed ──newer manifest available──▶ updateAvailable (still usable)
```

- `downloading` and `paused` keep finished files. Unfinished files are `.part` files and are
  deleted on resume.
- `verifying` checks every file's size and CRC32 against the manifest.
- `damaged`: any check fails at startup or on load. The app uses `builtin` and offers repair,
  which re-downloads only the bad files.
- The state is derived from the files on disk at startup. Nothing extra is stored in `user.db`.

## Unchanged

`Word`, `MushafLine`, `MushafPage`, `Ayah` and all `quran.db` tables keep their shape. `Word.text`
is never modified: kashida exists only in display strings.
