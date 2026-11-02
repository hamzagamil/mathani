# Contract: Prayer Times Screens, Alerts and Athan Playback

**Spec**: [../spec.md](../spec.md) | **Model**: [../data-model.md](../data-model.md) | **Research**:
[R7–R9](../research.md)

## Screens

Entry: Settings (reader toolbar) → "Prayer Times", two taps (FR-031). It pushes a normal route.
Back returns to the reader with page and recitation untouched. Notification taps open the same
route through the existing `PrayerNotificationOpenHost`.

| Screen / sheet | Contents |
| --- | --- |
| **First-time** (not set up) | One line on why location is used. "Use my location" and "Search for a city". No permission is requested until a button is tapped. |
| **Schedule** (home of the feature) | Header: place name, date with previous and next day arrows, method and Asr setting. If the place's zone differs from the phone's, the zone name. Rows: Fajr, Sunrise (marked "not a prayer"), Dhuhr, Asr, Maghrib, Isha. Each row shows its time and its marks: "adjusted" (high-latitude rule or offset) or "unavailable". The next prayer is highlighted with a live countdown, today only. A "Moved to {city}" banner appears once when `movedNotice` is set. Actions: Places, Calculation, Alerts. |
| **Places** sheet | "My location" row (with refresh), then saved places. Each row shows name, city and country; the current one is marked. Tapping a row views it. A "Use this place" button appears when viewing a non-current place. Rename, delete, "Add a place" (search). |
| **City search** | Text field (Arabic or English). The "Suggested" estimate row when applicable (location-api contract). Results show city, region and country. GeoNames attribution. Messages for no results, offline and errors, with retry. |
| **Calculation** sheet (per viewed place) | Method list (11), with the country suggestion labelled "Suggested". Asr: "Standard (Shafi'i, Maliki, Hanbali)" / "Hanafi", with the note "changes Asr only". High-latitude rule (2) with a one-line explanation. Per-prayer offset steppers, −30..+30 minutes. |
| **Alerts** sheet | Five switches (no Sunrise), the sound list and the athan length. Status lines: notifications blocked (with Open settings), exact alarms off (Android, with Allow), and any phone limit the app can detect. Qiyam switch with tonight's time and a one-line explanation. See the next section for the sound list and athan length. |

**Sound list** (in the Alerts sheet): each recitation with reciter, preview and Stop. Then "Simple
tone" and "Silent". Only one preview plays at a time. Closing the sheet stops the preview.

**Athan length** (in the Alerts sheet): "Opening takbirat" / "Full athan". Under "Full athan", a
platform-specific line (FR-024):

- **Android**: "Plays in full even when your phone is locked."
- **iPhone**: "The alert plays the opening; tap it to hear the full athan."
- **Web**: "Plays only while this page is open."

When full mode is on and the recording is not downloaded: a download row with progress, and "Until
downloaded, alerts play the opening" (FR-023).

**All screens** use Arabic and English (RTL and LTR), the inherited light and dark themes, safe
areas and text scaling. Touch targets are at least 44 pt / 48 dp. Every control has a semantic
label for VoiceOver and TalkBack. Status changes such as "alerts blocked" are announced. Taps give
feedback within 100 ms. Network and location work shows progress and never blocks the screen.

**Web**: the same screens inside the existing phone column. The Alerts sheet adds "Alerts work
only while this page is open", with links to the store apps (FR-028).

## Dart interfaces (behavioural)

- **`PrayerRepository`**:
  - `load()` reads and parses `prayer.state` from `UserRepository` preferences.
  - `save(state)` writes it. Writes are serialized.
- **`PrayerCalculator`**:
  - `schedule(place, localDate)` returns a DaySchedule.
  - `nextPrayer(place, now)`.
  - Pure and offline. Results depend only on the inputs and the calculator version.
- **`PrayerController`** (`ChangeNotifier`, route-scoped):
  - Holds the viewed place separately from `current`.
  - Exposes the actions in the data model's state-change table.
  - Calls `PrayerAlerts.refill` after each save that increments `generation`.
- **`PrayerAlerts`** (app-scoped, lazy):
  - `refill(state)` builds the 60-alert list (data model) and calls `PrayerAlertPlatform.replace`.
  - It runs after the first frame on start and resume, and after changes.
  - It also runs the "My location" refresh (R4) on the same trigger.
  - On iOS, while the app is active and full mode is ready, it keeps a timer for the next alert
    and plays the full athan through `AthanPlayer`. The timer is cancelled when the app goes to
    the background.
- **`PrayerAlertPlatform`** (conditional import: `_io` / `_web`):
  - `status()` returns `{notifications: granted|denied|notDetermined|unsupported, exactAlarms: bool?}` without prompting.
  - `requestPermission()` is called only from turning on an alert.
  - `openSettings({exactAlarms})`.
  - `replace(List<Alert>, generation)` cancels app-owned alerts not in the list and schedules the rest. It returns the count actually pending.
  - `cancelAll()`.
- **`AthanPlayer`** (existing):
  - `preview(recording)`, `playFull(recording)`, `stop()`.
  - Before playing it pauses Quran recitation and memorization listening. It never resumes them.

