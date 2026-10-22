# Contract: Page Typesetting

How a Mushaf page is set with the built-in lettering. Replaces the justification and font-size
parts of [001 research R4](../../001-quran-mushaf-reader/research.md). Implemented by
`lib/features/reader/kashida.dart` (`justifyLine`, `joinPoints`) and
`lib/features/reader/mushaf_page_renderer.dart`.

## Page geometry

1. The **sheet** is the whole reader body, within the safe areas.
2. The **text block** is the largest rectangle with height ÷ width = **1.77** that fits inside the
   sheet minus the header band, footer band and marker margin, centred.
3. `fontSize = textBlock.width ÷ targetEm`; `lineHeight = textBlock.height ÷ 15`.
4. Pages with fewer than 15 line slots (pages 1–2) use the same `lineHeight`, centred vertically
   in the block.
5. **Header band** (above the block): surah name at the right, juz at the left, as «سورة البقرة»
   and «الجزء ١». **Footer band**: page number centred, «٣». Each band is 0.6 × lineHeight; the
   text is the Quran font at 0.32 × lineHeight,
   accent ink. The surah is the first ayah's surah on the page; the juz is the first ayah's juz.

## Line justification (`justifyLine`)

Input: word widths (em), space width, tatweel width, join points per word, target width (em),
`centered`.

1. If `centered` or the line has one word: gap = 1 × space, no tatweel, centred, scale 1.
2. `natural = Σ words + (n − 1) × space`.
3. If `natural > target`: tighten gaps down to 0.5 × space. If still too wide, scale =
   target ÷ width, never below **0.95**.
4. Otherwise, add tatweels until the gaps come down to about **1.25 × space** (within half a
   tatweel per gap), then keep adding while a gap would exceed 1.5 × space and a point has room:
   - round-robin over words that have join points, in reading order;
   - within a word, the best point (by priority) fills first, at most **4 tatweels per point**.

   The renderer passes an effective tatweel width (starting at 0.8 × the measured one), shapes
   the stretched words, and re-justifies at most twice with the width the tatweels really added.
5. The rest goes to the gaps: `gap = (target − Σ stretched words) ÷ (n − 1)`. It normally falls
   between 0.5 and 1.5 × space. A line whose points run out first keeps the larger gap; such
   lines are counted (see the budgets below).
6. The output is deterministic: the same input always gives the same tatweels.

## Join points (`joinPoints`)

A point after letter *i* when letter *i* is dual-joining and letter *i+1* is a joining letter,
placed after letter *i*'s combining marks. Excluded:
- lam followed by «ا أ إ آ ٱ» (lam-alef ligature);
- any point in a word containing «لله» (the name of Allah);
- next to an existing tatweel;
- words with 2 letters or fewer, and ayah-end markers.

Priority: 0 after «س ش ص ض»; 1 before the word's last letter; 2 otherwise.

## Display text

The display string of a word is its `Word.text` with the tatweels inserted. It is used only for
painting and for measuring. Copy, share, search and semantics use `Word.text` (FR-005).

## Budgets and checks (tests)

| Check | Limit |
| --- | --- |
| Justified line width vs target | within 1% (SC-001) |
| Word gap | ≤ 1.5 × space on all lines except those with too few join points (86 lines on 2026-10-22), which must not grow |
| Line scale | ≥ 0.95 on all lines (FR-004) |
| Font size vs today, at 320, 390 and 430 pt widths | ≥ 100% (FR-012) |
| Text block ratio | 1.77 ± 2%; opposite margins equal within 2 pt (SC-004) |
| Page layout time | ≤ 8 ms per page on the reference phones (keeps 60 fps paging, SC-006) |
