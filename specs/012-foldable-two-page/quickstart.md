# Quickstart: Validating the Two-Page Spread

## Prerequisites

- Flutter 3.47.7. Xcode 27 with the iPhone Duo simulator (iOS 27).
- Android Studio with a Galaxy Z Fold emulator profile (or the resizable "7.6 Fold-in" AVD), on
  Android 14 and on Android 16.
- The reference phones of specs/001: iPhone SE (2nd gen) and Galaxy A15.
- A desktop Chrome for the web build.

## Automated

```sh
flutter analyze
flutter test test/unit/spread_fits_test.dart test/unit/reader_spread_place_test.dart
flutter test test/widget/two_page_spread_test.dart test/widget/keyboard_test.dart \
  test/widget/wide_window_test.dart test/widget/mushaf_page_renderer_golden_test.dart
flutter test   # the full suite: the single-page goldens must pass unchanged (SC-005)
```

## Manual checks

| # | Check | Expected |
| --- | --- | --- |
| Q1 | Duo simulator, open, Mushaf at page 50. Note the reading-area size (debug overlay). | Pages 49 (right) and 50 (left). The size is in R1's range. Record it in research R1. |
| Q2 | Swipe forward and back. Go to pages 1 and 604. | 51–52, 47–48. 1–2 and 603–604, with no blank page (SC-001). |
| Q3 | Fold at page 77, then open. Long-press an ayah on 78, close, fold. Repeat 20 times at random pages. | 77, then 77–78, then 78. Each time within 1 s. Reopen the app: same page (SC-002). |
| Q4 | Open: long-press on both pages, play a recitation across both pages, memorize a range across both pages, open «عرض المتشابه» on the left page, bookmark. | All as on one page. No turn while the recited ayah is on the spread, a turn after the left page. Header «صفحة ٤٩–٥٠» (SC-006). |
| Q5 | VoiceOver on the Duo, TalkBack on the Z Fold. | Right page read before left. "Show controls" action on both. |
| Q6 | Profile mode, swipe 20 spreads on the Duo and the Z Fold. | No dropped frames over the 60 fps budget, and no blank page on a turn (SC-004). |
| Q7 | iPhone SE and Galaxy A15: page through 20 pages, cold start, memory. | The same as the previous build (SC-005). No settings row for two pages. |
| Q8 | Z Fold open upright, then sideways, on Android 14 and 16. | Two pages both ways. Folded: one page, portrait. |
| Q9 | Settings → turn «عرض صفحتين عند الاتساع» off and on. | One page, then two, at the same page each time. |
| Q10 | Duo open with another app in Split View. | One page while the app's half is narrow. |
| Q11 | Desktop Chrome: resize from 1440 × 900 down to 700 wide and back. Use arrow keys. | Two pages in a wider column, then one page in the 480 column, place kept. Arrows turn two pages (SC-007). |
| Q12 | Measure the text block on the open Duo against the folded Duo, at the same page. | Open ≥ 90% of folded (SC-003). |
