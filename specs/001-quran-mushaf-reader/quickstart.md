# Quickstart & Validation: Quran Mushaf Reader

How to build the app and prove the feature works end to end. Schemas and formats are in
[contracts/](./contracts/); entities are in [data-model.md](./data-model.md).

## Prerequisites

| Need | For |
| --- | --- |
| Flutter SDK (version pinned in `pubspec.yaml`), Dart included | everything |
| Android Studio + Android SDK (API 36), JDK 17 (installed) | Android builds and emulator |
| A physical Android phone, ideally a Galaxy A15 or similar (reference device) | performance checks |
| macOS + Xcode **or** cloud macOS CI (Codemagic / GitHub Actions) | iOS builds; not possible on Windows |
| An iPhone SE (2nd gen) or similar (reference device) | iOS performance checks |
| Source data files downloaded into `tool/sources/` (gitignored) | building `quran.db` |

## Setup

```powershell
flutter pub get
dart run tool/build_quran_db.dart     # writes assets/db/quran.db from tool/sources/
dart run tool/verify_quran.dart       # must print: PASS (114 surahs, 6236 ayat, 604 pages, ...)
flutter test                          # unit + widget tests
flutter run                           # debug on emulator or device
```

## Validation scenarios

Run on **one Android and one iOS device** before merge (constitution workflow).

| # | Scenario | Steps | Expected | Covers |
| --- | --- | --- | --- | --- |
| 1 | Offline first launch | Fresh install, airplane mode on, open app | Al-Fatiha page 1 in Mushaf layout. Index, search, settings and bookmarks all work. | US1, FR-026, SC-007 |
| 2 | Page turning | Swipe through pages 1–10 and back | Next page lies to the left. No blank or loading frame. Header shows surah, juz, page. | FR-004, FR-008, SC-002 |
| 3 | Surah starts | Open Al-Fatiha (p.1), At-Tawbah (p.187), An-Nas (p.604) | Header frames are correct. No basmala before At-Tawbah. Al-Fatiha's basmala is ayah 1. | FR-006 |
| 4 | Position restore | Go to p.300, force-stop the app from system settings, reopen | Opens on p.300 | FR-013, SC-005 |
| 5 | Navigation | Reach Al-Kahf, Juz 30, quarter 120, page 300, 2:255 | Each in ≤3 taps or entries. 2:255 highlighted. Page 605 or 2:300 rejected with range shown. | US2, FR-012, SC-004 |
| 6 | Bookmarks | Bookmark 3 ayat (one twice), restart, open one, delete one | 3 rows, newest first, no duplicate. Indicator updates. | US3, FR-014/015 |
| 7 | Layout toggle | On p.50, select an ayah, toggle to flowing, then back | Same ayah in view each time, within 1 s | FR-003, SC-010 |
| 8 | Flowing text size | Flowing layout: set size 18, then 34 | No colliding diacritics. Line height stays 2×. | FR-017 |
| 9 | Theme and screen | Night theme, keep-screen-on on, wait past the auto-lock time | Readable night page. Screen stays on. Settings persist after restart. | US4 |
| 10 | Language | Device in English: open app, then switch to Arabic in settings | English LTR interface with transliterated surah names, Mushaf unchanged. Arabic RTL immediately, same ayah. Device in French gives English. | FR-025 |
| 11 | Copy and share | Long-press 2:255, share to a messaging app, then copy | Text matches the [share format](./contracts/ui-screens.md#shared-and-copied-text-format-fr-021) exactly | US5, FR-020/021 |
| 12 | Search | Search «الرحمن الرحيم» without diacritics, then «زززز» | Results with highlighted matches and count in < 1 s, and the tap opens the ayah. Second query shows "no results". | US6, FR-022, SC-006 |
| 13 | Accessibility | TalkBack / VoiceOver on: navigate index → open a surah → settings | All controls labelled in the interface language | FR-029 |
| 14 | Large font / small screen | Max system font scale; smallest supported phone | No clipped interface text. Mushaf page fits with no horizontal scroll. | Edge cases |

## Performance and size gates (constitution III and IV)

Release builds on the reference devices:

```powershell
# Android cold start: time to first frame of the Reader, average of 5 cold launches, target ≤ 2 s
flutter run --release --trace-startup
# Frame times while paging 50 pages and scrolling the flowing layout: no janky frames
flutter drive --profile --driver=test_driver/perf_driver.dart --target=integration_test/paging_perf_test.dart
# Download size: Android per-device ≤ 30 MB (and iOS ≤ 30 MB in the cloud macOS build)
flutter build appbundle --release --analyze-size
```

On iOS, measure cold start and frames with Xcode Instruments (App Launch and Animation Hitches
templates) on the iPhone SE (2nd gen). Record all numbers in the PR description; a regression
blocks merge.

## Release readiness

- `tool/verify_quran.dart` passes, and the `quran.db` SHA-256 is recorded (SC-003).
- Licence dependencies **D1** (KFGQPC font) and **D2** (QUL data) are resolved, or the fallback
  font is built in. See [research.md](./research.md).
- About screen shows the Tanzil, QUL and KFGQPC attributions and the tanzil.net link.
- Store listings are ready in Arabic and English, with privacy forms declaring no data collected.
