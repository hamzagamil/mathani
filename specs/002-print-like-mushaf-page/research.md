# Research: Print-Like Mushaf Page

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-10-22

Measurements were taken on 2026-10-22 in throwaway tests against the real `quran.db` (all 604
pages, 8,791 justified lines) on the Windows development machine. Rendered sample pages were
inspected visually.

## P1. Why lines show wide gaps today

**Finding**: the layout comes from the KFGQPC 15-line edition, where every line was written to the
full width by a calligrapher, using letter forms of varying width and elongations. A Unicode Quran
font sets each word at one natural width, so the same lines come out at very different lengths:

| Font | Shortest 5% | Median | 95th pct | 98th pct | Widest | p5 ÷ p98 |
| --- | --- | --- | --- | --- | --- | --- |
| Amiri Quran (in the app) | 14.02 em | 17.14 em | 20.68 em | 21.55 em | 24.96 em | 0.65 |
| KFGQPC Hafs (licence pending, D1) | 13.38 em | 16.13 em | 19.20 em | 20.10 em | 23.10 em | 0.67 |

Today the font size makes the 98th-percentile line fit, and the rest is spread between words. The
median gap is **2.8×** a normal space, the 90th percentile **4.5×**, and the worst **12.6×**.
176 lines are shrunk, by up to 14%.

**Consequence**: changing the font does not fix this. KFGQPC Hafs spreads as much as Amiri.
The fix has to fill lines the way print does, by lengthening joins.

## P2. Filling lines: kashida in the display text (FR-001 to FR-005)

**Decision**: justify each ayah line by inserting **tatweel (U+0640)** into the **display string**
of chosen words, then let word gaps absorb the remainder.

1. **Font size** comes from the widest line, not the 98th percentile. Its word gaps are tightened
   to 0.6 of a space and it may shrink by 5% (FR-004), which gives a target line width of
   **22.27 em**. Every line is filled to that width.
2. **Join points**: between two letters of a word that join, after the first letter's marks.
   Points are excluded inside «لا» (the lam-alef ligature), in the name of Allah, next to an
   existing tatweel, and in words of 2 letters or fewer («ما», «به»: kashida there looked wrong).
3. **Priority**: after «س ش ص ض» first, then the join before the last letter, then any other.
4. **Distribution**: tatweels are given out one at a time, round-robin across the line's words.
   Within a word, its best point fills first, up to **4 per point**, before the next point. This
   gives each word one longer stretch, as in print (revised during implementation, see below).
5. **Remainder**: word gaps take what is left, between **0.5 and 1.5×** a normal space (FR-002).
   If a line is still short (few join points), gaps may exceed 1.5×. These lines are counted
   and reported by a test.
6. **Long lines**: gaps tighten to 0.5×; if still too long, the line shrinks, never below 95%.

