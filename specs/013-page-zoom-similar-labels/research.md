# Research: Surah Header Width, Sideways Scrolling Page, Named Similar-Ayah Tabs

Decisions for [plan.md](./plan.md). Each one lists what was chosen, why, and what was rejected.
There are no open NEEDS CLARIFICATION items.

## R1. Margins: what the page does today

**Finding**: `PageGeometry.of` already does what FR-001 to FR-003 ask.

- The header and footer bands are 0.6 of a line high and start at the text block's edges. The
  detail text is 0.32 of a line high and centred in its band, so the gap to the block is about
  0.14 of a line.
- The text block is 91% of the page width. The other 4.5% on each side holds the hizb-quarter
  and sajdah marks, which are 0.7 em wide. There is no room to take from the sides.
- On a 360 × 780 phone the block is limited by the width. The page (block and bands) is 626 px
  high, so 154 px of paper is left over, half above and half below. Seen in
  `build/screenshots/p187_tawbah.png`.

**Decision**: no layout change. The owner was shown the three options (spread the lines to fill
the height, leave it, pin the details to the screen edges) and chose to leave it.

**Guard**: the existing 21 single-page goldens and `mushaf_typesetting_test.dart`. Pages without
a surah title must stay pixel-identical (SC-002).

**Rejected**: growing the line spacing to fill a tall screen. It reverses a specs/002 rule, and
the owner declined it.

## R2. Surah header from side to side

**Finding**: `_paintSurahHeader` sets the header font size to the smaller of two limits: the
width limit `block.width / 3.302`, and the height limit `0.9 × lineHeight / 0.40`. The line is
`1.77 / 15 = 0.118` of the block width, so the height limit always wins. The header's ink ends
up `0.9 × 0.118 / 0.40 × 3.302 × 0.98 = 86%` of the block width.

**Decision**: size the header by width only, so that its ink is exactly as wide as the block:
`fontSize = block.width / (_headerAdvanceEm × _headerInkShare)`, with a new constant
`_headerInkShare = 0.98`. The height limit is removed. The glyph stays centred on its line.

- The ink is then `0.40 / (3.302 × 0.98) = 0.1236` of the block width high, which is 105% of the
  line. It reaches 2.4% of a line past the line's top and bottom: 0.6 px on a 360 px wide phone,
  1.9 px on the sideways page.
- Beside ayah lines that is inside the clear space: they keep their ink centred in the slot. A
  header never follows another header directly.
- **Found during implementation**: when the header is the first line, the letters of the surah
  and juz line have tails («ر», «م») that reach the top of the block. With the header at full
  width they touched its frame. On pages where a header glyph is the first or the last line,
  the page details beside it now move away by the header's overflow plus 0.16 of a line. The
  gap to the text stays under half a line (FR-001), and pages without a header at the edge are
  unchanged (SC-002).
- The plain frame, drawn when the header font did not load, already spans the block. No change.
- The same code path serves portrait, the spread, the sideways page and the web (FR-025).

**Tests**: `RenderMushafPage` exposes the header ink rectangles for tests. A widget test walks
every page that has a surah title (all 114 headers) and checks width within 1% of the block
(SC-010) and that the ink passes its line by at most 3%. A second test draws, with the real
header font, every page whose first or last line is a header, and checks the pixels: the glyph
fills the rectangle it reports, and clear paper separates it from the page details (FR-026).
The goldens draw the plain frame, so none changed.

**Rejected**:
- Stretching the glyph sideways with a transform: distorts the calligraphy (FR-026).
- Giving the header line more height: moves every other line and breaks the 15-line grid.

## R3. Letting the app turn sideways

**Finding**: Android's manifest has `android:screenOrientation="portrait"`, and
`syncOrientation` in `app.dart` unlocks rotation at run time on large screens (specs/012 R6).
iOS lists only `UIInterfaceOrientationPortrait` in `Info.plist`.

**Decision**:
- **Android**: the manifest says `android:screenOrientation="user"`. The system then follows
  the sensor, respects the rotation lock, and allows only the rotations the device allows
  (phones do not turn upside down). `syncOrientation`, its call in the app builder and its test
  are deleted: large screens get the same value, so the run-time switch has nothing left to do.
- **iOS**: `UISupportedInterfaceOrientations` gains `UIInterfaceOrientationLandscapeLeft` and
  `UIInterfaceOrientationLandscapeRight`. Upside down stays out. iOS applies its own rotation
  lock.
