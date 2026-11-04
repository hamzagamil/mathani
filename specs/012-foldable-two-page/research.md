# Research: Two-Page Spread on Foldable Phones

## R1. When two pages show

- **Decision**:
  - `PageGeometry.spreadFits(Size area)` decides. `area` is the whole screen: the `MediaQuery`
    size, or on the web the browser window, which `PhoneColumn` passes down as `ScreenArea`
    before it narrows `MediaQuery` (R7). Nothing is subtracted: not the safe areas, not the
    docked recitation or memorization bar.
  - *Changed during implementation:* the first design subtracted the safe areas. On Android those
    shrink when the controls hide (immersive mode). An open Z Fold sits near the threshold, so a
    tap could flip it between one and two pages. The whole screen is stable, and the share was
    lowered from 0.8 to 0.7 to keep the Z Fold 5 and 6 (0.72–0.75) on two pages.
  - With the existing constants, the text block of a page `w` wide and `h` tall is
    `min(0.91 w, h / 1.9116)` (side margins of 4.5%, block ratio 1.77, bands of 0.6 line above and
    below). Let `one = block(W, H)` and `two = block(W / 2, H)`.
  - Two pages show when `two ≥ 0.7 × one` and `two ≥ 240` logical px.
  - Reference sizes (whole screens in points or dp, rounded; `test/unit/spread_fits_test.dart`):

    | Screen | Area | One page | Two pages | Share | Result |
    | --- | --- | --- | --- | --- | --- |
    | iPhone SE (2nd gen) | 375 × 667 | 341 | 171 | 0.50 | one |
    | iPhone 16 | 393 × 852 | 358 | 179 | 0.50 | one |
    | iPhone Duo, folded | 466 × 678 | 355 | 212 | 0.60 | one |
    | iPhone Duo, open | 890 × 626 | 327 | 327 | 1.00 | **two** |
    | iPhone Duo, open, half in Split View | 445 × 626 | 327 | 202 | 0.62 | one |
    | Galaxy Z Fold 7, folded | 412 × 915 | 375 | 187 | 0.50 | one |
    | Galaxy Z Fold 7, open upright | 750 × 832 | 435 | 341 | 0.78 | **two** |
    | Galaxy Z Fold 7, open sideways | 832 × 750 | 392 | 379 | 0.97 | **two** |
    | Galaxy Z Fold 6, open upright | 714 × 831 | 435 | 325 | 0.75 | **two** |
    | Galaxy Z Fold 5, open upright | 690 × 829 | 434 | 314 | 0.72 | **two** |
    | Android tablet, upright | 800 × 1280 | 670 | 364 | 0.54 | one |
    | Desktop browser | 1440 × 900 | 471 | 471 | 1.00 | **two** |
    | Small browser window | 600 × 400 | 209 | 209 | 1.00 | one (under 240) |

  - The Duo's open size comes from published viewport figures (890 × 626 pt). Quickstart Q1
    checks it on the simulator.
- **Rationale**:
  - The rule compares the two layouts on the same screen, so it holds for future foldables
    without a device list (FR-001).
  - The 0.7 ratio lets an upright Z Fold 5–7 show two pages. Each page is still about 91% of the
    folded single page (SC-003). Every one-page case is at 0.62 or below.
  - The 240 px floor keeps small windows on one page. It sits below the open Duo (327) and the
    smallest single-page golden (291 at 320 px wide).
  - Ignoring the system bars and the docked bar stops the layout flipping when the controls hide
    or a recitation starts (FR-001).
- **Alternatives considered**:
  - Device-model detection: rejected by FR-001, and it would miss Android foldables.
  - "Wider than tall": an upright Z Fold (0.95) would get one page although two fit well.
  - An absolute floor at the iPhone SE size (341): the open Duo (279–304) would never get two
    pages.

## R2. Two pages in the view

- **Decision**:
  - `MushafView` takes `spread` from `showsSpread(context)`: Mushaf layout, `twoPages` on, and
    `spreadFits`. With `spread` false, the build is today's code path, untouched.
  - With `spread` true, a second `PageView.builder` has `itemCount: 302`. Item `i` is a
    `Row` in right-to-left `Directionality` holding `Expanded(_MushafPageItem(2i + 1))` and
    `Expanded(_MushafPageItem(2i + 2))`. Right to left puts the odd page on the right.
  - `_MushafPageItem` gets a `bindingOnRight` parameter. One page passes `page.isOdd`, as today.
    In a spread the odd page passes `false` and the even page passes `true`, so the shades meet in
    the middle (FR-006).
  - Each mode has its own `PageController`, created at the reader's page: index `page - 1` for
    one page, `(page - 1) ~/ 2` for two. Going from two pages to one, a selected or highlighted
    ayah on the other page of the spread decides the page shown, and the reader's page follows
    it (FR-010). The `PageView` carries a `ValueKey(spread)`, so a
    switch replaces it. That cancels any swipe in progress (spec Edge Cases). Creating a
    controller does not call `onPageChanged`, so the switch does not move the place (FR-011).
  - `onPageChanged` in two-page mode calls `reader.onMushafSpreadShown(2i + 1)` and prefetches
    pages `2i - 1` to `2i + 4`. With `allowImplicitScrolling`, the neighbouring spreads are laid
    out. Six pages are in use, inside the existing 7-page cache.
  - Jumps (`jumpSerial`): the target index is the spread of `reader.page`. If that spread is
    already on screen there is no jump, so a recitation crossing to the left page does not turn
    (FR-009).
  - `PageGeometry.of` caches one size. Both pages of a spread are the same size, so the cache
    still hits.
- **Rationale**: Each page keeps its own gestures, renderer, semantics and loading state, so
  long-press, selection, marks and the retry message work per page with no new code (FR-008).
