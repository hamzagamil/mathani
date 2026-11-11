# Quickstart: Validating Feature 013

How to prove the feature works. Behaviour is defined in
[contracts/reader-ui.md](./contracts/reader-ui.md); sizes and rules in
[data-model.md](./data-model.md).

## Prerequisites

- Flutter 3.47.7, the repository's usual setup.
- An iOS simulator or iPhone, and an Android emulator or phone, with rotation allowed.
- For Q7: the iPhone Duo simulator or a Galaxy Z Fold emulator, and a desktop browser.

## Automated checks

```text
flutter analyze
flutter test
```

New and changed tests, and what each proves:

| Test | Proves |
| --- | --- |
| `test/unit/shared_wording_test.dart` | The tab label rules: half, then any, number fallback, five-word cut, pause marks removed, duplicates numbered |
| `test/unit/shared_wording_content_test.dart` | On the bundled content and database: SC-006 (no equal tabs; wording is in the pressed ayah and one other) and SC-007 (at least 90% of tabs have two or more words) |
| `test/widget/similar_sheet_test.dart` | Tabs show wording, stay on one line, wrap to more rows, keep content order; screen-reader labels |
| `test/widget/surah_header_width_test.dart` | All 114 headers: ink as wide as the block within 1%, no overlap with neighbours or page details (SC-010) |
| `test/widget/sideways_page_test.dart` | At 780 × 360: the page scrolls to its last line; a sideways swipe turns the page and starts at the top; rotation both ways keeps the page; long-press works; following brings the recited, highlighted and expected ayah on screen; a spread-sized screen and the web do not scroll |
| `test/widget/sideways_screens_test.dart` | No overflow on any screen or sheet at 780 × 360, text scale 1.0 and 1.3, both languages (FR-013) |
| `test/widget/mushaf_page_renderer_golden_test.dart` | Pages without a surah title are pixel-identical (SC-002); one new sideways golden |
| `test/widget/two_page_spread_test.dart` | The spread is unchanged; the `syncOrientation` cases are removed with the function |

## Device checks

Run each on one iOS and one Android phone unless it says otherwise.

**Q1. Surah header.** Open pages 187, 604, 1 and 2 in both letterings. The header reaches both
edges of the text, is not stretched, and touches nothing. Repeat on the sideways page.

**Q2. Rotation and the lock.**
- With the system rotation lock off, turn the phone both ways on the reader, the index, search,
  settings and an open sheet. Each follows. Nothing turns upside down.
- With the lock on, nothing turns.
- Cold-start the app while the phone is sideways. The launch screen and first screen look right.
- Android: repeat on an Android 7 emulator.

**Q3. The sideways page (SC-003, SC-004).**
- On page 50, turn the phone. The text is at least 1.7 times its portrait size (measure one
  line's width in two screenshots).
- Scroll to the page number and back. No bounce at either end. No text under the camera cut-out,
  in both sideways directions.
- Swipe to the next and previous page. Each starts at its top.
- Long-press an ayah near the bottom of the page: its actions open.

**Q4. Keeping the place (SC-005).** Turn the phone 20 times at random pages, some during a page
turn. The same page number shows every time, within 1 second.

**Q5. Following.** Sideways:
- Start a recitation at the top of a page and listen to the end of the page. The recited ayah is
  always on screen, and playback has no gap when the phone is turned.
- Open an ayah from search, a bookmark and the similar-ayah sheet. It is on screen, highlighted.
- Start a memorization session. Hidden words stay hidden while scrolling, and the expected ayah
  is on screen.

**Q6. Performance (constitution III).** In a profile build on the reference Android phone, scroll
a sideways page and turn ten pages: no frame over 16 ms in the performance overlay. Compare
memory on the sideways page with the portrait page, and note the difference in the PR.

**Q7. Unchanged elsewhere.**
- Open foldable (or its simulator), either way up: the two-page spread, as before. With the
  two-pages setting off: one whole page, as before, not a scrolling page.
- Desktop browser: a wide and a short window behave as before.
- Portrait phone: pages without a surah title look as before.

**Q8. Tabs (SC-008).** Open «عرض المتشابه» on 2:162, 4:155, 2:87, 2:126 and 16:85.
- 2:162 shows «يُخَفَّفُ عَنْهُمُ ٱلْعَذَابُ وَلَا هُمْ» and «وَلَا هُمْ يُنظَرُونَ».
- 2:126 and 16:85 show the same wording on both tabs, with (١) and (٢).
- For at least four of the five ayat, the tabs tell the groups apart before opening them.
- With VoiceOver and TalkBack, each tab reads its wording and whether it is selected.
- At the largest system text size, every tab can still be reached and tapped.

## Size check

`dart run tool/size_check.dart` reports growth well under 1 MB: no assets or packages are added.
