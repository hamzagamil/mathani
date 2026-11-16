# Data Model: Surah Header Width, Sideways Scrolling Page, Named Similar-Ayah Tabs

Nothing is stored. No database table, preference, asset or content-file field is added or
changed. Everything below is worked out at run time.

## Page mode

Which of three forms the Mushaf layout takes. Derived from the screen size and one setting.

| Mode | When | Source |
| --- | --- | --- |
| Whole page | every other case | today's behaviour |
| Two-page spread | two pages fit and the two-pages setting is on | `showsSpread(context)` (specs/012) |
| Scrolling page | not web, two pages do not fit, screen wider than tall | `scrollsPage(context)` ([research R4](./research.md)) |

Rules:
- Spread and scrolling page never apply together: the scrolling page requires that two pages do
  not fit.
- The mode is read from the whole screen (`ScreenArea`), so bars that come and go do not change it.
- A mode change keeps `ReaderController.page` (FR-010).

## Scrolling page geometry

| Value | Definition |
| --- | --- |
| Page width | the width of the reading area inside the safe areas |
| Text block width | page width × (1 − 2 × 0.045), as on the whole page |
| Page height | `PageGeometry.scrollPageHeight(width)`: block height (width × 1.77) + both bands (2 × 0.6 line) + 1 line of paper |
| Scroll range | 0 … page height − viewport height |
| Scroll offset | per page item, not saved; 0 when the page appears or stops being the reader's page |

## Follow target

The ayah the scrolling page keeps on screen (FR-011). At most one per page item.

| Priority | Source | Set by |
| --- | --- | --- |
| 1 | the recited ayah, or the recited basmala's line | recitation (specs/004) |
| 2 | `ReaderController.highlighted` | search, bookmarks, index, similar-ayah sheet, go-to |
| 3 | the memorization session's expected ayah | memorization (specs/006) |

It applies only when the ayah has words on this page. `RenderMushafPage.ayahRect(ref)` gives its
rectangle in page coordinates.

## Surah header

| Value | Before | After |
| --- | --- | --- |
| Font size | min(block width ÷ 3.302, 0.9 × line height ÷ 0.40) | block width ÷ (3.302 × 0.98) |
| Ink width | 86% of the block | 100% of the block |
| Ink height | 90% of the line | 105% of the line |

## Shared wording (tab label)

Worked out when the similar-ayah sheet opens for an ayah with two or more groups.

Input: the pressed ayah's words, and the words of every other ayah of one group
(`QuranRepository.wordsOf`, ayah-end markers removed).

| Field | Type | Rule |
| --- | --- | --- |
| `words` | list of Uthmani words | the chosen run of the pressed ayah, at most five ([research R8](./research.md)) |
| `cut` | bool | true when the run had more than five words |
| `label` | text | `words` without pause marks, joined by spaces, «…» when `cut`; the group's number when there is no run; « (n)» added when another tab has the same label |

Validation:
- Every word of `words` is in the pressed ayah, in order and adjacent.
- The run's keys appear, in order and adjacent, in at least one other ayah of the group.
- Labels of one sheet are pairwise different.

`MutashabihGroup`, `Mutashabihat` and the content file are unchanged.
