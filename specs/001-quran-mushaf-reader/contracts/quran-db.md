# Contract: Bundled Quran Database (`assets/db/quran.db`)

- **Producer**: `tool/build_quran_db.dart` (build time).
- **Consumer**: the app, read-only, through `QuranRepository`.
- **Verification**: `tool/verify_quran.dart` (research R10).
- **Compatibility**: the app reads `meta.schema_version` and refuses to open a database with a
  different major version. Any schema change bumps it, and the build script and app change
  together.

## Schema (SQLite)

```sql
CREATE TABLE meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
-- Required keys: schema_version ("1.0"), built_at (ISO-8601), font ("kfgqpc-hafs" | "amiri-quran"),
-- text_source ("tanzil-uthmani" for Amiri | "qul-kfgqpc-hafs"), p98_line_width_em, space_width_em,
-- max_line_width_em (REAL as text, R4), source_<name>_sha256 for each source file,
-- attribution_tanzil ("Tanzil Project — https://tanzil.net"), attribution_qul, attribution_kfgqpc.

CREATE TABLE surahs (
  number         INTEGER PRIMARY KEY,           -- 1..114
  name_ar        TEXT    NOT NULL,
  name_translit  TEXT    NOT NULL,
  ayah_count     INTEGER NOT NULL,
  revelation     TEXT    NOT NULL CHECK (revelation IN ('makki','madani')),
  start_page     INTEGER NOT NULL
);

CREATE TABLE ayahs (
  id             INTEGER PRIMARY KEY,           -- 1..6236
  surah          INTEGER NOT NULL REFERENCES surahs(number),
  ayah           INTEGER NOT NULL,
  page           INTEGER NOT NULL,
  juz            INTEGER NOT NULL,
  hizb_quarter   INTEGER NOT NULL,
  sajdah         INTEGER NOT NULL DEFAULT 0,    -- 0/1
  first_word_id  INTEGER NOT NULL,
  last_word_id   INTEGER NOT NULL,
  search_text    TEXT    NOT NULL,
  UNIQUE (surah, ayah)
);
CREATE INDEX ayahs_page ON ayahs(page);

CREATE TABLE words (
  id             INTEGER PRIMARY KEY,
  surah          INTEGER NOT NULL,
  ayah           INTEGER NOT NULL,
  position       INTEGER NOT NULL,
  text_uthmani   TEXT    NOT NULL,
  is_ayah_end    INTEGER NOT NULL DEFAULT 0,
  search_offset  INTEGER NOT NULL
);

CREATE TABLE mushaf_lines (
  page           INTEGER NOT NULL,              -- 1..604
  line           INTEGER NOT NULL,              -- 1..15
  type           TEXT    NOT NULL CHECK (type IN ('ayah','surah_name','basmallah')),
  centered       INTEGER NOT NULL,
  first_word_id  INTEGER,
  last_word_id   INTEGER,
  surah          INTEGER,
  PRIMARY KEY (page, line)
) WITHOUT ROWID;

CREATE TABLE divisions (
  kind           TEXT    NOT NULL CHECK (kind IN ('juz','hizb_quarter')),
  number         INTEGER NOT NULL,
  start_surah    INTEGER NOT NULL,
  start_ayah     INTEGER NOT NULL,
  start_page     INTEGER NOT NULL,
  opening_words  TEXT    NOT NULL,
  PRIMARY KEY (kind, number)
) WITHOUT ROWID;
```

## Queries the app relies on (performance contract)

| Query | Used by | Budget on reference device |
| --- | --- | --- |
| Lines and words for page *p* (join `mushaf_lines` → `words` by id range) | Mushaf page render, preloading | ≤ 10 ms |
| Ayahs and words for page *p* | flowing layout item | ≤ 10 ms |
| All surahs, all divisions | index tabs (cached in memory after first load) | ≤ 20 ms |
| Page containing (surah, ayah) | go-to, bookmarks, search jump, layout switch | ≤ 2 ms |
| All `search_text` and word offsets | first search (then cached) | ≤ 150 ms |

## Invariants (must pass `tool/verify_quran.dart`)

- Counts: 114 surahs, 6,236 ayahs, 604 pages × ≤15 lines, 30 juz, 240 quarters, 15 sajdah ayahs.
- Every ayah's text, rebuilt from `words`, equals the Tanzil Uthmani reference under the
  documented encoding map. Any other difference fails the build.
- Every word id appears in exactly one `ayah` line, in ascending order across the Mushaf.
- No `basmallah` line for surah 9. Surah 1 has no separate `basmallah` line.
