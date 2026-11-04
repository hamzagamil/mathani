# Data Model: Two-Page Spread on Foldable Phones

## ReaderPreferences.twoPages (stored)

| Field | Type | Default | Stored as |
| --- | --- | --- | --- |
| `twoPages` | `bool` | `true` | `preferences` key `two_pages`, value `'true'` / `'false'` |

- It is read like `keep_screen_on`: `'false'` turns it off, and any other value or a missing key
  reads as the default. Existing installs need no migration.
- It is part of `copyWith`, and it is saved through `ReaderController.updatePreferences`.
- Changing it does not increment `jumpSerial`. The view switches modes at `reader.page`, which
  keeps the place (FR-017).

## Spread (derived, not stored)

| Property | Rule |
| --- | --- |
| right-hand page of page `p` | `p.isOdd ? p : p - 1` |
| left-hand page | right-hand page + 1 |
| index | `(p - 1) ~/ 2`, from 0 to 301 |
| count | 302 (604 ÷ 2; 604 is even, so no blank page) |

## Reader's page (existing `ReaderController.page`)

It stays one page from 1 to 604, and it is saved and restored as today. Two-page mode changes it
only through `onMushafSpreadShown`:

```text
spread with right-hand page r shown
 ├─ page ∈ {r, r+1}                       → no change
 ├─ selected/highlighted ayah on r or r+1 → page = that ayah's page, anchor = that ayah
 └─ otherwise                             → page = r, anchor = first ayah on r
```

`jumpTo`, `jumpToPage` and `onFlowingTopAyah` are unchanged. In two-page mode the view shows the
spread that holds the resulting `page`.

## Display mode (derived per frame, not stored)

`showsSpread = layout == mushaf && preferences.twoPages && PageGeometry.spreadFits(screen area)`

The screen area is the whole screen, or the browser window on the web (`ScreenArea`, research R1
and R7).
