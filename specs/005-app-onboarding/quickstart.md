# Quickstart: Validating the Onboarding

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Prerequisites

- Flutter 3.47.7 (pinned).
- The reference phones from feature 001: Galaxy A15 (Android 14) and iPhone SE 2nd gen (iOS 15+
  test build), plus one Android 7 emulator (API 24).
- A build of **1.3.0** on each phone, for the update scenarios (Q-9, Q-10).
- Wi-Fi, and a way to turn all networks off (airplane mode).

## Automated tests

```sh
flutter test test/unit/onboarding_steps_test.dart       # step sequence: flowing adds textSize, no reciters/player, replay; progress numbers
flutter test test/unit/onboarding_controller_test.dart  # next/back/skip/done; onboardingDone written only on a first run; layout change mid-way; stopPreview on leaving reciter
flutter test test/unit/reciter_preview_test.dart        # preview states with a fake engine and fake server: plays 1:1, offline → unavailable, 5 s timeout, no session, no onFirstPlay
flutter test test/widget/onboarding_screen_test.dart    # each step in ar and en; language flips direction in place; theme/layout apply live; Skip from every step
flutter test test/widget/button_tour_test.dart          # hole over each real button; taps absorbed; controls forced visible; jumps held, then applied; player targets the bar during a session
flutter test test/widget/onboarding_a11y_test.dart      # semantics of cards, card group, excluded scrim; 2.0 text scale on 320×568 without overflow
flutter test                                             # whole suite: existing tests pass with openTestReader(onboarded: true)
flutter test integration_test/app_flow_test.dart -d <device>   # first-run pass: fresh db → onboarding → reader on page 1
```

Expected: all pass. There are no golden changes outside the new files.

## Device scenarios

Run each on both reference phones. Q-1, Q-4 and Q-7 also run on the API 24 emulator. "Fresh
install" means the app is uninstalled first.

| # | Scenario | Expected | Covers |
| --- | --- | --- | --- |
| Q-1 | Fresh install, airplane mode, open the app | The onboarding opens in the device language. Every step works; the reciter step shows the offline note and disabled samples. Finish: the Mushaf is on page 1. | FR-001, FR-004, SC-007 |
| Q-2 | Fresh install. Choose English, Night, Flowing, size 30, El-Minshawi. Finish. | The reader is in English, night, flowing at size 30. Play: El-Minshawi. Settings shows the same. Kill and reopen: same, with no onboarding. | Story 1, SC-003, SC-004 |
| Q-3 | On the language step, pick Arabic, then English, then Arabic | The text and direction change each time, and the step stays the same. | AS2, edge case |
| Q-4 | Fresh install, tap Skip on the first screen | The Mushaf opens at once on page 1, with defaults. Reopen: no onboarding. | Story 2, SC-002 |
| Q-5 | Fresh install. Choose Night, then Skip on the layout step | The Mushaf opens at night. The tour doesn't run. | AS3, AS5 |
| Q-6 | Fresh install. Choose Flowing, go to the reciter step, go back to layout and pick Mushaf, then Next | The text size step is gone, the reciter step follows, and the earlier choices are kept. | AS5, AS7 |
| Q-7 | Fresh install. Choose Night and Flowing, then kill the app on the reciter step | Reopen: the onboarding restarts at the language step. Night and Flowing are selected and in effect. | FR-003 |
| Q-8 | Reciter step on Wi-Fi: play the Al-Husary sample, then the El-Minshawi sample, then lock the phone | The first sample stops when the second starts. Locking stops it. There are no lock-screen media controls, and no recitation bar later. | FR-010, FR-011 |
| Q-9 | Install 1.3.0. Choose Night and El-Minshawi, read to page 300, bookmark it, download Al-Mulk. Update to this build and open. | The full onboarding shows. Each step has the saved choice selected. Finish: page 300, with the bookmark and the download still there. Reopen: no onboarding. | Q2, FR-005, FR-007, SC-009 |
| Q-10 | Same as Q-9, but Skip on the first screen | Page 300, nothing changed. Reopen: no onboarding. | SC-009 |
| Q-11 | Gesture stops in each layout | The Mushaf stops show a sideways drag in the page-turn direction and a tap. The flowing stops show an upward scroll and say the controls stay. The press-and-hold stop shows play, bookmark, copy and share. | Story 3, AS3, AS4 |
| Q-12 | Button hints | Each hint highlights the real button: index, search, Listen, settings. Tapping the highlighted area or the page does nothing. Next moves on, and Done leaves the reader on page 1 with no controls hint afterwards. | AS5–AS8, FR-017a, FR-018 |
| Q-13 | Read to page 200, start a recitation, open Settings › See the tour again | The tour starts at "Turn the pages", with no setup steps. The recitation keeps playing. The player hint highlights the recitation bar, and the page doesn't turn while hints show. Done: page 200, or the recited page if the recitation moved on. Preferences and bookmarks are unchanged. | Story 4, FR-022, edge case |
| Q-14 | Android system back through the onboarding | Back goes one step back each time. On the first step, it leaves the app; reopening shows the onboarding again. From the first hint, back returns to the last gesture stop. | FR-025 |
| Q-15 | VoiceOver (iOS) and TalkBack (Android) through the whole onboarding | Each step's title gets focus. Cards read as radio buttons, and the sample button says its state. In hints, only the card is reachable, and it reads "*i* of *n*, title, body". | FR-024 |
| Q-16 | Largest system font size, then dark mode with the theme on System | No clipping. Long steps scroll and the bottom bar stays visible (it wraps if needed). The colours follow the device. | FR-024, edge cases |
| Q-17 | Reduce motion on (iOS Reduce Motion / Android Remove animations) | Gesture stops show still frames with arrows, and steps change without sliding. | R3 |
| Q-18 | Usability test, 5 first-time readers | Each completes the onboarding. Then, without help: show the controls, play from the 3rd ayah, bookmark it, find it in Bookmarks, search a word. At least 4 of 5 succeed at all of them. Time the onboarding: under 2 minutes in total, and under 45 s for setup. | SC-001, SC-005 |

## Performance and size gates (Principles III and IV)

```sh
flutter drive --profile --driver=test_driver/perf_driver.dart --target=integration_test/paging_perf_test.dart   # unchanged reader paging
flutter build appbundle --release --analyze-size
dart run tool/size_check.dart android <analyze-size.json>
flutter build ipa --release --analyze-size
dart run tool/size_check.dart ios <analyze-size.json>
```

Expected:
- Cold start to the first usable onboarding screen is no longer than to the Mushaf today
  (≤ 2 s), measured from icon tap on both reference phones (SC-006).
- Step changes respond within 100 ms of the tap. Gesture animations hold 60 fps in a profile
  build (DevTools frame chart).
- Growth is well under 1 MB on both stores (SC-008).

## Before release

- Q-9 and Q-10 are signed off on both stores' update paths: Play internal track and TestFlight
  over a 1.3.0 install.
- Store screenshots are optional: one onboarding frame (the layout step) may be added. Nothing
  else changes in the store listing or the privacy answers. No data is collected, and the sample
  uses the same audio host as recitations.
