# Data Model: Prayer Times and Athan

**Spec**: [spec.md](./spec.md) | **Research**: [research.md](./research.md) | **Contracts**:
[location API](./contracts/location-api.md), [alerts and UI](./contracts/prayer-ui-and-reminders.md)

## Persistence

One JSON document, `schemaVersion: 2`, stored as the value of key `prayer.state` in the
`preferences` table of `user.db` (R6). It is parsed only when Prayer Times opens or the
post-first-frame refill runs. Schedules and alert lists are derived, never stored in Dart.

A missing value means "not set up". A value that fails to parse, or an unknown
`schemaVersion`, is treated as not set up. The stored value is kept untouched until the reader
saves a new place, so a newer app version's data is not destroyed by an older one.

Android keeps a derived copy of the pending alert list in `SharedPreferences` so alarms can be
restored after a reboot without starting Flutter. It is rebuilt from the JSON document on every
refill.

## PrayerState (root)

| Field | Type | Rules |
| --- | --- | --- |
| `schemaVersion` | int | `2` |
| `places` | list of Place | Saved places, unique `id`. May be empty. |
| `myLocation` | Place or null | The latest "My location" result. Not in `places`. |
| `current` | `"myLocation"` or a place `id` | Which place drives the home schedule and alerts. Must point to an existing place, or to `myLocation` when that is non-null. |
| `alerts` | AlertSettings | Shared by all places. |
| `generation` | int | Increases on every change that affects alerts. Native alerts carrying an older generation are ignored. |
| `movedNotice` | string or null | City name to show once in a "Moved to {city}" message, then cleared. |

"Not set up" means `places` is empty and `myLocation` is null. In that state Prayer Times shows
the first-time screen and no alerts are scheduled.

## Place

| Field | Type | Rules |
| --- | --- | --- |
| `id` | string | Random, stable. |
| `name` | string | 1–80 characters, trimmed, no control characters. Defaults to the city name. Renamable for saved places. |
| `city`, `region` | string | From search or resolve. May be empty for an unnamed spot. |
| `countryCode` | string | ISO 3166-1 alpha-2, or empty. |
| `latitude`, `longitude` | double | Rounded to 2 decimal places. Range −90..90 and −180..180. |
| `timezoneId` | string | Valid IANA ID. Never the phone's zone as a guess. |
| `source` | `location` / `search` / `estimate` | How it was set. Shown on the place. |
| `calculation` | CalculationSettings | Per place (FR-016). |

## CalculationSettings

| Field | Type | Rules |
| --- | --- | --- |
| `method` | enum, 11 values | `muslim_world_league`, `egyptian`, `umm_al_qura`, `karachi`, `isna`, `dubai`, `kuwait`, `qatar`, `singapore`, `turkey`, `moonsighting_committee`. |
| `methodChosen` | bool | `false` while the method is the automatic country suggestion. When "My location" moves country, a `false` method is replaced by the new suggestion (R4). |
| `asr` | `standard` / `hanafi` | Default `standard`. |
| `highLatitudeRule` | `middle_of_night` / `seventh_of_night` | Default from latitude: `seventh_of_night` above 48°, else `middle_of_night`. |
| `offsets` | map of prayer → int | Keys: `fajr`, `dhuhr`, `asr`, `maghrib`, `isha`. Values −30..30 minutes. Missing key = 0. |

## AlertSettings

| Field | Type | Rules |
| --- | --- | --- |
| `prayers` | set of `fajr` / `dhuhr` / `asr` / `maghrib` / `isha` | Empty at first (FR-017). Never `sunrise`. |
| `sound` | recitation id, `tone` or `silent` | Default `tone` while the catalogue is empty, otherwise the first recitation. If the stored id leaves the catalogue, fall back to `tone`. |
| `athan` | `opening` / `full` | Default `opening`. Ignored for `tone` and `silent`. |
| `qiyam` | bool | Default `false` (FR-027). |

