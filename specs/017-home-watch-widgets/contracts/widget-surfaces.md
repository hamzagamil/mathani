# Contract: Widget Surfaces, States and Taps

What every widget shows in each state, and where a tap goes. "Next" means the first entry with
`atUtc > now` (data-model.md). The countdown is native (iOS `Text(date, style: .timer)` with the
snapshot's locale, Android `Chronometer` count-down, Wear `TimeDifferenceComplicationText`).

## Links

| Link | Opens |
| --- | --- |
| `mathani-widget://prayer` | Prayer Times. If no place is set, the place setup sheet (specs/009 Story 1). |
| `mathani-widget://mushaf/<page>` | The Mushaf at `<page>` (1–604). |
| `mathani-widget://khatma/read` | The Mushaf at the khatma place, the same as "Read" on the Khatma screen (specs/014). |
| `mathani-widget://khatma` | The Khatma screen. |

An unknown or malformed link opens the app normally and is ignored. During a memorization
session, the link waits until it ends (the same as group links).

## Phone: Prayer widget (iOS, Android)

| Size | Content |
| --- | --- |
| Small (iOS systemSmall; Android 2×2, min 110×110 dp) | Place, "Next", prayer name, time, countdown |
| Medium (iOS systemMedium; Android 4×2) | Place and day label; five rows name + time, next highlighted, countdown on it |
| iOS lock: accessoryCircular | Prayer name (short) + time; ring = time elapsed since the previous prayer |
| iOS lock: accessoryRectangular | Name, time, countdown |
| iOS lock: accessoryInline | "Asr 3:12 PM" |

| State | Shown | Tap |
| --- | --- | --- |
| No snapshot or `prayer` null | Mathani mark + `labels.setPlace` (native string if there is no snapshot) | `mathani-widget://prayer` |
| Normal | As above | `mathani-widget://prayer` |
| `now ≥ validUntilUtc` | `labels.openToUpdate`, no times | `mathani-widget://prayer` |
| Largest text | Small: name + time only. Medium: next + following only. | same |

Screen reader: `labels.a11yNext` filled in, for example "Next prayer: Asr at 3:12 PM".

## Phone: Quran widget (iOS, Android)

| `quran.mode` | Small | Medium | Tap |
| --- | --- | --- | --- |
| `wird` | title, line1, line2 | + progress bar and `progress.text` | `mathani-widget://khatma/read` |
| `wirdDone` | `todayWirdDone` + check | + progress | `mathani-widget://khatma` |
| `continue` | `continueReading`, line1, line2 | + progress if paused khatma | `mathani-widget://mushaf/<page>` |
| `start` | `startReading` | same | `mathani-widget://mushaf/1` |

## Phone: Khatma progress (iOS lock screen only, iOS 16+)

| Family | Content | Tap |
| --- | --- | --- |
| accessoryCircular | Gauge `percent`, check mark when `todayRead` | `quran.link` |
| accessoryRectangular | `progress.text` + "Today's wird is done" or the wird's start | `quran.link` |
| No khatma | Mathani mark + `labels.noKhatma` | `mathani-widget://khatma` |

Android has no separate khatma widget: the medium Quran widget shows progress, and Android lock
screens take the same widgets as the home screen.

## Watch: Apple Watch and Wear OS (the same content on both, FR-024)

| Surface | Apple Watch | Wear OS | Content |
| --- | --- | --- | --- |
| Prayer complication | accessoryCircular, accessoryCorner, accessoryInline | SHORT_TEXT, LONG_TEXT | Next prayer name + countdown (Apple's ring = time elapsed between prayers; Wear OS shows the countdown as text) |
| Glance card | accessoryRectangular in the Smart Stack | Tile | Place; today's five times, next highlighted. Apple's card adds the countdown and, at large text, shows the next prayer only; the Wear OS tile has no countdown |
| Khatma complication | accessoryCircular, accessoryCorner | RANGED_VALUE, SHORT_TEXT | `percent` gauge; check when `todayRead`; neutral mark with no khatma |
| Watch screen (tap target of all) | SwiftUI list | Compose for Wear list | Place, today's five times, next marked; `setPlaceWatch` or `openToUpdate` when no valid times |

No place → the complication shows the Mathani mark, and the card shows `labels.setPlaceWatch`. After
`validUntilUtc` → `labels.openToUpdate`.

## Usage statistics (specs/016 allowed list addition)

| Event | Parameters | When |
| --- | --- | --- |
| `widgets_present` | `kinds`: sorted comma-joined subset of `prayer,quran,khatma` (`none` allowed); `surface`: `phone` | At most once per calendar day, on resume, phones only |
