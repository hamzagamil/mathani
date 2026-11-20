# Data Model: Jumu'ah Alerts, Duha Reminder and Announcements

## PrayerKind (changed)

`fajr, sunrise, dhuhr, asr, maghrib, isha, qiyam, jumuah, duha`. `jumuah` and `duha` are
reminder kinds, like `qiyam`: never in `dailyPrayers`, never in a schedule's `events`.

## AlertSettings (changed)

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| prayers, sound, athan, qiyam | unchanged | | |
| jumuah | `bool?` | `null` | `null` = never changed: follows the Dhuhr alert (R4) |
| duha | `bool` | `false` | |

- `jumuahOn` = `jumuah ?? prayers.contains(dhuhr)`.
- `any` = `prayers.isNotEmpty || qiyam || duha || jumuahOn`.
- JSON: `jumuah` written only when not null; `duha` always. Missing keys read as the defaults.

## DaySchedule (changed)

| Field | Type | Notes |
| --- | --- | --- |
| duhaUtc | `DateTime?` | Midpoint of the adjusted Sunrise and Dhuhr, rounded to the minute; null if either is null |
| isFriday | getter | `localDate.weekday == DateTime.friday` |

## Alert (unchanged shape)

New `kind` values `jumuah` and `duha`; ids from `alertId(place, date, kind)`.

## ReaderPreferences (changed)

| Field | Type | Default |
| --- | --- | --- |
| announcements | `bool` | `true` |

## Announcement (not stored)

A push message: `notification.title`, `notification.body`, optional `data.link`. Shown by the
system or, in the foreground on Android, by the app. Nothing is kept after it is shown.
