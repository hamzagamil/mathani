# Contract: Dividing the Quran into Wirds

**Spec**: [../spec.md](../spec.md) FR-001 to FR-004, FR-030, SC-003, SC-004 | **Research**:
[R2](../research.md#r2-dividing-the-quran-into-wirds) | **File**:
`lib/features/khatma/khatma_division.dart` (plain Dart, no Flutter imports)

## Function

```text
divide(index, startAyah, plan) → List<WirdRange>      WirdRange = (firstAyah, lastAyah)   ayah ids
preview(index, startAyah, plan, startDate) → (wirds, fewestPages, mostPages, finishDate)
```

`index` is what `QuranRepository` already holds in memory: each ayah's page, the 240 quarter
starts and the 114 surah starts. The function makes no query and has no side effect. The same
inputs always give the same wirds.

## Rules

1. **Cover**: the first wird starts at `startAyah`. Each next wird starts at the ayah after the
   one before. The last wird ends at ayah 6236. Every wird has at least one ayah.
2. **By marks**, `marks(q)`: a boundary is the start of quarter 1 + *k*·*q*, for *k* = 1, 2, ….
   A new wird begins at every boundary after `startAyah`.

   | *q* | Daily amount | Wirds from the beginning |
   | --- | --- | --- |
   | 1 | A quarter hizb | 240 |
   | 2 | Half a hizb | 120 |
   | 4 | A hizb | 60 |
   | 8 | A juz | 30 |
   | 16 | Two ajza' | 15 |
   | 24 | Three ajza' | 10 |
   | 80 | Ten ajza' | 3 |

3. **Seven days**, `seven`: a new wird begins at the first ayah of surahs 5, 10, 17, 26, 37 and
   50, where these come after `startAyah`.
4. **Custom**, `days(n)`: let *p* be the pages from the start point's page to page 604, and
   *m* = the smaller of *n* and *p*. Wird *k* (1 to *m*) covers pages ⌊(*k*−1)·*p*/*m*⌋ to
   ⌊*k*·*p*/*m*⌋ − 1, counted from the start point's page. The first wird starts at `startAyah`,
   and every wird ends at the last ayah of its last page. Sizes differ by at most one page.
5. **Pages a day** *P* becomes `days(⌈p / P⌉)`. **A finish date** *F* becomes
   `days(F − startDate + 1)`. *F* may not be before the start date.
6. **A start point off a boundary**: the first wird is simply shorter (rules 2 and 3), or
   starts in the middle of its first page (rule 4).
7. **A wird's number of pages** is its last page minus its first page, plus one: every page it
   touches counts, so "pages 42 to 62" is 21 pages. **Pages left** in a wird, for the page on
   screen, is the wird's last page minus that page, plus one.

## Examples (from the bundled Mushaf data)

| Plan and start | Result |
| --- | --- |
| `marks(8)` from the beginning | 30 wirds. Wird 1: Al-Fatiha 1 to Al-Baqarah 141, pages 1 to 21. Wird 3: Al-Baqarah 253 to Al 'Imran 92, pages 42 to 62, ending in the middle of page 62. Wird 30: An-Naba' 1 to An-Nas 6, pages 582 to 604 |
| `marks(8)` from Juz 16 (Al-Kahf 75) | 15 wirds |
| `marks(8)` from the first ayah on page 250 | 18 wirds. The first runs to Ibrahim 52, the end of Juz 13 |
| `seven` from the beginning | 7 wirds of 106, 102, 74, 85, 79, 72 and 87 pages. The first ends in the middle of page 106, where Al-Ma'idah begins |
| `days(29)` from the beginning | 29 wirds of 20 or 21 pages |
| `days(30)` from the beginning | 30 wirds of 20 or 21 pages, on page ends, not on the juz marks |
| 50 pages a day from the beginning | `days(13)`: 46 or 47 pages a day |
| `days(604)` from the beginning | 604 wirds of one page |
| `days(40)` from page 600 | 5 wirds of one page: there are only 5 pages |

## What the tests must show

- **SC-003**: for every plan the app offers and every start page, the wirds satisfy rule 1 with
  no gap and no overlap. Run on the bundled `quran.db`: all seven mark amounts and `seven` from
  the first ayah of each of the 604 pages; `days(n)` for every *n* from 1 to 604 from pages 1,
  2, 50, 302, 603 and 604; and *n* = 1, 2, 7, 29, 30, 100, 365 and 604 from every page.
- **SC-004**: with `days(n)`, the largest and smallest wird differ by at most one page, counting
  a first page that starts in the middle as one page. With marks and `seven`, every wird start
  after the first is a boundary of rule 2 or 3.
- The examples above, exactly.
- `divide` for the longest case (604 wirds) takes under 5 ms on the reference Android phone.