- **Alternatives considered**:
  - One `PageView` with `viewportFraction: 0.5`: a swipe would move one page, not two, and the
    pairs would not stay odd–even.
  - Drawing two pages in one renderer: this would duplicate hit-testing and semantics.

## R3. The reader's place on a spread

- **Decision**: `ReaderController.onMushafSpreadShown(int rightPage)`:
  - If `page` is `rightPage` or `rightPage + 1`, nothing changes. The place is already on this
    spread, for example the left page after a jump or a recitation.
  - Otherwise, if the selected or highlighted ayah is on this spread, `page` becomes its page and
    the anchor stays.
  - Otherwise, `page` becomes `rightPage` and the anchor its first ayah, as `onMushafPageShown`
    does today.
  - The saved position is scheduled the same way.
- **Rationale**:
  - FR-010 and FR-011: one page is the place. On a fold, the single view opens at `reader.page`,
    which is the right page unless an ayah on the left one holds the place.
  - Recitation (`_followJump` sets the page through `jumpTo`), bookmarks, Listen
    (`playFromPage(reader.page, anchor:)`) and Memorize keep working without changes. The
    recitation controller only unfollows when `page` moves away from the recited page, which a
    spread turn does and a jump within the spread does not.
- **Alternatives considered**: a `spread` field in the controller. That would duplicate
  `page`, and every user of `page` would need two cases.

## R4. Controls on a spread

- **Decision**:
  - **Header**: with `showsSpread`, the label is `pagesLabel(first, second)`: «صفحة ٤٩–٥٠» /
    "Pages 49–50". Surah and juz come from `pageHead`, as today.
  - **Bookmark**: filled when `bookmarksOnPage(r)` or `bookmarksOnPage(r + 1)` is not empty.
    Tapping removes the bookmarks on both pages, or adds one at `reader.page`.
  - **Keyboard**: `turn(±1)` moves `±2` from the right-hand page with `jumpToPage`, clamped to
    1–603.
  - **Settings**: a `SwitchListTile`, «عرض صفحتين عند الاتساع», hint «تظهر صفحتان متقابلتان حين
    تتسع الشاشة لهما، كالمصحف المفتوح.» It shows only while `spreadFits` is true for the screen,
    whatever the preference (FR-017). It sits in the reading section, after the lettering
    setting.
- **Rationale**: Each control reads `showsSpread(context)`, the same function the view uses, so
  they can never disagree.

## R5. The iPhone Duo's inner screen

- **Decision**:
  - Build the iOS app with Xcode 27 (iOS 27 SDK). In `ci.yml` and `ios-release.yml`, select it
    explicitly on the `macos-latest` runner. Do not rely on the image default.
  - The deployment target stays iOS 15.0.
  - `UISupportedInterfaceOrientations` stays portrait-only: the outer screen keeps it, and the
    inner screen ignores it (Apple, *Prepare your app for iPhone Duo*). `TARGETED_DEVICE_FAMILY`
    stays iPhone.
  - Before the switch, check that Flutter 3.47.7 builds and runs with Xcode 27. If it does not,
    the Flutter upgrade becomes its own task, and it gates this feature.
- **Rationale**: apps built with earlier SDKs run on the inner screen at a phone size and aspect,
  so the app would never see the wide screen. Apple's guidance is to lay out by size, which R1
  does.
- **Alternatives considered**: keeping Xcode 26. The feature would then work only on Android and
  the web.
- **Follow-up**: App Store screenshots for the inner screen, when App Store Connect offers the
  slot (`store-screenshots.yml`).

## R6. Android rotation on large screens

- **Decision**:
  - Keep `android:screenOrientation="portrait"` in the manifest, so phones never start sideways.
  - On Android, the `MaterialApp` builder syncs the orientation from the screen's shortest side.
    Under 600 dp it locks to portrait up. At 600 dp or more it unlocks with
    `setPreferredOrientations([])`.
  - The sync runs again when the size changes (folding or opening), and only calls the platform
    when the answer changes.
  - On iOS and the web nothing is called.
- **Rationale**:
  - Android 12L–15 honour the portrait lock on an open Z Fold. The app would stay upright there,
    where two pages still fit (R1) but held sideways is often preferred.
  - Android 16 ignores the lock on large screens anyway. Unlocking keeps both versions the same.
  - 600 dp is Android's large-screen threshold. Folded screens and phones are under it.
- **Alternatives considered**: removing the manifest lock. A phone held sideways would start in
  landscape for a moment.

## R7. Wide browser windows

- **Decision**:
  - `PhoneColumn` (specs/008 R13) reads `showsSpread(context)`. `ReaderScope` sits above
    `MaterialApp`, so the builder can read it.
  - When it is true, the column is `min(W, max(960, 2 × PageGeometry.fullPageWidth(H)))` wide
    (about `1.15 H`) instead of 480. That is wide enough for two full-size pages, and never wider
    than the window.
  - The column passes the window's size down as `ScreenArea`. The view, the header and Settings
    decide from the window, not from the column.
  - Otherwise the column stays 480, as today.
  - Sheets, dialogs and other screens follow the column, as on the open Duo (FR-015).
- **Rationale**: one rule for all platforms (FR-016). Everything decides from the same window
  size, so the view and the column always agree.
- **Alternatives considered**: dropping the column in two-page mode. On a 1920 px window each
  page would be 960 px of paper around a 500 px text block.

## R8. Screen readers

- **Decision**: no change. Each `_MushafPageItem` keeps its `Semantics` label. In a right-to-left
  `Row`, Flutter orders semantics right to left, so the right page is read first (spec Edge
  Cases). A widget test checks the order.
- **Rationale**: VoiceOver and TalkBack already handle page labels and the "show controls"
  action per page.
