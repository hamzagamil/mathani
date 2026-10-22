# Contract: Search Screen

Updates the **Search** row of [001 ui-screens](../../001-quran-mushaf-reader/contracts/ui-screens.md).
Entry, exit, layout and direction rules are unchanged.

## Summary line

Shown under the query field when the normalised query is not empty. It is a live region.

| Case | Arabic | English |
| --- | --- | --- |
| no hits | لا توجد نتائج. | No results. |
| occurrences == ayat | `searchAyatCount`: «٦ آيات» | "6 ayat" |
| occurrences > ayat | `searchSummary`: «٢٥٤٧ موضعًا في ١٧٣٧ آية» | "2,547 occurrences in 1,737 ayat" |

Plural forms follow [research S4](../research.md#s4-the-result-summary-fr-006). Numbers use the
interface numerals (`formatNumber`).

New `.arb` keys: `searchSummary` (placeholders `occurrences` int, `occurrencesShown` String,
`ayat` int, `ayatShown` String), `searchAyatCount` (`ayat` int, `ayatShown` String). The key
`searchResultCount` is removed.

## Result row

- **Identity**: keyed by ayah id. A row never shows another ayah's text.
- **Title**: `bookmarkTitle` («سورة {name}، الآية {n}» / "Surah {name}, ayah {n}"), unchanged.
- **Body**: the ayah's Uthmani words, without the ayah-end marker. Every word in
  `hit.matchedWordIds` has the `selected` background. No other word does.
- **Loading**: a 38-point neutral placeholder.
- **Tap**: `reader.jumpTo(hit.ayah.ref)` and close search. The ayah shown is the ayah opened.

## Query field

Unchanged: 200 ms debounce; results apply only if the field still holds the query they were
computed for; the clear button empties the field and the list.
