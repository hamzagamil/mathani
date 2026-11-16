# UI Contract: Surah Header, Sideways Page, Similar-Ayah Tabs

What the reader sees and what each piece of code promises. Reasons are in
[research.md](../research.md).

## Surah header

- On every Mushaf page, in every mode, the header glyph's ink starts at the right edge of the
  text block and ends at its left edge (within 1% of the block width).
- The glyph is drawn at one font size in both directions. It is centred on its line slot.
- Its ink may pass the line slot by at most 3% of a line at the top and at the bottom. It never
  overlaps the ink of the line above or below, or the page details.
- Without the header font, the plain frame with the surah name is drawn, as wide as the block
  (unchanged).
- `RenderMushafPage.surahHeaderRects` (tests only): the ink rectangle of each header on the page.

## Page details and margins

`PageGeometry.of` gives the same block, bands and font size for the same size as before this
feature. On every page whose first and last lines are not surah headers, the details are drawn
exactly where they were.

Where a header glyph is the first line, the surah and juz line is drawn higher by the header's
overflow plus 0.16 of a line, so the tails of its letters do not touch the frame. Where a
header glyph is the last line, the page number is drawn lower by the same amount.

## Decision: `scrollsPage(context)`

```text
bool scrollsPage(BuildContext context)   // lib/features/reader/mushaf_view.dart
```

True when all hold: the build is not web; the layout is Mushaf; `spreadFitsScreen(context)` is
false; `ScreenArea.sizeOf(context)` is wider than it is tall. It is the only place this is
decided.

## The scrolling page

| Reader does | Result |
| --- | --- |
| Turns the phone sideways on a Mushaf page | Same page, at full width, scrolled to its top, or to the follow target if there is one |
| Drags up or down | The page scrolls; it stops at its top and bottom without bouncing; the controls hide |
| Swipes sideways | Next or previous page, in the Mushaf's direction, at its top |
| Taps | Clears a selection, else shows or hides the controls (unchanged) |
| Long-presses an ayah (or right-clicks) | The ayah actions (unchanged) |
| Turns the phone upright | The whole page, same page number |

Layout:
- The page is as wide as the reading area inside the safe areas. A camera cut-out on either side
  is outside it.
- Its height is `PageGeometry.scrollPageHeight(width)`. The paper, grain and binding shade cover
  the whole height.
- The reader header and toolbar lie over the page as today and hide on a page turn or a scroll.
  A docked recitation or memorization bar stays below the page; the page scrolls above it.

Following (FR-011): when the follow target changes and its rectangle is not fully visible, the
page scrolls so that the rectangle's top is one line below the top of the viewport. 200 ms
animation, or a jump when the page has just appeared. A scroll made by following does not hide
the controls.

Screen readers: the page keeps its one label. The scroll view adds the standard scroll up and
scroll down actions. With screen-reader navigation on, the controls stay visible, as today.

`RenderMushafPage.ayahRect(AyahRef ref)`: the union of the ayah's word rectangles on this page,
in the page's coordinates, or null when it has no word here.

## Rotation

- Android: `android:screenOrientation="user"`. iOS: portrait, landscape left, landscape right.
- Every screen follows the device and the system rotation lock. No screen sets its own
  orientation.
- No screen overflows or puts a control outside the safe area at 780 × 360 with side insets, at
  text scale 1.0 and 1.3.
- Turning the phone does not stop audio, close a sheet or dialog, clear typed text, or change
  the reader's page.

## Similar-ayah tabs

Shown only when the pressed ayah has two or more groups (unchanged).

```text
// lib/features/mutashabihat/shared_wording.dart — plain Dart, no Flutter
List<String> tabLabels({
  required List<String> pressed,            // Uthmani words of the pressed ayah, no end marker
  required List<List<List<String>>> groups, // for each group: the words of each other ayah
  required String Function(String) key,     // normalizeArabic
  required String Function(int n) number,   // formatNumber for the locale
})
```

Returns one label per group, in content order, by the rules of research R8:

1. the longest run of the pressed ayah found in at least half of the group's other ayat;
2. if under two words, the longest run found in at least one other ayah;
3. no run: `number(n)`;
4. at most five words, pause marks removed, «…» when cut;
5. equal labels get ` (${number(n)})` added.

Tab:
- A `ChoiceChip` in the existing `Wrap`, in content order; the first is selected when the sheet
  opens.
- Label: one line, Quran font, right-to-left in both interface languages, ellipsis overflow, no
  wider than the sheet's content.
- Minimum touch target 48 × 48.
- Semantics: label = the tab's text for a wording tab, `similarGroup(n)` («Group n») for a
  number tab; `selected` and `button` as today.

`showSimilarSheet(context, ref)`: selects the ayah, then, for two or more groups, loads the
words and computes the labels, then opens the sheet. `SimilarSheet` takes the labels as a
parameter.

Strings: none added. `similarGroup` stays for number tabs.