**Measured** at the 22.27 em target: kashida per word is 2.2 tatweels at the median, 4.4 at the
90th percentile and 6.9 at the 99th; 427 lines need no kashida at all. Rendered pages 3, 50 and
300 read as continuous print. The visible issues were kashida in very short words (fixed by rule
2's 2-letter minimum) and a few lines with few join points, which keep wider gaps (rule 5).

**Revised during implementation (2026-10-22)**, measured with the real renderer on all 604 pages:
- **A tatweel adds less than its own width.** On average a tatweel adds 0.85 of its measured
  width, and 0.78 for the median word, because the letters around it change form. The renderer
  starts from 0.8 × tatweel, shapes the stretched words, and re-justifies (at most twice) with
  the width the tatweels really added.
- **Cap per point.** With the real widths, 2 per point left 362 lines with gaps over 1.5× space
  (4%), 3 left 362 with rotation, and 4 left **86 lines (1%)**. The count is the same at every
  width.
- **Best point first.** Rotating across all of a word's points stretched every join («كَـيْـفَ»)
  and looked mechanical. Filling the best point first gives one longer stretch per word and
  reads like print. The over-gap count did not change.

**Text size** (FR-012): the wider target makes the Quran text 96.7% of today's size at the same
content width. The full-screen page (P5) gives the text the 2 × 8 pt side padding that today's
reader adds; on a 390 pt wide phone that is +4.4% width. The net is about **101%** of today. A
test checks it on the three reference widths.

**Visual only** (FR-005): kashida exists only in the strings handed to the text painter. `Word`
text, copy, share, search and screen-reader labels keep the source text.

**Screen-size independent**: the choice of tatweels depends only on em widths, so it is the same
on every screen. Only the scale changes, and line breaks never move (FR-006).

**Rationale**: works with the current font and with KFGQPC Hafs when licensed. Needs no new
packages or font features Flutter lacks. It is close to how the printed Mushaf fills lines.

**Alternatives considered**:
- *Widen gaps only* (today): the defect itself. Rejected.
- *Horizontal scaling of words*: distorts the letter shapes. Rejected.
- *DigitalKhatt Madina* (variable font built for justified Mushaf layout): it needs its own
  layout engine, which Flutter's text stack cannot run. Rejected for now; noted for later.
- *Switch to KFGQPC Hafs*: same spread (P1) and still licence-blocked (D1). Kept swappable.
- *Precompute kashida at build time in `quran.db`*: same result, but it couples the database to
  one font, and runtime cost is small (P3). Rejected for now (Principle V).

## P3. Where the justification runs

**Decision**: a pure Dart function, `justifyLine`, in `lib/features/reader/kashida.dart`. It
takes the words' em widths, the space and tatweel widths, each word's join points and the target
width. It returns tatweel counts per point and the gap. The renderer calls it once per line during
layout. Word painters are cached by display string per page, as today.

**Rationale**: unit-testable without fonts, deterministic, and the renderer stays one RenderBox
(001 R4). A page has about 15 lines and 120 words; the extra shaping is one painter per stretched
word, which is about what layout does today.

## P4. Text block proportions (FR-008)

**Decision**: the text block has a fixed **height-to-width ratio of 1.77**, measured from the
reference screenshot (15 lines over 1,330 px for a 750 px wide block). That gives a line pitch
of 0.118 × the width, about 2.6 em at the 22.27 em target, which leaves room for diacritics
(today's minimum is 2.0 em).
- The block takes the full available width unless the height runs out first. Then it takes the
  full height and the width follows.
- Spare space becomes equal margins: top and bottom on tall screens, left and right on short
  ones.
- Line spacing never grows with the screen; today's `lineHeight = height / 15` does.

**Fit on the reference screens** (status bar hidden, safe areas kept, header and footer bands of
0.6 × line pitch, hizb-mark margins of 4.5% each side):

| Screen | Bound by | Quran font vs today |
| --- | --- | --- |
| iPhone SE 2nd gen, 375 × 667 | height | 100.1% |
| 390 × 844 class | width | 100.9% |
| 430 × 932 class | width | 100.5% |

With 0.9-line bands, the SE would be height-bound at 96% of today's size, so the bands are
0.6 × line pitch. The page-detail text is 0.32 × line pitch (about 13 pt).

**Alternatives considered**: keeping `height / 15` (spreads lines on tall phones; part of the
defect); measuring a printed page with a ruler (the reference app already matches print, and its
ratio can be tuned later as a constant).

## P5. Full-screen paper page (FR-009 to FR-011, FR-013)

**Decisions**:
- **Layout**: in the Mushaf layout, the reader body fills the screen. Today's app bar and bottom
  toolbar become an overlay that slides in on tap and out on the next tap or page turn. The
  flowing layout keeps today's bars.
- **System bars**: hidden with the controls (`SystemUiMode.immersiveSticky` on Android, status
  bar hidden on iOS), shown with them, and restored when leaving the Mushaf layout or the reader.
- **Page details**: drawn by the page renderer inside the sheet, as in print, so they turn with
  the page. The surah name sits at top right and the juz at top left, in the Quran font at 0.32 ×
  the line pitch and in accent colour (P4). The page number is centred at the bottom. Text and numerals are Arabic,
  following the Mushaf-area rule of feature 001.
- **Screen readers**: when `MediaQuery.accessibleNavigation` is true, the controls stay shown and
  the system bars stay visible (FR-010).
- **First open**: controls start shown and hide on the first page turn. The first time, a short
  hint «اضغط على الصفحة لإظهار الأدوات» / "Tap the page to show controls" appears once. It is
  stored as the preference key `controls_hint_shown` in the existing `preferences` table, with no
  schema change.
- **Tap versus long-press**: tap toggles the controls, except when an ayah is selected, where tap
  clears the selection as today. Long-press stays ayah selection.
- **Paper**: the sheet fills the screen (no card). A **soft page edge** is a 12 pt horizontal
  gradient on the binding side, ink at 6% opacity to 0, like the reference. The **paper
  texture** is a 128 × 128 noise tile generated once at runtime from a fixed seed. It tiles at
  3% opacity (ink colour), so it adds no asset bytes (SC-007). In night theme, the same tile is
  drawn in the night ink colour.
- **Contrast**: the texture changes the background luminance by less than 1%. A test checks that
  the Quran ink stays at or above 4.5:1 against the darkest texture value in both themes.

**Alternatives considered**: a texture PNG asset (about 30–80 KB per theme, against
Principle IV); a card with margins and shadow (wastes width that the text needs); permanent bars
(not print-like, and they take the room that pays for FR-012).

## P6. Exact replica pack (FR-014 to FR-021): format and gating

**Facts gathered**:
- The reference app draws each page with its own page font (KFGQPC QCF), one glyph per word.
  Word glyph codes are published per word id, and our word ids are QUL's.
- Download sizes (604 files, measured; see the spec): V2 1421 AH plain 93 MB as WOFF2; V4 1441 AH
  with tajweed colours 48 MB; V1 1405 AH 46 MB. TTF is about 2–6× larger, and gzip-compressed TTF
  is 1.2–3.2× the WOFF2 size on the two sampled pages.
- **Layout match**: our layout is QUL's "KFGQPC V4" 15-line layout. On a 2-page sample, the Quran.com
  API's default line numbers put **15 of 289 words** on a neighbouring line, always at a line
  boundary. So which edition's lettering matches our line breaks must be proven, not assumed.

**Decisions**:
1. **Gate (spike S-1)**: before any pack work, download QUL's layout databases for the candidate
   lettering (V2 and V4) and compare every word's page and line with `quran.db` (SC-008). The
   pack uses only an edition that matches 100%. If the plain V2 lettering does not match, the
   options go back to the owner: V4 lettering (matches by name, but has tajweed colours, which
   are out of scope), or rebuilding the built-in layout from the V2 edition (changes line breaks
   and FR-006).
2. **Gate (spike S-2)**: on one Android and one iOS device, load one page font with
   `FontLoader` from WOFF2 bytes and from TTF bytes, and compare the rendering. If WOFF2 loads on
   both, the pack ships WOFF2 (about 93 MB). Otherwise it ships gzip-compressed TTF, inflated with
   `dart:io` `GZipCodec` when a page font is loaded (an estimated 140–200 MB stored, no new
   package).
3. **Pack layout**: a `manifest.json` (version, edition, file list with byte sizes and CRC32),
   `glyphs.json` (word id → glyph string), and one font file per page. It is hosted as static
   files at a URL set in the build (`--dart-define=REPLICA_PACK_URL`). The host is chosen under
   D4 and needs permission under D3.
4. **Download**: `dart:io` `HttpClient`, one file at a time, skipping files already on disk with
   the right size, so resuming is natural (FR-016). Each file is written to a `.part` file and
   renamed when complete. The pack is checked against the manifest (sizes and CRC32) before it
   is enabled. It runs only while the app is open; leaving and coming back resumes it.
   Android release builds need `android.permission.INTERNET` (the app's first permission).
5. **Storage**: the app support directory, under `replica/<version>/`. Free space is checked first
   against the manifest total plus 10%.
6. **Rendering**: a page with the pack enabled loads its page font (family `qcf_p###`) the first
   time it is shown, prefetching n ± 2. The renderer draws each word's glyph string with that
   font instead of the Unicode text, at the same placements. A replica line is already full
   width, so no kashida applies. Highlights and hit testing use the same word rectangles.
7. **Memory**: Flutter cannot unload a registered font. Each page font is about 0.2–0.9 MB in
   memory, so reading 100 pages in one session adds about 30–60 MB. Spike S-2 also measures
   this. If it is too high, the mitigation is to draw glyphs from cached paths rather than
   registered fonts (a later plan).

**Rationale**: the pack is optional and blocked by D3 (licence), so the plan fixes its shape and
gates now. The built-in print-like page (P2–P5) ships without it.

**Alternatives considered**: bundling the pack in the app (90+ MB against the 30 MB limit);
`package:archive` for a single zip (a new dependency, and resuming one large file is harder);
background download services (Principle IV: no background work without need).
