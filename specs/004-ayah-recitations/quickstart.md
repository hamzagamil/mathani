# Quickstart: Validating Ayah-by-Ayah Recitations

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Prerequisites

- Flutter 3.47.7 (pinned). The reference phones from feature 001: Galaxy A15 (Android 14) and
  iPhone SE 2nd gen (iOS 15+ test build), plus one Android 7 emulator (API 24).
- Network for building the catalogue, and Wi-Fi plus mobile data on the phones.
- Wired or Bluetooth headphones for the interruption checks.

## Build the catalogue (once, and again when a reciter is added)

```sh
dart run tool/build_recitation_manifest.dart        # about 12.5k HEAD requests at 4 at a time; 15–25 min
dart run tool/build_quran_db.dart
dart run tool/verify_quran.dart                      # unchanged text checks still pass
```

Expected: the manifest tool reports `husary: 6236/6236`, `minshawy: 6236/6236`, exit 0
(SC-003, automated half). `quran.db` has 2 `reciters` rows and 12,472 `recitation_files` rows.

## Automated tests

```sh
flutter test test/unit/recited_item_order_test.dart      # next/previous over all 6,236 ayat; basmala rules; 9 and 1:1
flutter test test/unit/ayah_fetcher_test.dart            # resolve order, size check, mirror fallback, offline, .part, LRU cap
flutter test test/unit/download_queue_test.dart          # state from disk, resume fetches only missing, delete, concurrency 2
flutter test test/unit/recitation_controller_test.dart   # states, never skips on failure, follow/unfollow by jumpSerial, reciter switch
flutter test test/widget/recitation_bar_test.dart        # bar states, back-to-recitation row, error row, semantics, page refit
flutter test test/widget/recitation_highlight_test.dart  # recited highlight covers exactly the ayah words, both letterings; basmala line
flutter test test/widget/downloads_screen_test.dart      # listing, totals, delete updates in ≤ 1 s, preconditions dialogs
flutter test                                              # whole suite, including the existing goldens
```

The tests use a fake player, a fake HTTP server (`HttpServer` on localhost) and a fake
`app.mathani/device` channel. They never reach EveryAyah.

## Device scenarios

Run each on both reference phones unless marked.