Permission states, exact-alarm access and download status are runtime facts read from the
platform. They are not stored.

## DaySchedule (derived)

Produced by `PrayerCalculator.schedule(place, localDate)` with no network.

- `placeId`, `localDate` (in the place's zone), `timezoneId`.
- `events`: Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha. Each has:
  - `atUtc`: null when unavailable.
  - `status`: `normal`, `adjusted` or `unavailable`.
  - `adjustedBy`: `highLatitude`, `offset` or both.
- `qiyamUtc`: Maghrib + ⅔ × (next day's Fajr − Maghrib), rounded to the minute. Null when either
  boundary is unavailable, with `qiyamUnavailableReason`.

**Order of computation**:
1. Library times.
2. Polar-day check.
3. High-latitude cap.
4. Asr correction.
5. Re-apply the method's built-in adjustments.
6. Apply the reader's offsets.
7. Round to the minute.

Qiyam uses Maghrib and Fajr after step 6.

**Next prayer**: the earliest available Fajr, Dhuhr, Asr, Maghrib or Isha after now, looking up
to 2 days ahead. Never Sunrise.

## Alert (derived; handed to the platform)

| Field | Rules |
| --- | --- |
| `id` | 31-bit int from hash(place id, local date, kind). Stable across refills so replacing the list does not duplicate. |
| `kind` | One of the five prayers, or `qiyam`. |
| `atUtc` | Future instant. |
| `title`, `body` | Localized at refill time: prayer name, time, place name. The language follows the app. |
| `sound` | Recitation id, `tone` or `silent`. Qiyam is always `tone`. |
| `full` | true when `athan = full` and the full recording is downloaded. |
| `fullPath` | Android only: absolute path of the downloaded full recording. |
| `generation` | `PrayerState.generation` at refill. |

**Refill**: the next 60 alerts from the current place's schedules, starting now. Events that are
unavailable are skipped (FR-014). Qiyam is included when `qiyam` is true. The prayers in
`alerts.prayers` are included when notifications are permitted.

## AthanRecording (catalogue, shipped with the app)

`assets/prayer/athan_catalogue.json`, empty until rights are cleared (R10).

| Field | Rules |
| --- | --- |
| `id` | Stable, `[a-z0-9_]+`. Names the native opening clip `athan_<id>_opening`. |
| `nameAr`, `nameEn`, `reciter` | Shown in the sound list. |
| `openingEndMs` | End of the fourth "Allahu akbar". The clip is under 30 000 ms. |
| `fullUrl`, `fullSha256`, `fullBytes`, `fullDurationMs` | Full download, checked by size and hash. |
| `source`, `licence`, `attribution` | Shown in About → licences. |

Download status of a full recording (`absent` / `downloading` / `ready` / `failed`) is read from
the file store at runtime.

## State changes

| Action | Effect |
| --- | --- |
| Set first place (location, search or estimate) | A location result fills `myLocation` and sets `current = "myLocation"`. A search or estimate result is added to `places` and becomes `current`. |
| Save another place | Added to `places`. `current` unchanged. |
| View a place | Screen state only. Nothing saved. |
| Use this place | `current = id`, `generation++`, refill. |
| Switch to "My location" | Detect, then set `myLocation` and `current`, `generation++`, refill. |
| "My location" moved > 10 km (R4) | Replace `myLocation` keeping its calculation (method updated if `methodChosen` is false), set `movedNotice` if the city changed, `generation++`, refill. |
| Change calculation, offsets, alert settings | Save, `generation++`, refill. |
| Rename place | Save only. No refill, unless the place is current, because alert text includes its name. |
| Delete the current place | The UI first asks for a replacement or alerts off. Then remove it, `generation++`, refill. |
| Delete the last place (and no `myLocation`) | State returns to "not set up". Cancel all alerts. |
| Delete all prayer data | Remove `prayer.state`, cancel all alerts, delete the Android alert copy. Recitation downloads stay. |
