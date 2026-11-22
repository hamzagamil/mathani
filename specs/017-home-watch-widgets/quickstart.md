# Quickstart: Validate Home Screen and Watch Widgets

**Feature**: [spec.md](spec.md) | Contracts: [widget-snapshot](contracts/widget-snapshot.md),
[widget-surfaces](contracts/widget-surfaces.md), [watch-sync](contracts/watch-sync.md)

## Prerequisites

- Flutter 3.47.7. The Android reference phone (Galaxy A15) and an Android 16 QPR1+ phone or
  emulator for the lock screen.
- An iPhone on iOS 15 (the SE 2nd gen) and one on iOS 16 or later, installed from TestFlight (iOS
  builds come from CI, research R4).
- An Apple Watch (or the watchOS 10 simulator on CI/Mac) paired with the iPhone.
- A Wear OS emulator (Wear OS 4, API 33) paired with an Android phone emulator through the Wear OS
  app, or a real Galaxy/Pixel Watch.
- Owner setup done: Apple ids, App Groups and profiles; Play Wear OS form factor (research R4,
  R11).

## Automated checks

```text
flutter analyze
flutter test test/features/widgets
cd android && ./gradlew :app:testReleaseUnitTest :wear:testReleaseUnitTest :wear:bundleRelease
```

On CI: the `ios` job (`flutter build ios --simulator --no-codesign`, `xcodebuild test` for
RunnerTests) and the Android size check (`tool/size_check.dart android`, growth ≤ 1 MB, SC-009).

## Scenarios

| # | Story / req | Steps | Expected |
| --- | --- | --- | --- |
| 1 | S1, FR-007 | Fresh install, no place. Add the small and medium Prayer widgets on both phones. | "Set your place in Prayer Times"; a tap opens the place setup. |
| 2 | S1, SC-001 | Set a place. Look at both widgets. | Next prayer, time and countdown match the Prayer Times screen. |
| 3 | S1, SC-002 | Close the app (swipe away). Wait across a prayer time. | The widget shows the following prayer within 1 minute. On Android, repeat with exact alarms off and note the delay (research R3). |
| 4 | S1 | Change the calculation method and the place. Go home. | The widgets update within 1 minute. |
| 5 | Edge, FR-008 | Set the device date 8 days ahead without opening the app. | "Open Mathani to update"; opening the app restores the times. |
| 6 | Edge | Move the clock across a DST change for a place with DST. | Times are still correct. |
| 7 | S2 | No khatma. Read to page 23 and leave. Add the Quran widget. | Surah, "Page 23 · Juz 2"; a tap opens page 23. |
| 8 | S2 | Start a khatma. | The widget shows the wird and progress; a tap opens the khatma place. Read the wird → "Today's wird is done"; a tap opens Khatma. |
| 9 | S2 | Fresh install, never read. | "Start reading" → page 1. |
| 10 | S3 | iOS 16+: add the next-prayer and khatma lock screen widgets. Lock the phone. | Correct content, no notes or group names. A tap unlocks, then opens the same screen. |
| 11 | S3, FR-016 | Android 16 QPR1+: add the Prayer widget to the lock screen hub. | It works as on the home screen. On the A15, nothing is offered and nothing breaks. |
| 12 | FR-005 | Switch the app's language to Arabic and numerals to Arabic-Indic. | All widgets turn RTL Arabic with app numerals within 1 minute. Android countdown digits follow the system (accepted, R3). |
| 13 | FR-006, SC-008 | Dark mode, iOS 18 tinted, Android dynamic colors, the largest text, VoiceOver/TalkBack. | Readable, no clipping (fallback layout), one sentence read. |
| 14 | Edge | Clear the app's data (Android) or reinstall (iOS) with widgets left in place. | The not set up state, no crash. |
| 15 | S4 | Add the Mathani prayer complication and card (Smart Stack / tile) on both watches. | Same next prayer as the phone; the card shows the five times. A tap opens the one-screen watch app. |
| 16 | S4, SC-004 | Turn the phone off (or airplane mode). Check the watch across prayer times on 2 days (set the watch date forward for days 3–7). | It moves on correctly; after day 8 it shows "Open Mathani to update". |
| 17 | S4, SC-005 | Phone off → change the place → phone on near the watch. | The watch updates within 15 minutes. |
| 18 | S4 | Remove the place on the phone. | The complication shows the Mathani mark; the card says "Set a place in Mathani on your phone". |
| 19 | S5 | Active khatma; add the khatma complication; read the wird on the phone. | The gauge shows progress; a check appears within 15 minutes. With no khatma, the neutral mark. |
| 20 | FR-002 | Watch the network (proxy) during scenarios 2–19. | No request from any widget or watch app. |
| 21 | SC-006 | Leave all widgets placed 24 h. Check the system battery screen. | The app's share rises < 1 point. |
| 22 | SC-007 | Release build with widgets placed; check GA4 Realtime / DebugView. | `widgets_present` with the correct `kinds`, once a day. |

Record the results and the measured size growth in docs/release.md for the release.
