# Contract: Mutashabihat UI

**Spec**: FR-001 to FR-013, FR-019, FR-020 | **Design**: [research R4–R8](../research.md)

## Strings (`app_ar.arb` / `app_en.arb`)

| Key | Arabic | English |
| --- | --- | --- |
| `showSimilar` | عرض المتشابه | Show similar ayat |
| `similarTitle` | المتشابه | Similar ayat |
| `similarThisAyah` | هذه الآية | This ayah |
| `similarGroup` (n) | المجموعة {n} | Group {n} |
| `similarOpenAyah` (ref) | {ref}، افتحها في المصحف | {ref}, open in the Mushaf |
| `similarAyahSemantics` (n) | الآية {n}، لها متشابه | Ayah {n}, has similar ayat |
| `similarOnPage` (list) | فيها متشابه: الآيات {list} | Similar ayat on this page: {list} |
| `similarClose` | إغلاق | Close |

Numbers follow the existing rule: Eastern Arabic digits in the Arabic interface (`formatNumber`).
The explanation is shown as written, in Arabic, in both interfaces (FR-012).

## Colour

`SemanticColors.similar`: day `#7A4E12`, night `#E2B866` ([research R4](../research.md#r4-the-mutashabih-colour)).
Exposed as `MathaniColors.similar` and `MushafPalette.similar`.

| Situation | Linked ayah drawn in |
| --- | --- |
| Reading, page or flowing layout | `similar` (every word and the end mark) |
| Selected, jump-highlighted or being recited | `similar` text on the existing background |
| Memorization session active | `ink`, as before (no `similar` anywhere while a session is active) |
| Content missing or unreadable | `ink` (nothing linked) |

## Long-press actions sheet

Only for a linked ayah, the first row is:

```
[git-compare]  عرض المتشابه
[play]         استمع من هذه الآية
[memorize]     ...
[copy] [share] [bookmark]   (unchanged)
```

Tapping the row closes the actions sheet and opens the overlay for the same ayah. The ayah stays
selected until the overlay closes.

## Overlay

```
┌──────────────────────────────────┐
│            ───  (drag)           │
│ المتشابه                     [✕] │
│ (١) (٢)          ← only if > 1   │
├──────────────────────────────────┤
│ ┌ هذه الآية ── البقرة ٣٥ ───────┐ │  ↑
│ │ وَقُلْنَا يَٰٓـَٔادَمُ ٱسْكُنْ … ﴿٣٥﴾  │ │  │ two thirds,
│ └──────────────────────────────┘ │  │ scrolls on
│ ┌ الأعراف ١٩ ──────────────────┐ │  │ its own
│ │ وَيَٰٓـَٔادَمُ ٱسْكُنْ …     ﴿١٩﴾  │ │  │
│ └──────────────────────────────┘ │  ↓
├──────────────────────────────────┤
│ في سورة البقرة: «وَكُلَا مِنْهَا   │  ↑ one third,
│ رَغَدًا» …                        │  │ scrolls on
│                                  │  ↓ its own
└──────────────────────────────────┘
```

- **Size**: 92% of the available height, within safe areas. Background `surfaceRaised`. Top
  corners `Radii.lg`.
- **Split**: below the header, the content is split 2:1 (`flex: 2` / `flex: 1`) with a `line`
  divider. Each part scrolls on its own (FR-008).
- **Pressed ayah card**: `selected` background, a «هذه الآية» label and the reference. Not
  tappable.
- **Other cards**: `surface` background with the reference in `caption`/`inkMuted`. The whole
  card is a button, at least 48 dp high. A tap closes the overlay and calls `reader.jumpTo(ref)`,
  which shows the 1.5 s highlight (FR-009).
- **Ayah text**: `flowingTextStyle(colors, preferences.flowFontSize)` in `ink`, right to left,
  with its end marker.
- **Explanation**: `TypeScale.body` in `ink`, right to left, `Space.s3` between paragraphs,
  `Space.s4` side padding.
- **Group chips**: `ChoiceChip` «١» «٢» … in file order, shown only when the ayah is in more than
  one group. They swap both parts and reset their scroll to the top (FR-011).
- **Closing**: the ✕ button (44 pt / 48 dp), back gesture or button, swipe down, or a tap on the
  dimmed page above. All return to the same reading position, with the selection cleared
  (FR-010).
- **Text scaling**: both parts scroll rather than clip. The header wraps.
- **Web**: the same sheet. Esc closes it.

## Screen readers

See [research R8](../research.md#r8-screen-readers-fr-004). The overlay header is announced as a
heading, and the ✕ button by its `similarClose` tooltip.
