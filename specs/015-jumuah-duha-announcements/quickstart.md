# Quickstart: validating feature 015

## Prerequisites

- Flutter 3.47.7; one Android phone or emulator (API 24+), one iPhone (iOS 15+; push needs a real
  device).
- For announcements: a Firebase project configured with `flutterfire configure` (writes
  `lib/firebase_options.dart`), the APNs key uploaded, and the Push Notifications capability.

## Automated

```sh
flutter analyze
flutter test test/features/prayer_times test/features/announcements
```

Expected: green. The tests cover the Friday title, the Jumu'ah reminder time and default, Duha's
midpoint, the priority cut, settings JSON round-trips and old JSON, and topic changes.

## Manual

1. **Jumu'ah label** (Story 1): Dhuhr alert on; set the phone to a Friday a few minutes before
   Dhuhr. The schedule shows "Jumu'ah"; the alert says "Time for Jumu'ah prayer". Repeat on a
   Thursday: "Dhuhr".
2. **Jumu'ah reminder** (Story 2): with Dhuhr on and the reminder never touched, the row is on.
   Lock the phone; on Friday the reminder arrives 20 min before Dhuhr with the Qiyam sound. Turn
   it off, then toggle Dhuhr: the reminder stays off. Add +5 to Dhuhr: the reminder moves 5 min.
3. **Duha** (Story 3): turn Duha on; the row shows the midpoint of the day's Sunrise and Dhuhr.
   Wait for it; one "Duha prayer" reminder.
4. **Announcements** (Story 4): in the console, send to topic `all` with the app open, in the
   background and killed. Add `link` = a group khatma link: the tap opens it. Turn the switch
   off, send again: nothing arrives. Switch the app to English, send to `lang_en`: it arrives.
5. **Size and start**: `dart run tool/size_check.dart` and note the growth in review; cold start
   unchanged on the reference device.