| # | Scenario | Expected | Covers |
| --- | --- | --- | --- |
| Q-1 | Fresh install, Wi-Fi. Open page 50, tap **Listen**. | Al-Husary is heard within 2 s. The first ayah starting on page 50 is highlighted. Then repeat for 20 starts per phone (10 random ayat, 2:255 and 2:282 among them, half on 4G), logging tap-to-first-audio: at least 19 of 20 are ≤ 2 s. | US1 AS1, US2 AS1, SC-001 |
| Q-2 | Long-press the 3rd ayah of page 50, **Play from this ayah**. Listen across into page 51. | Each ayah in order, no gaps beyond the recording's silence. The highlight follows. The page turns as the first ayah of page 51 starts (≤ 0.5 s). | US1 AS2–4, SC-004 |
| Q-3 | Play from 1:7 into Al-Baqarah. Play 8:75 into At-Tawbah. Repeat for 8 more surah starts, for each reciter. | The basmala is heard once before 2:1 and highlighted on its line. No basmala before 9:1. V-1: 2:1 does not begin with a second basmala. | US1 AS5, R2 |
| Q-4 | Play Al-Kahf from 18:1 to 18:110 (each reciter, Wi-Fi). Log the item changes (debug overlay). | 110 ayat, each exactly once and in order, plus the basmala. The time from each `itemCompleted` to the next `itemStarted` is ≤ 150 ms at the 95th percentile. | SC-002, FR-009 |
| Q-5 | During playback: pause, resume, next ×3 quickly, previous, stop. | Each reacts within 100 ms. The rapid next taps land 3 ahead. Stop hides the bar and clears the highlight. | US1 AS6, FR-011 |
| Q-6 | Switch to the flowing layout during playback and let it run 10 ayat. Then back to Mushaf. | The ayah stays highlighted. The flowing view scrolls only when the ayah leaves the screen. Following continues. | US1 AS7, edge cases |
| Q-7 | During playback, swipe two pages away. Then tap **Back to recitation**. | Playback continues and the page stays where the reader put it. The back row appears; tapping it returns to the ayah and following resumes. Same with the index, search and go-to. | FR-014, edge cases |
| Q-8 | Switch reciter mid-ayah. Restart the app. | The same ayah restarts in the new voice. After the restart, the new reciter is kept and nothing plays by itself. | US2 AS3–4 |
| Q-9 | Play Al-Mulk, lock the phone for 3 ayat, pause and resume on the lock screen, next, then unlock. | The lock screen shows reciter, surah and ayah, and the controls work. On unlock the reader is on the recited ayah's page. | US3 AS1–3, FR-016 |
| Q-10 | Lock the screen and play for 30 minutes (Al-Baqarah). | No stop. Battery and thermal state normal. | SC-005 |
| Q-11 | Call the phone during playback, end the call. Start music in another app. Unplug the headphones. | Pause, then resume after the call (as the platform does). Pause with the other app. Pause and stay paused after unplugging. | US3 AS4, FR-017 |
| Q-12 | Airplane mode, tap Listen on an undownloaded surah. | The message within 1 s, with Download and Retry. Reading still works. | SC-008 |
| Q-13 | Wi-Fi: during playback, turn off the network after 2 ayat. | The fetched ayat finish. Playback then pauses on the next ayah with the retry message, without skipping. After reconnecting, Retry continues from that ayah. | FR-019, FR-020 |
| Q-14 | Mobile data: Surahs index › Al-Mulk › Download. | The size is shown, then the mobile-data confirmation. Progress in Settings › Downloads. Reading and listening are uninterrupted. | US4 AS1–3 |
| Q-15 | Start downloading Al-Baqarah, then turn on airplane mode at about 30% and close the app. Reopen, go online, tap Resume. | Shown as stopped (partial). Resume completes it, and the data used ≈ the remaining size (logged bytes ≤ remaining + one ayah). | US4 AS4, SC-011 |
| Q-16 | Airplane mode. Play Al-Mulk (downloaded) from 67:1 to the end, then into Al-Qalam (not downloaded). | All of Al-Mulk plays with its basmala, then it pauses at 68's basmala with the offline message. | US4 AS5, SC-010, edge cases |
| Q-17 | Airplane mode, Al-Mulk downloaded for Al-Husary only. Switch to El-Minshawi. | The message "El-Minshawi isn't downloaded for this surah". Al-Husary stays. | edge cases |
| Q-18 | Fill the device until free space is under the surah size + 50 MB. Download Al-Baqarah. | "Not enough storage: X needed". Nothing starts. | FR-028 |
| Q-19 | Settings › Downloads: delete Al-Mulk. Delete all for a reciter. | Totals update within 1 s. Al-Mulk's index mark disappears, and it no longer plays offline. | US4 AS7, SC-012 |
| Q-20 | Truncate one downloaded file (debug build: `adb shell` / Files app via a debug menu). Play it offline. | Not played. The surah now shows as partial, and playback pauses with the offline message. | FR-031 |
| Q-21 | VoiceOver and TalkBack: start playback from the toolbar, and change the reciter from the bar. | All labels are read in the interface language, and ayah changes do not interrupt the reader. | FR-025 |
| Q-22 | Largest system font, night theme, iPhone SE: bar with the back row and an error row. | Nothing clipped. The page refits once, and no Quran text is covered. | FR-010, FR-025 |
| Q-23 | Android 7 emulator: Q-1, Q-9 and Q-14. | Same results. | FR-026 |

## Performance and size gates (Principles III and IV)

```sh
flutter drive --profile --driver=test_driver/perf_driver.dart \
  --target=integration_test/paging_perf_test.dart --dart-define=WITH_RECITATION=true   # paging while a recitation plays
flutter build appbundle --release --analyze-size
dart run tool/size_check.dart android <analyze-size.json>   # growth over 1 MB is expected; report it in the PR (SC-007)
flutter build ipa --release --analyze-size
dart run tool/size_check.dart ios <analyze-size.json>
```

Expected:
- Paging stays at 60 fps with a recitation playing (SC-006).
- Cold start is unchanged (≤ 2 s; `AudioService.init` is deferred to the first play).
- Android growth is reported with its cause; iOS growth is under 1 MB.

## Before release

- **D4 granted** (`docs/licences.md`), and the About attribution matches its terms.
- `docs/store/privacy.md` is updated (network use, Android permissions, iOS background audio),
  and the published privacy policy names the audio host. The privacy answers are rechecked:
  still "no data collected".
- Q-3 listening log for both reciters is attached to the release checklist (SC-003, listening
  half: one ayah per surah per reciter).
- Usability test, SC-009: 10 readers, 9 must succeed on their first try.
