# Contract: Jumu'ah and Duha alerts

## Alerts built by `buildAlerts`

| Kind | When | Title (en / ar) | Body (en / ar) | Sound |
| --- | --- | --- | --- | --- |
| dhuhr on Friday | Dhuhr | Time for Jumu'ah prayer / حان وقت صلاة الجمعة | unchanged | unchanged |
| jumuah | Friday Dhuhr − 20 min, if `jumuahOn` | Jumu'ah prayer in 20 minutes / صلاة الجمعة بعد ٢٠ دقيقة | Hasten to the remembrance of Allah. / فاسعوا إلى ذكر الله | Qiyam's |
| duha | `duhaUtc`, if `duha` | Duha prayer / صلاة الضحى | The prayer of those who turn to Allah. / صلاة الأوابين | Qiyam's |

- Numbers in the Arabic title use the app's numeral formatting.
- A reminder whose time has passed, or whose source time is unavailable, is skipped.
- `full` is always false for reminders.

## Android native contract

- `PrayerAlarmStore` accepts kinds `jumuah` and `duha`; lateness = `LATENESS_MS`.
- `PrayerAlarmReceiver` and `soundChannel` treat `jumuah` and `duha` like `qiyam` (tone sound,
  `prayer_qiyam_v2` channel). The channel's display name is the Dart string
  `prayerChannelReminders`.
- Taps report the kind as today; the app opens Prayer Times.

## Alerts sheet

After the Qiyam row: "Jumu'ah reminder" (subtitle: "20 minutes before Jumu'ah, on Fridays" +
next Friday's time) and "Duha" (subtitle: today's or tomorrow's time + "Halfway between sunrise
and Dhuhr, the best time for Duha"). Both disabled while busy or with no place.

## Schedule

On Fridays the Dhuhr row's label is "Jumu'ah" / "الجمعة"; the next-prayer header uses it too.