- The activity already handles `orientation|screenSize` config changes, so it is not recreated
  and a recitation keeps playing (FR-014).
- The web is untouched.

**To verify on devices** (quickstart Q2): `"user"` on Android 7 and on a current Android, with
the lock on and off; the launch screen in landscape on both platforms.

**Rejected**: `SystemChrome.setPreferredOrientations` per screen. It needs code on every route,
and iOS applies it late, so the screen flips visibly. The owner chose that the whole app turns.

## R4. When the page scrolls

**Decision**: one function in `mushaf_view.dart`, next to `showsSpread`:

```text
scrollsPage(context) =
    not web
    and the layout is Mushaf
    and two pages do not fit the screen (spreadFitsScreen is false)
    and the screen is wider than it is tall
```

- It reads `ScreenArea.sizeOf`, the whole screen, like `spreadFits`. The system bars and the
  docked recitation bar never flip it.
- It uses `spreadFitsScreen`, not `showsSpread`. A screen where two pages fit (an open foldable,
  a tablet) keeps the specs/012 behaviour whatever the two-pages setting says (FR-015).
- Phone sizes, sideways: 780 × 360, 852 × 393 and 667 × 375 all fail `spreadFits` (each page's
  block would be under 240 px), so they scroll.

**Rejected**:
- A device check (phone or tablet): the size rule already separates them.
- Scrolling in the web app: FR-015 keeps wide windows as they are, and FR-024 limits rotation
  to iOS and Android.

## R5. The scrolling page

**Decision**: `_MushafPageItem` wraps today's page tree in a vertical scroll view when
`scrollsPage` is true. Nothing else in the tree changes.

```text
SingleChildScrollView (vertical, clamping physics, own ScrollController)
└── SizedBox (height: PageGeometry.scrollPageHeight(width))
    └── RepaintBoundary
        └── today's tree: Semantics › GestureDetector › PaperSheet › MushafPageRenderer
```

- `PageGeometry.scrollPageHeight(width)` is the height of a page whose block is limited by the
  width: block height, both bands, plus one line of paper so the details do not touch the
  screen edge. `PageGeometry.of(Size(width, thatHeight))` then gives a width-limited block, so
  `RenderMushafPage` needs no layout change.
- Text size: the block is 91% of the safe width. Sideways against portrait this gives 1.92×
  on 360 × 780, 1.87× on 393 × 852 (59 px insets) and 1.79× on 375 × 667. SC-003 asks for 1.7×.
- Clamping physics on both platforms: scrolling stops at the page's top and bottom (FR-008),
  and an overscroll bounce does not fight the sideways page swipe.
- Gestures: a vertical drag scrolls, a horizontal drag turns the page (the two recognisers
  compete by axis), and tap and long-press reach the same `GestureDetector` as today.
- The `RepaintBoundary` lets a scroll replay the page's recorded picture. `paint()` does not
  run per frame.
- **Top of the page** (FR-009, FR-010): a new scroll view starts at 0. An item that is kept
  alive beside the current page resets to 0 when it is no longer the reader's page.
- **Controls**: a scroll started by the reader hides the controls, like a page turn. The item
  calls the existing `onPageTurned` callback on a drag-started scroll.
- **Rotation**: the one-page `PageView` keeps its key and controller, and `PageView` keeps its
  page when its width changes. The renderer keeps its `GlobalKey`, so it moves into and out of
  the scroll view without losing its painters.

**Rejected**:
- `InteractiveViewer` with a scale: free panning and pinch are out of scope, and a scaled
  picture is blurrier than text laid out at the larger size.
- A separate sideways renderer: the existing one already lays out at any size.
- Keeping the scroll offset per page: FR-009 wants a turned-to page at its top.

## R6. Bringing an ayah on screen

**Decision**: `RenderMushafPage.ayahRect(ref)` returns the union of the ayah's word rectangles
on this page (or the basmala line, for a recited basmala). The page item has one follow target:

```text
target = the recited ayah or basmala, else the highlighted ayah,
         else the memorization session's expected ayah — when it is on this page
```

When the target changes, or the scrolling page first appears with a target, the item scrolls
after the frame:

- if the rectangle is fully visible: nothing;
- otherwise: the rectangle's top goes one line below the top of the viewport, clamped to the
  scroll range. An ayah taller than the viewport is aligned the same way.
- It animates over 200 ms when the page was already showing, and jumps when the page has just
  appeared.