## Native contract

### Method channel `app.mathani/prayer_notifications` (Android and iOS)

| Call | Arguments | Returns |
| --- | --- | --- |
| `status` | none | `{notifications, exactAlarms}`. `exactAlarms` is Android 12+ only, otherwise null. |
| `requestPermission` | none | Same as `status`. |
| `openSettings` | `{exactAlarms: bool}` | none |
| `replace` | `{generation, alerts: [Alert]}` | `{pending: int}` |
| `cancelAll` | none | none |

| Event (native → Dart) | When |
| --- | --- |
| `opened {kind, alertId}` | The reader tapped an alert. Prayer Times opens. If full mode is on and the recording is ready, the app plays the full athan (iOS, web). |
| `athanStarted` | Android service started while the app process is alive. Dart pauses memorization listening. |

On iOS, `flutter_local_notifications` performs scheduling. The channel above is a thin Dart
facade over it in `prayer_notifications_io.dart`, so Dart callers see one interface.

### Android

- **`PrayerNotificationsPlugin.kt`**:
  - Stores the alert list in `SharedPreferences` (`PrayerAlarmStore`, plain JSON).
  - Sets one alarm per alert: `setExactAndAllowWhileIdle` when exact alarms are allowed,
    otherwise `setAndAllowWhileIdle`.
  - Cancels alarms for removed ids.
  - Creates channels on demand: `prayer_<sound>_v1`, `prayer_silent_v1`, and the existing Qiyam
    channel.
- **`PrayerAlarmReceiver.kt`**: on an alarm:
  - Ignores it if the stored generation is newer, the alert was removed, or it is more than
    15 minutes late.
  - If `full` is true, `fullPath` exists and exact alarms are allowed, starts
    `AthanPlaybackService`.
  - Otherwise posts the notification on the alert's sound channel.
  - Then removes the alert from the store.
  - On `BOOT_COMPLETED`, `TIME_SET`, `TIMEZONE_CHANGED` and exact-alarm permission changes, it
    re-sets alarms for future alerts only.
- **`AthanPlaybackService.kt`** (new, foreground type `mediaPlayback`):
  - Requests `AUDIOFOCUS_GAIN`, then plays `fullPath` with `MediaPlayer`.
  - Shows an ongoing notification with the prayer name, place and a Stop action. Tapping it opens
    Prayer Times.
  - Stops itself and abandons focus on completion, Stop, error or focus loss.
- **Manifest**:
  - Remove `ACCESS_FINE_LOCATION`.
  - Add the service declaration with `foregroundServiceType="mediaPlayback"`.
  - Keep `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`,
    `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK`.
- **Removed**: `PrayerMediaBridge.kt` and its registration in `MainActivity.kt`.

### iOS

- **Scheduling**: `zonedSchedule` with absolute UTC times, at most 60 pending. The sound is the
  bundled `athan_<id>_opening.caf`, `qiyam_tone.caf`, or none for silent.
- **Foreground delivery**: full-mode alerts are scheduled with
  `DarwinNotificationDetails(presentSound: false)`, so an alert that arrives while the app is open
  shows a banner without sound. While the app is active, `PrayerAlerts` keeps a timer for the next
  alert and plays the full athan through `AthanPlayer` at that moment. This works the same way as
  the web page timer, and needs no native `willPresent` code.
- **Tap**: `didReceive` emits `opened`.
- **`Info.plist`**: keep the when-in-use usage text, updated to say approximate location only.
  Add `NSLocationDefaultAccuracyReduced = true`.

### Web

`prayer_notifications_page.dart` keeps an in-memory timer queue while the page is open, shows a
browser notification if permitted, and plays through `AthanPlayer`. If autoplay is blocked, it
shows a "Play athan" button. Missed events are not replayed when the page is revisited.

## Behaviour by platform (FR-020, FR-024)

| Situation | Opening / tone / silent | Full athan |
| --- | --- | --- |
| Android, any state | Notification on the sound's channel | `AthanPlaybackService` plays in full with Stop. Without exact alarms or the downloaded file: opening notification. |
| iOS, app open | Banner with the clip sound | Banner without sound; the app plays in full with Stop |
| iOS, background, locked or closed | Notification with clip sound (≤30 s) | Same as opening; tapping it opens the app and plays in full |
| Web, page open | Browser notification (if allowed) plus in-page sound | In-page full playback |
| Web, page closed | Nothing (stated in settings) | Nothing |

Quran recitation pauses before any app-played athan and does not resume by itself. A notification
sound played by the phone may briefly overlap recitation (FR-026).

## User-visible states

Each state has one line of text and at most one action.

| State | Action |
| --- | --- |
| Location refused | Search for a city |
| Location unavailable | Retry or search |
| Offline (search or estimate) | Retry |
| Search found nothing | none |
| Time unavailable at this latitude | none |
| Notifications blocked | Open settings |
| Exact alarms off (Android) | Allow |
| Recitation downloading or failed | Retry |
| Autoplay blocked (web) | Play athan |
| Alerts follow "{place}" | Shown in the Alerts sheet; no action |

No error removes saved places or settings.
