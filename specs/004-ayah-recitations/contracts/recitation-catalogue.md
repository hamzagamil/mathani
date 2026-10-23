# Contract: Recitation Catalogue

How the list of reciters and the size of every ayah recording get into `quran.db`, and how URLs
are formed. Research: R1, R2, R6.

## Build

```text
dart run tool/build_recitation_manifest.dart [--reciter husary|minshawy] [--concurrency 4]
  → tool/sources/recitations/<reciter>.json     (sizes; pinned in tool/sources.lock.json)
dart run tool/build_quran_db.dart
  → assets/db/quran.db with the tables below
```

`build_recitation_manifest.dart`:
- Reads the reciter definitions (id, names, style, base and mirror URLs, bitrate, sort) from
  `tool/recitations.json` (committed; `tool/sources/` is gitignored).
- Sends a `HEAD` request for `<base>/<SSS><AAA>.mp3` for every ayah of the 114 surahs, 4 at a
  time. A throttled or failed request is retried up to 3 times with backoff (1 s, 4 s, 16 s),
  then tried once on the mirror.
- Requires a `200` status, `Content-Type: audio/mpeg` and `Content-Length > 0`. It **exits
  non-zero** if any ayah fails after retries, listing them (FR-002, SC-003).
- Writes `{"reciter": "...", "files": {"1:1": 42003, ...}}` with 6,236 entries, keys in Mushaf
  order.

`build_quran_db.dart` refuses to build if a manifest is missing or does not have 6,236 entries.

## Schema (added to `quran.db`)

```sql
CREATE TABLE reciters (
  id            TEXT PRIMARY KEY,         -- 'husary', 'minshawy'
  name_ar       TEXT NOT NULL,
  name_en       TEXT NOT NULL,
  short_ar      TEXT NOT NULL,            -- bar chip: 'الحصري'
  short_en      TEXT NOT NULL,            -- bar chip: 'Al-Husary'
  style         TEXT NOT NULL,            -- 'murattal'
  base_url      TEXT NOT NULL,            -- no trailing slash
  mirror_url    TEXT NOT NULL,
  bitrate_kbps  INTEGER NOT NULL,
  sort          INTEGER NOT NULL
) WITHOUT ROWID;

CREATE TABLE recitation_files (
  reciter  TEXT NOT NULL REFERENCES reciters(id),
  surah    INTEGER NOT NULL,
  ayah     INTEGER NOT NULL,
  bytes    INTEGER NOT NULL,
  PRIMARY KEY (reciter, surah, ayah)
) WITHOUT ROWID;
```

New `meta` keys: `recitations_built_at` (ISO date), and `source_recitations_<reciter>_sha256`
for each manifest.

## Rows in this release

| id | name_ar | name_en | short_ar | short_en | style | base_url | mirror_url | kbps | sort |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| husary | محمود خليل الحصري | Mahmoud Khalil Al-Husary | الحصري | Al-Husary | murattal | `https://everyayah.com/data/Husary_64kbps` | `https://mirrors.quranicaudio.com/everyayah/Husary_64kbps` | 64 | 1 |
| minshawy | محمد صديق المنشاوي | Mohamed Siddiq El-Minshawi | المنشاوي | El-Minshawi | murattal | `https://everyayah.com/data/Minshawy_Murattal_128kbps` | `https://mirrors.quranicaudio.com/everyayah/Minshawy_Murattal_128kbps` | 128 | 2 |

## Repository API (`QuranRepository`)

Loaded with the existing startup query batch. The reciters table is tiny. File sizes are read
lazily per surah, and never on the startup path (Principle III).

| Member | Returns |
| --- | --- |
| `reciters` | `List<Reciter>` in `sort` order |
| `reciter(String id)` | `Reciter?` |
| `recordingBytes(String reciter, int surah)` | `Future<List<int>>`: bytes for ayat 1..n |
| `surahDownloadBytes(String reciter, int surah)` | `Future<int>`: sum, plus 1:1 when the surah has a basmala |

## URLs

`urlFor(reciter, surah, ayah, {mirror = false})` returns
`'${mirror ? r.mirrorUrl : r.baseUrl}/${pad3(surah)}${pad3(ayah)}.mp3'`. The basmala is
`urlFor(r, 1, 1)`.

Adding a reciter later means: a row in `tool/recitations.json`, run both tools, and add the attribution
in `docs/licences.md` and the About screen. No app code changes.
