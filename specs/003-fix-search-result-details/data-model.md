# Data Model: Fix Search Result Details

**Feature**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)

No stored data changes. `quran.db` and `user.db` keep their schemas
([001 contracts](../001-quran-mushaf-reader/contracts/quran-db.md)). Everything below lives in
memory while the search screen is open.

## SearchCorpus (existing, `lib/data/quran_repository.dart`)

Unchanged: per ayah, its normalised search text; per word id, its offset into that text.

## SearchableWord (new, in memory)

One space-separated token of an ayah's search text.

| Field | Meaning | Rule |
| --- | --- | --- |
| `wordId` | Uthmani word the token belongs to | the word whose search range contains the token's start |
| `stems` | forms the token can be matched as | the token, plus prefix-stripped forms ([search-matching](./contracts/search-matching.md)) |

- An ayah has an ordered list of searchable words. Ayah-end words have no search text and give no
  searchable words.
- Several searchable words can share one `wordId` («يَٰٓأَيُّهَا» → «يا», «ايها»).
- Built once, when `SearchIndex.load` runs (about 78,000 words and 113,000 stems).

## SearchHit (existing, extended)

One result row.

| Field | Meaning | Rule |
| --- | --- | --- |
| `ayah` | the matching ayah | one hit per ayah, in Mushaf order |
| `matchedWordIds` | Uthmani word ids to highlight | the words of every match in this ayah |
| `occurrences` (new) | matches in this ayah | ≥ 1; one per starting searchable word |

## SearchResults (existing, extended)

| Field | Meaning | Rule |
| --- | --- | --- |
| `query` | normalised query | empty means no search |
| `hits` | rows | Mushaf order |
| `occurrences` | total matches | sum of `hits[*].occurrences`; no overlaps (FR-006) |
| `ayahCount` (new, derived) | number of matching ayat | `hits.length` (FR-006) |

**Invariants** (tested):
- `ayahCount == hits.length`.
- `occurrences == Σ hit.occurrences`, and `occurrences >= ayahCount`.
- Every id in `hit.matchedWordIds` lies in `hit.ayah.firstWordId..lastWordId`, and is never an
  ayah-end word.

## Result row (UI state)

| State | Shows |
| --- | --- |
| loading | title + neutral placeholder (never another ayah's text) |
| loaded | title + the ayah's Uthmani words, matched words highlighted |

A row's identity is its ayah. A row for a different ayah is a new row with its own state
(research S1).