`reader.jumpTo(ref)` already sets the highlight, so search, bookmarks, the index and the
similar-ayah sheet are covered (FR-011). A page jump without an ayah shows the top.

**Rejected**: `Scrollable.ensureVisible`: it needs a render object per ayah, and the page is a
single render object.

## R7. Other screens sideways

**Decision**: no redesign (FR-013). One widget test pumps each screen and sheet at 780 × 360
with 44 px side insets, at text scale 1.0 and 1.3, in both languages, and fails on any overflow
or on a control outside the safe area. Fixes are limited to making content scroll and adding
missing `SafeArea` sides.

Screens and sheets covered: reader (flowing layout, header, toolbar, recitation and memorization
bars), ayah actions, similar-ayah sheet, index, go-to sheet, search, settings, reciter sheet,
downloads, memorization range sheet and result screen, prayer times and its three sheets,
onboarding (setup steps and button tour).

**Result**: the test found two overflows: the ayah actions sheet and the memorize sheet. Both
now scroll. The onboarding needed no change. The memorization result screen and the three prayer
sheets are not in the test and stay device checks.

**Rejected**: keeping some screens upright. The owner chose that the whole app turns.

## R8. Shared wording for the tabs

**Finding**: the rule first written in the spec (the longest run of words found in every ayah of
the group) was run on the published content: 72 groups, 16 ayat that are in two groups, 32 tabs.
Nine of the 32 tabs came out as one common word or nothing: «بِٱللَّهِ», «ٱللَّهِ», «وَإِذْ»,
«ٱلَّذِينَ», «بَعْدِ». Similar ayat differ by definition, so few words survive in all of them.

**Decision**: the wording is taken from the pressed ayah.

1. Split each ayah of the group into words, without the ayah-end marker. The matching key of a
   word is `normalizeArabic(text)` (the search normaliser: no vowel or pause marks, unified
   letter forms).
2. Find the longest run of consecutive words of the pressed ayah whose keys appear, in order and
   adjacent, in at least half of the group's other ayat. Ties go to the earliest run.
3. If that run has fewer than two words, find the longest run that appears in at least one
   other ayah.
4. No run at all: the tab shows the group's number (FR-019).
5. The label is the Uthmani text of the run's first five words, pause marks removed, joined by
   spaces, plus «…» when words were cut (FR-018).
6. If two tabs of the sheet have the same label, each adds its number: «… (٢)» (FR-020).

Results on the published content, for the 32 tabs:

| Rule | Tabs with two or more words | Examples |
| --- | --- | --- |
| In every ayah | 23 | 4:155 → «ٱللَّهِ»; 2:126 → «وَإِذْ» |
| Chosen rule | 31 | 4:155 → «ٱلْأَنۢبِيَآءَ بِغَيْرِ حَقٍّ»; 2:162 → «يُخَفَّفُ عَنْهُمُ ٱلْعَذَابُ وَلَا هُمْ» and «وَلَا هُمْ يُنظَرُونَ» |

The one single-word tab is «لِلْفُقَرَآءِ» (2:273), which is the point of that group. Three ayat
(16:85, 2:126, 14:35) get the same wording on both tabs, because their two groups overlap; rule 6
adds the numbers.

**Where it runs**: `showSimilarSheet` loads the words of the groups' ayat and computes the labels
before it opens the sheet, and only when the ayah has two or more groups. The ayah is marked as
selected first, which is the feedback within 100 ms (SC-009). The words come from the local
database. The largest case is 31 short ayat.

**Cost**: at most a few thousand word comparisons. No caching.

**Tests**: unit tests of the pure function (rules 1 to 6), and one test over the bundled content
file and database that checks SC-006 and SC-007.

**Rejected**:
- In every ayah: see the finding.
- Shared with any one other ayah only: longer labels, but 2:162's two tabs come out the same.
- A label written by the owner: the owner chose the automatic route in the clarify session.
- A Unicode normalisation package for matching: `normalizeArabic` is already in the app.

## R9. Tab layout

**Decision**: keep the `Wrap` of `ChoiceChip`s. Each label is one line of Quran text in
`TypeScale.quranFamily`, right-to-left, with ellipsis overflow and a maximum width of the sheet's
content width. Chips that do not fit continue on the next row, so every tab stays visible and
reachable (FR-021). The semantics label is the wording (or «Group n»), with the selected state.

**Rejected**: one horizontally scrolling row. It hides tabs off screen, and with five-word
labels most sheets would show only one or two.
