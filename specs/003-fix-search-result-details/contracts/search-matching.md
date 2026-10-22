# Contract: Search Matching

Replaces the substring rule of feature 001 research R7 (normalisation is unchanged). Implemented
by `SearchIndex.search` in `lib/features/search/search_index.dart`. Each example below is a unit
test.

## Input

- `query`: any string. It is normalised with `normalizeArabic` (unchanged) and split on spaces
  into tokens. An empty normalised query returns `SearchResults.empty`.

## Stems of a searchable word *w*

1. *w* itself.
2. For each prefix *p* below that *w* starts with, where at least 2 letters remain, *w* without
   *p*:

   `وال فال بال كال ولل فلل وب وك ول فب فك فل ال لل و ف ب ك ل`

3. If *p* ends in «لل», also «ال» + the rest.
4. **Name of Allah**: if *w* is «الله» or «اللهم», optionally preceded by «و», «ف» or «ب», or is
   «لله», «ولله» or «فلله»: no article or «ل» is stripped. Only the leading «و», «ف» or «ب» is
   removed (giving «الله» or «اللهم»).

## Match

Tokens *t₀…tₙ₋₁*, searchable words *w₀…wₘ₋₁* of an ayah. A match starts at *i* when, for every
*k* in 0…n−1:
- *k < n−1*: some stem of *w_{i+k}* equals *tₖ*;
- *k = n−1*: some stem of *w_{i+k}* starts with *tₖ*.

## Output

- One hit per ayah with at least one match, in Mushaf order.
- `hit.occurrences` = number of starting positions *i*.
- `hit.matchedWordIds` = Uthmani word ids of *w_i…w_{i+n−1}* for every match.
- `results.occurrences` = Σ `hit.occurrences`.

## Examples (unit tests)

| Query | Must find (in some ayah) | Must not find |
| --- | --- | --- |
| «من» | من، ومن، فمن، منهم | المؤمنين |
| «الله» | الله، والله، بالله، فالله، اللهم | — |
| «لله» | لله، ولله | الله |
| «له» | له، ولهم | الله، لله |
| «رحم» | رحمة، الرحمن، برحمته | — |
| «المتقين» | المتقين، للمتقين | — |
| «متقين» | المتقين، للمتقين | — |
| «يا ايها الذين امنوا» | 89 ayat | — |
| «قل هو الله احد» | 112:1 only | — |
| «ال» | الحمد، والارض، للمتقين (and «والده», whose «ال» is not the article; accepted) | — |

**Regression counts** (ayat / occurrences), recorded on 2026-10-22 with the prototype and
confirmed by the implementation (`test/unit/search_index_test.dart`):

| Query | Ayat | Occurrences |
| --- | --- | --- |
| «من» | 2,582 | 4,075 |
| «الله» | 1,737 | 2,547 |
| «يا ايها الذين امنوا» | 89 | 89 |
| «الرحمن الرحيم» | 6 | 6 |
| «المتقين» | 43 | 43 |

## Budgets

- Building stems: once per app session, ≤ 150 ms on the reference phones.
- Any query: ≤ 100 ms on the reference phones (feature 001 SC-006 allows 1 s).
