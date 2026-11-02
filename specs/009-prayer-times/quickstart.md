# Quickstart Validation: Prayer Times and Athan

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Model**: [data-model.md](./data-model.md)
| **Contracts**: [location API](./contracts/location-api.md), [alerts and UI](./contracts/prayer-ui-and-reminders.md)

How to prove the feature works. Record each run's outcome in `validation/` with the date, device,
OS version and result. A mocked test or a compile is not a device result.

## Prerequisites

- Flutter 3.47.7 / Dart 3.13.5 (pinned), Java 17, Node with `node --test`.
- An Android phone with API 33 or later (the Galaxy A15 reference phone) and, if available, an
  API 24–30 phone or emulator.
- A physical iPhone on iOS 15 or later (the iPhone SE 2nd gen reference phone) and a Mac with
  Xcode for iOS builds.
- Current Chrome and Safari (desktop and iPhone) for the web app.
- For Story 5: at least one catalogue recording with cleared rights (research R10). Until then,
  test Story 4 with "Simple tone" only.

## Automated checks

```powershell
flutter pub get
flutter analyze
flutter test test/features/prayer_times test/platform
node --test tool/prayer/location_api_test.mjs
cd android; .\gradlew :app:testDebugUnitTest --tests "app.mathani.mathani.Prayer*"; cd ..
dart run tool/size_check.dart
```

Expected: no analysis issues and all tests pass. The calculator suite includes the SC-002
reference fixtures for 10 cities, all 11 methods and both Asr settings, plus daylight-saving,
high-latitude, Ramadan (Umm al-Qura), offset and Qiyam cases. Size check: report the Android and
iOS deltas and explain any over 1 MB.

On a device:

```powershell
flutter test integration_test/prayer_times_test.dart -d <device-id>
flutter test integration_test/paging_perf_test.dart -d <device-id> --profile
```

## Scenarios on devices

Run each on one Android phone and one iPhone. Run the web rows in Chrome and iPhone Safari.

### Story 1: Schedule (SC-001)

| # | Steps | Expected |
| --- | --- | --- |
| 1.1 | Fresh install. Open the app. | Mushaf opens. No permission prompt. |
| 1.2 | Settings → Prayer Times → Use my location → allow. Time it. | The system prompt offers approximate location (iOS shows "Precise: Off"). The schedule shows within 30 s with place, date and six times. The next prayer is highlighted with a countdown. |
| 1.3 | Reinstall. Use my location → deny. | One line explains it. Search stays available. No second prompt on reopen. |
| 1.4 | Open search while location is denied and the phone is online. | A "Suggested" row with an estimated city. Nothing is set until tapped. |
| 1.5 | Search "Alexandria", then "الإسكندرية". | Results show region and country (Egypt; Virginia, US). Picking one shows its schedule within 60 s of starting. |
| 1.6 | Airplane mode. Reopen Prayer Times. | Today's schedule shows normally. |
| 1.7 | Tap the next-day and previous-day arrows. | Each day's times show. The countdown is only on today. |

### Story 2: Calculation (SC-002)

| # | Steps | Expected |
| --- | --- | --- |
| 2.1 | Pick Cairo, Dubai, Istanbul and London in turn. | The suggested methods are Egyptian, Dubai, Turkey and Moonsighting Committee respectively. The method name is on the schedule. |
| 2.2 | Change the method and the Asr setting. | The schedule updates. Hanafi Asr is later. The values match the fixture for that city and date. |
| 2.3 | Isha +5. | Isha moves by 5 minutes, is marked adjusted, and its alert moves too (check the pending alert time). |
| 2.4 | Pick Oslo in June. | Fajr and Isha are marked adjusted with the rule's name. Switch the rule and the times change. |
| 2.5 | Restart the app. | All choices are kept. |

### Story 3: Places and travel (SC-005)

| # | Steps | Expected |
| --- | --- | --- |
| 3.1 | "My location" current. Use a mock location (Android developer options or the Xcode location simulation) to move to another city, then reopen the app. | The place, schedule and pending alerts update. "Moved to {city}" shows once. |
| 3.2 | Make a fixed city current and repeat 3.1. | Nothing changes. |
| 3.3 | Save Makkah, London and New York. View London while Makkah is current. | London times in London's zone. Alerts still follow Makkah. "Use this place" switches them. |
| 3.4 | Delete the current place. | The app asks for a replacement or alerts off. No alert remains for the deleted place. |
| 3.5 | Repeat switching, deleting and restarting 10 times across the three places. | Settings and the current place are correct each time. |

### Story 4: Alerts (SC-003, SC-004)

| # | Steps | Expected |
| --- | --- | --- |
| 4.1 | Turn on Fajr. | The notification permission prompt appears now, and not before. |
| 4.2 | Deny it. | Switches are kept. "Alerts blocked" shows with Open settings. |
| 4.3 | Allow it. Android 14+: exact alarms are off by default. | The "Exact alarms off" line shows with Allow. After allowing it, the line disappears. |
| 4.4 | Preview two recitations (or the tone). Start the second while the first plays. | The first stops. Stop works. |
| 4.5 | Timing trial: offset-adjust prayers so 20 alerts fall within a test window, with the phone locked. | At least 19 of 20 alerts fire within 1 minute, with the right prayer, place and sound. |
| 4.6 | Make 10 changes (place, method, sound, prayers) with alerts pending. | No duplicate alerts and no alerts for an old setting. |
| 4.7 | Reboot the phone. Do not open the app for 7 days (or set the clock forward on a test phone). | Alerts keep firing through day 7. |
| 4.8 | Turn the phone off across an alert time, then on. | The missed alert does not fire late. |
| 4.9 | Tap an alert. | Prayer Times opens. |

### Story 5: Full athan

| # | Steps | Expected |
| --- | --- | --- |
| 5.1 | Choose Full athan. | The device-specific line shows. If the recording isn't downloaded, a download row shows and alerts play the opening. |
| 5.2 | Android, locked, process killed (swipe away). | The full athan plays with a Stop notification. Stop ends it at once. |
| 5.3 | iPhone, locked. | The alert plays the opening. Tapping it opens the app and plays the full athan with Stop. |
| 5.4 | App open on both platforms. | The full athan plays in the app. |
| 5.5 | Quran recitation playing, then an athan starts (5.2 and 5.4). | Recitation pauses and stays paused after the athan. |

### Story 6: Qiyam (SC-006)

| # | Steps | Expected |
| --- | --- | --- |
| 6.1 | Open Alerts. | Qiyam is off and separate. |
| 6.2 | Turn it on for 5 places or dates. | The shown time is within 1 minute of Maghrib + ⅔ × (Fajr − Maghrib) (fixture). |
| 6.3 | Wait for the reminder. | One "Qiyam" alert with the tone. |
| 6.4 | Turn it off. | Prayer switches are unchanged. |

### Web (FR-028)

| # | Steps | Expected |
| --- | --- | --- |
| W1 | get.mthani.app (or a preview) → Prayer Times. Run 1.2–1.7 and 2.1–2.5. | Same results. Location uses the browser prompt. |
| W2 | Open Alerts. | "Only while this page is open" with store links. With the page open, an alert fires at the time. If autoplay is blocked, "Play athan" shows. |

### Quality (SC-007, SC-008)

| # | Steps | Expected |
| --- | --- | --- |
| Q1 | Cold start on the Galaxy A15 and iPhone SE with alerts on and "My location" current. | At most 2 s to the Mushaf. The paging test stays at 60 fps. |
| Q2 | Run all stories with TalkBack and with VoiceOver, in Arabic and English, at the largest text size. | Every step is completable. Nothing is clipped. |
