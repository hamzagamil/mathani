# Data Model: Home Screen and Watch Widgets

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

Nothing here is stored in `user.db`. Everything is a derived copy that the app rebuilds from the
state of Prayer Times (specs/009), the personal khatma (specs/014) and the reader (specs/001). The
JSON layout is in [contracts/widget-snapshot.md](contracts/widget-snapshot.md).

## WidgetSnapshot

| Field | Type | Rules |
| --- | --- | --- |
| `v` | int | Schema version, `1`. Native readers ignore a snapshot with an unknown higher major version and show the "not set up" state. |
| `madeAtUtc` | int (ms) | When it was built. |
| `lang` | `ar` \| `en` | The app's language. |
| `rtl` | bool | True for Arabic. |
| `labels` | Labels | All fixed text, already in `lang` with the app's numerals. |
| `prayer` | PrayerBlock \| null | Null when no place is set (the not set up state). |
| `quran` | QuranBlock | Always present. |

## PrayerBlock

| Field | Type | Rules |
| --- | --- | --- |
| `place` | string | Place name shown on every prayer widget (1–80 chars). |
| `entries` | PrayerEntry[] | Today and 7 more days: up to 40 items (a time the calculator cannot give is left out), ascending, each `atUtc` unique. Sunrise is excluded. |
| `days` | Day[] | 8 items: `startUtc`, `label` (for example "Today", "الجمعة"). |
| `validUntilUtc` | int (ms) | The last entry's `atUtc` + 60 s. After it, every surface shows `labels.openToUpdate` (FR-008). |

**PrayerEntry**: `kind` (`fajr|dhuhr|asr|maghrib|isha`), `atUtc` (ms), `name` (localized, with
"الجمعة"/"Jumu'ah" on Fridays for Dhuhr as specs/015), `time` (formatted local time at the place, in
the app's numerals).

**Next prayer at moment *t*** is the first entry with `atUtc > t`. It changes exactly at each
`atUtc`. Every platform implements this one rule.

## QuranBlock

| Field | Type | Rules |
| --- | --- | --- |
| `mode` | `wird` \| `wirdDone` \| `continue` \| `start` | `wird`: an active khatma has a wird waiting. `wirdDone`: today's wird is read. `continue`: no active khatma and the reader has a last place. `start`: neither. |
| `title` | string | Main line, for example "Today's wird" / "Continue reading". |
| `line1`, `line2` | string | `wird`: from "Al-Baqarah 142" to "Al-Baqarah 202". `continue`: surah name, then "Page 23 · Juz 2". |
| `progress` | KhatmaProgress \| null | Present when a personal khatma is active or paused. |
| `link` | string | Tap target (contracts/widget-surfaces.md). |

**KhatmaProgress**: `percent` (0–100, int), `pagesRead`, `pagesTotal`, `text` (for example "41%
· 248 of 604 pages"), `todayRead` (bool), `paused` (bool).

**Never included**: group khatma data, bookmark notes, any other person's text (FR-003).

## Labels

`next`, `inPrefix`/`inSuffix` (around the countdown), `todaysWird`, `todayWirdDone`,
`continueReading`, `startReading`, `setPlace` ("Set your place in Prayer Times"), `setPlaceWatch`
("Set a place in Mathani on your phone"), `openToUpdate`, `khatma`, `noKhatma`, `paused`, and
`a11yNext` ("Next prayer: {name} at {time}"), whose `{name}` and `{time}` native code fills. The
live countdown is read by the system next to it.

## WatchCopy

A subset sent to the watches (contracts/watch-sync.md): `v`, `madeAtUtc`, `lang`, `rtl`, `labels`
(watch subset), `prayer` (all fields), and `khatma` (`percent`, `todayRead`, `paused`, `text`) or
null. It is kept on the watch until a newer `madeAtUtc` arrives; older copies are dropped.

## State transitions

```text
Quran widget:   start ──first read──▶ continue ──khatma started──▶ wird ⇄ wirdDone (daily)
                                         ▲                           │
                                         └──khatma ended/finished────┘   (paused: continue + progress.paused)
Prayer widget:  not set up ──place set──▶ entries (next moves at each atUtc) ──validUntil passed──▶ openToUpdate
                       ▲                                                          │
                       └──place removed──────────── app opened ◀──────────────────┘ (fresh snapshot)
```
