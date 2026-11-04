# Contract: Two-Page UI

## Decision

- `PageGeometry.spreadFits(Size area) → bool`: research R1. Pure, with no state.
- `showsSpread(BuildContext) → bool` in `mushaf_view.dart` is the only place that combines the
  layout, the preference and `spreadFits`. Every user listed below calls it, so they cannot
  disagree:

| User | Uses it for |
| --- | --- |
| `MushafView` | one-page or two-page `PageView` |
| `_ReaderHeader` | page label |
| `_BookmarkToggle` | pages to check and clear |
| `ReaderScreen._withKeys` | step of 1 or 2 |
| `PhoneColumn` (web) | column width |
| `SettingsScreen` | whether the switch row shows (with `spreadFits` only, not the preference) |

## Layout

```text
 ┌──────────────────────── reading area (safe areas applied) ────────────────────────┐
 │ ┌───────────── page 2i+2 ─────────────┐┌───────────── page 2i+1 ─────────────┐ │
 │ │                                ░░░░ ││ ░░░░                                │ │
 │ │   (details band)               ░░░░ ││ ░░░░   (details band)               │ │
 │ │   15 lines                     ░░░░ ││ ░░░░   15 lines                     │ │
 │ │                                ░░░░ ││ ░░░░                                │ │
 │ └──────────────── left ───────────────┘└─────────────── right ───────────────┘ │
 └────────────────────────────────────────────────────────────────────────────────┘
   ░ = binding shade (PaperSheet, 12 pt, ink 6% → 0) on each page's inner edge
```

- The two halves are equal (`Expanded`). Each half is laid out by `PageGeometry` as a single
  page is today.
- The header and toolbar overlays, the immersive mode and the docked bar behave as on one page.
  They span the full width.

## Gestures

| Gesture | Result |
| --- | --- |
| Swipe left → right | next spread (pages +2) |
| Swipe right → left | previous spread |
| Tap either page | clears a selection, otherwise shows or hides the controls |
| Long-press / right-click on either page | ayah actions for the ayah under the finger |

## Strings

| Key | Arabic | English |
| --- | --- | --- |
| `pagesLabel(first, second)` | `صفحة {first}–{second}` | `Pages {first}–{second}` |
| `twoPagesSetting` | `عرض صفحتين عند الاتساع` | `Two pages when there is room` |
| `twoPagesHint` | `تظهر صفحتان متقابلتان حين تتسع الشاشة لهما، كالمصحف المفتوح.` | `Shows two facing pages, like an open Mushaf, when the screen is wide enough.` |

Numbers follow the interface language, as `pageLabel` does today (Eastern Arabic in Arabic).

## Semantics

- Each page keeps today's label: `pageSemantics` plus the similar-ayat note. The right page comes
  before the left page in reading order.
- The header's page range is read as text, with no extra label.
- The settings row is a standard switch, with its title and hint.

## Platform

| Platform | Orientation | Notes |
| --- | --- | --- |
| iOS (iPhone) | portrait (Info.plist); the Duo's inner screen ignores it | build with Xcode 27 |
| Android, shortest side < 600 dp | portrait up | manifest lock, and synced at run time |
| Android, shortest side ≥ 600 dp | any | unlocked at run time (R6) |
| Web | window | `PhoneColumn` widens to `min(W, max(960, 2 × fullPageWidth(H)))` in two-page mode |
