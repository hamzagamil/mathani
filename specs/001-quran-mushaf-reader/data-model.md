# Data Model: Quran Mushaf Reader

**Feature**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)

There are two stores (research R8):
- **`quran.db`**: bundled and read-only. It is built at build time from licensed sources (R2).
  Its exact schema is in [contracts/quran-db.md](./contracts/quran-db.md).
- **`user.db`**: on the device, read and write. It holds user data only. Its exact schema is in
  [contracts/user-data.md](./contracts/user-data.md).

## Quran content (read-only, `quran.db`)

### Surah
| Field | Type | Rules |
| --- | --- | --- |
| number | int | 1–114, unique, Mushaf order |
| name_ar | text | as in the Mushaf, e.g. «البقرة» |
| name_translit | text | English interface, e.g. "Al-Baqarah" (FR-025) |
| ayah_count | int | sums to 6,236 across all surahs |
| revelation | enum `makki` / `madani` | |
| start_page | int | 1–604 |

### Ayah
| Field | Type | Rules |
| --- | --- | --- |
| surah, ayah | int, int | composite key; ayah 1..surah.ayah_count |
| id | int | 1–6,236, global order |
| page | int | page where the ayah **starts** |
| juz | int | 1–30 |
| hizb_quarter | int | 1–240 |
| sajdah | bool | exactly 15 true (FR-007) |
| first_word_id, last_word_id | int | contiguous range in `Word` |
| search_text | text | normalised imla'i text (R7); never displayed |

### Word
| Field | Type | Rules |
| --- | --- | --- |
| id | int | global order, 1..N |
| surah, ayah, position | int | position starts at 1 within the ayah |
| text_uthmani | text | exact KFGQPC Hafs text; verbatim (FR-002) |
| is_ayah_end | bool | true for the ayah-end marker token (rendered with Eastern Arabic numerals, FR-005) |
| search_offset | int | character offset into the ayah's `search_text`, so search hits map to words (R7) |

### MushafLine
| Field | Type | Rules |
| --- | --- | --- |
| page, line | int, int | page 1–604, line 1–15, unique together |
| type | enum `ayah` / `surah_name` / `basmallah` | |
| centered | bool | true means centred, false means justified |
| first_word_id, last_word_id | int? | required for `ayah`, null otherwise |
| surah | int? | required for `surah_name` and `basmallah` |

Invariants (checked by `tool/verify_quran.dart`, R10):
- Every word belongs to exactly one `ayah` line.
- Lines are in word order across pages 1–604.
- There is no `basmallah` line before surah 9.
- Surah 1's basmala is its ayah 1 and is rendered as a normal `ayah` line.

### Division (juz / hizb quarter)
| Field | Type | Rules |
| --- | --- | --- |
| kind | enum `juz` / `hizb_quarter` | 30 juz and 240 quarters |
| number | int | 1–30 or 1–240 |
| start_surah, start_ayah | int, int | |
| start_page | int | |
| opening_words | text | first words of the start ayah, shown in the Ajza' index (FR-011) |

Derived: hizb = ⌈quarter / 4⌉; juz of a quarter = ⌈quarter / 8⌉.

## User data (read/write, `user.db`)

### Bookmark (FR-014, FR-015)
| Field | Type | Rules |
| --- | --- | --- |
| id | int | auto |
| surah, ayah | int, int | unique together: adding an existing ayah is a no-op that returns the existing row |
| page | int | Mushaf page of the ayah (denormalised for listing) |
| created_at | int | Unix ms; list ordered newest first |

When the user bookmarks a *page* rather than an ayah, the bookmark is stored against the first
ayah that starts on that page.

### ReadingState (FR-013, R6), a single row
| Field | Type | Rules |
| --- | --- | --- |
| anchor_surah, anchor_ayah | int, int | default 1:1 (Al-Fatiha, page 1) |
| updated_at | int | Unix ms |

Write policy: debounced 500 ms on page change or scroll settle, plus an immediate write when the
app lifecycle state becomes `paused` or `inactive`.

### Preferences (FR-016–FR-019, FR-025)
| Key | Values | Default |
| --- | --- | --- |
| layout | `mushaf` / `flowing` | `mushaf` |
| theme | `system` / `day` / `night` | `system` |
| flow_font_size | 18–34 (int, pt) | 24 |
| keep_screen_on | bool | `false` |
| language | `system` / `ar` / `en` | `system` (`system` resolves to `ar` for Arabic device locales, `en` otherwise) |

Values outside the allowed set are reset to the default when read.

## State: reader view

```text
           ┌─────────── toggle layout (anchor kept) ───────────┐
           ▼                                                   │
   [Mushaf layout] ──long-press word──▶ [Ayah selected] ──copy/share/bookmark/dismiss──┐
           ▲  │                                ▲                                       │
           │  └─open index / go-to / search ──▶ [Navigating] ──target chosen──▶ jump to page, highlight ayah 1.5 s
           │                                                                           │
           └───────────────────────────────────────────────────────────────────────────┘
   (the flowing layout has the same states; on every change the anchor ayah is saved)
```
