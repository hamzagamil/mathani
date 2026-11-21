# Implementation Plan: Jumu'ah Alerts, Duha Reminder and Announcements

**Branch**: `015-jumuah-duha-announcements` | **Date**: 2026-11-20 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/015-jumuah-duha-announcements/spec.md`

## Summary

Two small extensions of the prayer alerts from feature 009, and one new channel:

- **Jumu'ah and Duha** stay entirely on the phone. On Fridays at the place, the Dhuhr alert and the
  schedule row are named Jumu'ah (same alert id, sound and time). Two new reminder kinds,
  `jumuah` (Friday Dhuhr − 20 min) and `duha` (midpoint of Sunrise and Dhuhr), join `qiyam` in
  `buildAlerts`, use the Qiyam sound and Android channel, and get rows in the Alerts sheet. The
  Jumu'ah setting is stored as a nullable boolean: `null` means "never changed", so it follows the
  Dhuhr alert (spec Q1), with no migration step.
- **Announcements** use Firebase Cloud Messaging, which the owner asked for, with
  `firebase_core` and `firebase_messaging` only (no Analytics; specs/016 later adds usage
  statistics). The app subscribes to the topics
  `all` and `lang_ar` or `lang_en` when the Settings switch is on, and unsubscribes when it is off.
  Firebase starts after the first frame, and only on Android and iOS. The admin sends from the
  Firebase console to a topic. A `link` data field that is a Mathani link is handed to the
  existing link host from feature 014.

## Technical Context

**Language/Version**: Dart 3.13 / Flutter 3.47.7; Kotlin (Android alarm store); Swift (iOS
entitlements only)

**Primary Dependencies**: existing `adhan_dart`, `flutter_local_notifications`, `timezone`; new
`firebase_core` and `firebase_messaging` (research R6, R7)

**Storage**: `user.db` prayer state JSON (`AlertSettings` gains `jumuah`, `duha`); reader
preferences gain `announcements` (default on)

**Testing**: `flutter test` (unit tests for `buildAlerts`, settings JSON, calculator, the
announcements controller with a fake messaging client); manual device checks in
[quickstart.md](quickstart.md)

**Target Platform**: iOS 15.0+ and Android 7.0 (API 24)+. Web gets the Jumu'ah label only.

**Project Type**: mobile app (Flutter) with Cloudflare Pages Functions; no server change

**Performance Goals**: no change to cold start (Firebase starts after the first frame); alert
refill stays under the current cost (one extra event per day)

**Constraints**: offline for Jumu'ah and Duha; no account, analytics or personal data for
announcements (FR-017); iOS pending notification limit (64) shared with khatma reminders

**Scale/Scope**: 2 new alert kinds, 3 new settings rows, 1 new Settings switch, ~12 strings per
language, 1 new platform service

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
| --- | --- | --- |
| I. Parity | Every part works on iOS and Android; the web gap (no alerts, no push) is the existing documented 009 gap | Pass |
| II. Mobile-first | New rows reuse the Alerts sheet's `SwitchListTile`s and the Settings section pattern; RTL, dark mode, font scale and screen readers come with them | Pass |
| III. Performance | Firebase initialises after the first frame, never before `runApp`; no background isolate or handler | Pass |
| IV. Lean | Two new dependencies, justified below; no Analytics; size growth measured and called out | Pass with justification |
| V. Simplicity | Reuses `buildAlerts`, the Qiyam channel, `alertId`, the link host; no new layer | Pass |
| Platform & store | Notification permission only when the reader turns something on; store privacy answers updated in `docs/store/privacy.md` | Pass |

Re-check after Phase 1: unchanged. The only added complexity is the Firebase dependency.

## Project Structure

### Documentation (this feature)

```text
specs/015-jumuah-duha-announcements/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── alerts.md            # alert kinds, ids, text, sound, Android store
│   └── announcements.md     # message format the admin sends, topics, tap handling
└── tasks.md                 # /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── features/prayer_times/
│   ├── prayer_models.dart        # PrayerKind.jumuah/duha, AlertSettings.jumuah/duha, DaySchedule.duhaUtc
│   ├── prayer_calculator.dart    # duha midpoint
│   ├── prayer_alerts.dart        # buildAlerts: Friday title, Jumu'ah and Duha reminders, priority cut
│   ├── prayer_copy.dart          # prayerName(friday:), channel names
│   ├── prayer_controller.dart    # setJumuah, setDuha, nextDuha, nextJumuah
│   ├── prayer_times_screen.dart  # Jumu'ah label on Fridays
│   └── reminder_settings.dart    # Jumu'ah and Duha rows
├── features/settings/settings_screen.dart   # Announcements switch
├── features/announcements/announcements.dart # controller: topics, taps → links
├── platform/announcements.dart (+ _io, _web)  # FCM on phones, no-op elsewhere
├── firebase_options.dart                      # generated by `flutterfire configure` (owner)
├── data/models.dart                           # ReaderPreferences.announcements
└── app/l10n/app_{en,ar}.arb
android/app/src/main/
├── AndroidManifest.xml            # FCM default channel and auto-init off
└── kotlin/.../PrayerAlarmStore.kt, PrayerAlarmReceiver.kt, PrayerNotificationsPlugin.kt
ios/Runner/Runner.entitlements, Info.plist   # aps-environment, auto-init off
test/features/prayer_times/, test/features/announcements/
docs/store/privacy.md
```

**Structure Decision**: Existing Flutter app layout. Prayer changes stay in
`lib/features/prayer_times`; announcements get a small feature folder and a conditional platform
file, as other platform services do.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
| --- | --- | --- |
| New dependencies `firebase_core`, `firebase_messaging` (estimated +1–2 MB per platform) | Push messages need a push service; the owner asked to send from the FCM console | APNs + own server: no console, needs a sender service and token store. OneSignal and others: larger, another third party, not what the owner asked for. Polling our server: battery and data cost, not delivered when the app is closed |
