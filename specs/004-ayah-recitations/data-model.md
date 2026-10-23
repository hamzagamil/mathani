# Data Model: Ayah-by-Ayah Recitations

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

Three places hold data:
- `quran.db` (bundled, read-only) gains the recitation catalogue.
- `user.db` gains one preference key.
- Audio files live on disk, in a cache and in a downloads directory. Download state is derived
  from those files, not stored.

## Bundled: `quran.db`

Schema and build: [contracts/recitation-catalogue.md](./contracts/recitation-catalogue.md).

### Reciter

| Field | Type | Rules |
| --- | --- | --- |
| `id` | text | Stable slug: `husary`, `minshawy`. Used in preferences, file paths and the catalogue. It never changes once released. |
| `name_ar` | text | «محمود خليل الحصري», «محمد صديق المنشاوي» |
| `name_en` | text | "Mahmoud Khalil Al-Husary", "Mohamed Siddiq El-Minshawi" |
| `short_ar`, `short_en` | text | Bar chip names: «الحصري» / "Al-Husary", «المنشاوي» / "El-Minshawi". In the catalogue so a new reciter needs no new strings. |
| `style` | text | `murattal` (the only value in this release; the column lets Mujawwad be added later) |
| `base_url` | text | e.g. `https://everyayah.com/data/Husary_64kbps` |
| `mirror_url` | text | e.g. `https://mirrors.quranicaudio.com/everyayah/Husary_64kbps` |
| `bitrate_kbps` | int | 64 or 128; shown nowhere, kept for the record |
| `sort` | int | List order. Al-Husary is first and is the default (FR-004). |

Rule: a reciter row exists only if its catalogue has all 6,236 ayat. The build fails otherwise
(FR-002).

### Ayah Recording (catalogue entry)

| Field | Type | Rules |
| --- | --- | --- |
| `reciter` | text | → Reciter.id |
| `surah`, `ayah` | int | 1..114, 1..ayah count. Exactly 6,236 rows per reciter. |
| `bytes` | int | Exact file size. A local file of another size is damaged (FR-031). |

The URL is derived: `<base_url or mirror_url>/<SSS><AAA>.mp3`. The **basmala** has no row of its
own. It is the reciter's 1:1 recording (research R2).

Derived: `surahBytes(reciter, surah)` is the sum of `bytes` for that surah. It is shown before
downloading (FR-028). When the surah has a basmala, the 1:1 file's size is added unless the
reciter's `basmala.mp3` is already saved (see below).

## User data: `user.db`

The `preferences` table gains one key (schema version unchanged; key-value table from 001):

| Key | Values | Default | Used for |
| --- | --- | --- | --- |
| `reciter` | a Reciter.id | `husary` | the chosen reciter (FR-004) |

An unknown value, for example a reciter removed in a later release, falls back to the default.
`ReaderPreferences` gains `reciter` (String).

## Audio files on disk

Layout and rules: [contracts/audio-storage.md](./contracts/audio-storage.md).

| Store | Path | Limit | Cleared by |
| --- | --- | --- | --- |
| Recent cache | `<cache>/recitations/<reciter>/<SSS><AAA>.mp3` | 100 MB, LRU by file modification time (touched on play) | Settings › "Clear recent recitations", or the OS under storage pressure |
| Downloads | `<app support>/recitations/<reciter>/<SSS>/<AAA>.mp3` | none | Settings › Downloads (delete), or uninstall |

The basmala for a downloaded surah is stored as `<app support>/recitations/<reciter>/basmala.mp3`
(a copy of 1:1). Deleting all of a reciter's downloads removes it.

### Surah Download (derived)

| Field | Source |
| --- | --- |
| `reciter`, `surah` | directory names |
| `savedBytes` | sum of sizes of files whose size matches the catalogue |
| `totalBytes` | `surahBytes(reciter, surah)` |
| `state` | see below |

```text
            enqueue                    all files valid
  absent ───────────► queued ──► downloading ─────────────► complete
    ▲                   │  ▲          │  │                      │
    │        cancel     │  │ resume   │  │ network lost, app    │ delete
    │◄──────────────────┘  │          │  │ suspended, no space  │
    │                      │          ▼  ▼                      │
    │   delete (partial)   └─────── stopped (partial) ◄─────────┘ a file found damaged
    └────────────────────────────────────┘                        (becomes partial)
```

- `absent`: no files. `complete`: every ayah file present with its catalogue size **and**, when the surah has a basmala item (not 1, not 9), a valid `basmala.mp3` (FR-031).
- `stopped` (shown as "Resume"): some valid files. Named `stopped` so it is not confused with a paused recitation. It is the state of any partial surah after a
  restart, because the queue is not persisted.
- `queued` and `downloading` exist only in memory, in the `DownloadQueue`.
- On entering `complete`, the surah gets a done mark in the Surahs index (FR-032).

## In memory: Recitation Session

Owned by `RecitationController` and never persisted (spec assumption). Contract:
[contracts/recitation-playback.md](./contracts/recitation-playback.md).

| Field | Type | Meaning |
| --- | --- | --- |
| `reciter` | Reciter | the voice of this session (normally the preference; see the offline switch edge case) |
| `item` | `RecitedItem` | `(surah, ayah)` or `(surah, basmala)` being recited |
| `status` | enum | `loading`, `playing`, `paused`, `error`, `ended` |
| `error` | enum? | `offline`, `notDownloaded`, `fetchFailed` (with the item it is stuck on) |
| `following` | bool | whether the reader follows the item (FR-013, FR-014) |
| `followSerial` | int | the `ReaderController.jumpSerial` produced by the last follow jump |

No session means no recitation bar. `stop` and the end of the Quran end the session (after
`ended` has shown).

### Recited item order

The next item after `(s, a)`:
- `(s, a + 1)` if `a < ayahCount(s)`;
- otherwise, for `s < 114`: `(s + 1, basmala)`, except when `s + 1` is 9 (At-Tawbah): `(9, 1)`;
- otherwise (114:6): the end of the Quran.

The next item after `(s, basmala)` is `(s, 1)`. Starting at ayah 1 of a surah that has a basmala
starts at its basmala item (FR-008). Al-Fatiha has no basmala item; its 1:1 is ayah 1.

The previous item skips basmala items. Previous from `(s, 1)` or `(s, basmala)` goes to the last
ayah of `s − 1`, and from 1:1 it stays on 1:1. Rapid next and previous taps are merged: only the
last one loads.

## Reused from features 001 and 002

- `AyahRef`, `Ayah.page`, `QuranRepository.pageOf`, and the basmala line positions in
  `MushafPage.lines` (`LineType.basmallah`, `surah`).
- The highlight palette gets `recited`: the brand's `secondarySoft` at a stronger alpha, so it is
  distinct from the 1.5 s jump highlight and from selection, in day and night.
