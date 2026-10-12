# Research: Quran Mushaf Reader (Uthmani Script)

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-10-10

Each entry: Decision, Rationale, Alternatives considered. Items marked **Open dependency** are
external actions, not design unknowns. The design does not wait on them, but release does.

---

## R1. App framework

**Decision**: Flutter (latest stable at project start, pinned in `pubspec.yaml`; 3.47 / Dart 3.13
at time of writing), a single codebase for iOS and Android.

**Rationale**:
- **Identical Quran rendering on both platforms** (Constitution I). Flutter shapes text with the
  same engine (HarfBuzz via SkParagraph/Impeller) on iOS and Android. Uthmani text depends heavily
  on OpenType mark placement, and native or React Native text goes through CoreText on iOS and
  Minikin on Android, which can position diacritics differently.
- **Precise control of line layout.** The page-faithful Mushaf needs per-line, per-word layout
  and justification (R4). Flutter exposes `TextPainter` and custom `RenderBox` directly.
- **Performance** (Constitution III). AOT-compiled; 60 fps scrolling and paging is routine; cold
  start is well under 2 s on mid-range Android.
- **Simplicity** (Constitution V). One codebase, and a single developer can maintain both apps.

**Alternatives considered**:
- *Native Swift + Kotlin*: the best size and startup, but two codebases for every feature, and
  Quran rendering parity has to be achieved twice. Rejected under Principles I and V.
- *React Native (Expo)*: a large ecosystem, but native text stacks differ for Uthmani shaping,
  and a JS runtime adds startup cost. Rejected under Principles I and III.
- *Kotlin/Compose Multiplatform*: also renders with Skia, but iOS maturity and the RTL/Arabic text
  ecosystem lag behind Flutter. Rejected as higher risk for no clear gain.

## R2. Quran text, layout data and sources

**Decision**: Build one read-only bundled database (`assets/db/quran.db`) at **build time**
from:

| Data | Source | Licence / terms |
| --- | --- | --- |
| 15-line, 604-page Madinah layout (lines, line type, centred flag, word ranges) | QUL (qul.tarteel.ai): "KFGQPC HAFS" layout, `qpc-hafs`, 604 pages × 15 lines | QUL terms (**Open dependency D2**: confirm reuse terms) |
| Uthmani text, word by word (matches the KFGQPC Hafs font encoding) | QUL "KFGQPC Hafs (word by word)" script | as above, text originating from KFGQPC |
| Simplified (imla'i) word forms for search | QUL imla'i word-by-word script | as above |
| Reference Uthmani text for integrity verification | Tanzil Uthmani text | CC BY 3.0: verbatim only, credit "Tanzil Project", link to tanzil.net |
| Metadata: surahs, juz, hizb quarters, sajdas, page starts | Tanzil Quran metadata, cross-checked with QUL | CC BY 3.0 (as above) |

The build script (`tool/build_quran_db.dart`) writes source file checksums and versions into a
`meta` table. The verification script (`tool/verify_quran.dart`) proves SC-003 (see R10).

**Rationale**: QUL publishes exactly the line-by-line layout the spec needs (FR-003 Mushaf
layout). Each line has `line_type` (`ayah` / `surah_name` / `basmallah`), `is_centered`, and
`first_word_id`–`last_word_id`. Its word-level text is encoded for the KFGQPC Hafs font, so one
font renders every page. Building at build time means no network at runtime (FR-026) and no parse
cost at startup.

**Alternatives considered**:
- *Page images* (as in some Quran apps): roughly 100–300 MB; violates the 30 MB budget and
  offline-on-first-launch. Text cannot be selected, searched or resized. Rejected.
- *QCF V1/V2 per-page glyph fonts* (604 fonts): pixel-faithful, but about 30–90 MB of fonts, which
  breaks the size budget. The glyph codes are also not real text, so copy, share and search need a
  second text set. Rejected.
- *Tanzil text alone with dynamic line breaking*: lean, but page and line breaks would not match
  the printed Mushaf. Kept as the basis of the flowing layout only.

**Open dependency D2**: Confirm QUL's terms for redistributing the layout and word data (QUL docs
do not state a licence; terms link to tarteel.ai). Action: email QUL/Tarteel before release and
record the reply in `docs/licences.md`. Fallback: the King Fahd Complex publishes the Hafs text
with its font package. Line assignments can be derived from the official Madinah Mushaf page and
line table (Tanzil metadata gives page starts; line splits come from KFGQPC sources).

## R3. Quran font

**Decision**: **KFGQPC Uthmanic Script HAFS** for Quran text in both layouts (as the brand guide
specifies for production), behind a single `QuranFont` setting so it can be swapped. The fallback
is **Amiri Quran** (SIL OFL, already the brand's development font).

**Rationale**: Its encoding matches the QUL word text, it gives a faithful Madinah look with one
font of about 0.5 MB, and the brand guide names it.

**Open dependency D1 (release blocker)**: The KFGQPC font licence is proprietary. It forbids
reproduction or modification without written approval from the King Fahd Glorious Quran Printing
Complex. Third-party "free" labels are not authoritative. Action: request written permission
from KFGQPC (fonts.qurancomplex.gov.sa) to embed the unmodified font in a free app, now, in
parallel with development. If permission is not granted in time, ship with Amiri Quran. The
Mushaf layout still works, but line widths must be re-checked because justification tolerances
differ (R4).

**Font check (T018), 2026-10-10, development data (Tanzil Uthmani encoding)**:
- **Coverage**: Amiri Quran has a glyph for every code point the text uses (266 mapped, 0
  missing), checked against the font's cmap.
- **Rendering**: pages 1, 2, 50, 187, 255 and 604 render correctly. Ayah-end markers (U+06DD +
  Eastern Arabic digits) draw as ornamented numbers, and diacritics do not collide at line
  height 2.0.
- **Measurement**: the widest dev-layout line is 26.9 em (p98 22.8 em). The renderer sizes pages
  by the p98 width and shrinks only wider lines.
- **Re-run required**: this must be repeated once the QUL KFGQPC word text replaces the dev data,
  because its encoding differs from Tanzil's.

**Font check on the real QUL text (T018), 2026-10-12: Amiri Quran FAILS with the KFGQPC encoding.**
U+065E (staggered dammatan) has no glyph, so boxes appear, and KFGQPC writes every final yaa as U+064A,
relying on its own font to drop the dots, so Amiri shows dotted «فِي» where the Mushaf has «فِى».

**Decision (2026-10-12)**: the display text follows the font.
- **Amiri Quran**: each QUL word shows the Tanzil Uthmani word(s) it aligns with. Tanzil is
  Amiri's native encoding and the verification reference. QUL's layout and word ids are kept.
  Alignment is 1:1 in 6,235 of 6,236 ayahs; the exception (37:130 «إِلۡ يَاسِينَ», one QUL word
  with a space) is handled by the space rule. Integrity: identical to Tanzil, with no encoding
  map. Coverage: 0 missing glyphs; pages render as printed.
- **KFGQPC Hafs (after D1)**: the QUL KFGQPC text, which then needs the approved encoding map
  (T015) to verify.

The build records this in `meta.text_source` (`tanzil-uthmani` or `qul-kfgqpc-hafs`).

**Alternatives considered**: *DigitalKhatt Madina* (open source, designed for justified Mushaf
layout). Promising, but its encoding and stability on mobile need evaluation. It is noted as a
future option, not chosen for v1.

## R4. Rendering the page-faithful Mushaf layout (FR-003, FR-004)

**Decision**:
- **Words**: each page is laid out by a custom `RenderBox` (`MushafPageRenderer`) that draws
  15 line slots. Each word is shaped once into a cached `TextPainter`.
- **Lines**: `ayah` lines are justified by distributing leftover width evenly between words, or
  centred when `is_centered` is set. `surah_name` lines draw a brand frame with the surah name.
  `basmallah` lines draw the basmala text.
- **Font size**: one size per screen geometry, the largest at which the widest line of all 604
  pages fits the content width *and* 15 lines fit the height. It is computed once per screen size
  and cached, so every page looks consistent.
- **Paging**: `PageView` with `reverse` semantics under a forced `Directionality.rtl`, regardless
  of interface language. The next page lies to the left (FR-004).
- **Preloading**: implicit scrolling keeps pages n−1 and n+1 laid out (SC-002).

**Rationale**:
- Word-level painters give exact justification and per-word hit testing for long-press ayah
  selection (FR-020). The future audio feature needs the same word geometry to highlight the
  recited ayah, so nothing is wasted.
- One `RenderBox` per page avoids roughly 150 widgets per page.
- The widest line is measured with the bundled font at build time and stored in
  `meta.max_line_width_em`, so size computation is a single division at runtime.

**Alternatives considered**: one `Text` widget per line with `TextAlign.justify`. Flutter does not
justify the last or only line of a paragraph, and it gives no word geometry. Rejected.

## R5. Flowing layout (FR-003 flowing, FR-017)

**Decision**: a virtualised vertical `ListView.builder` with one item per Mushaf page. Each item is
a single `RichText` paragraph of that page's ayat with inline ayah-end markers, plus surah headers
where surahs begin. Text size is 18–34 pt (default 24) with line height fixed at 2.0× (brand
`quran-page`). The header shows the Mushaf page number of the topmost item.

**Rationale**: Page-sized chunks keep the list virtualised (Constitution III) and make position
mapping between layouts trivial (R6). There is no second data set: the same words are joined per
ayah.

**Alternatives considered**: one item per ayah (many tiny paragraphs, so wrapping is not
"flowing"); one item per surah (Al-Baqarah would be a single very long paragraph, which is
expensive to lay out). Rejected.

## R6. Keeping the reader at the same ayah (FR-003, FR-013, SC-005, SC-010)

**Decision**: The single source of truth is the **anchor ayah** (`surah:ayah`) plus the layout.
- Mushaf layout: the anchor is the first ayah that starts on the current page, or the selected
  ayah if there is one.
- Flowing layout: the anchor is the first ayah visible at the top.
- Switching layout or language rebuilds the view and jumps to the page or item that contains the
  anchor.
- Saving: the anchor is written to `user.db` with a 500 ms debounce on every page change or scroll
  settle, *and* immediately when the app goes to the background. A system kill therefore never
  loses more than the last 500 ms (edge case "app ended mid-reading").

## R7. Search (FR-022, SC-006)

**Decision**: in-memory linear search over normalised imla'i text, with **no FTS engine**.
- At first search, load one normalised string per ayah (6,236 rows, about 0.7 MB) plus a
  word-offset map from `quran.db`.
- The query is normalised the same way: strip tashkeel and Quranic annotation marks; unify
  أ/إ/آ/ٱ → ا, ى → ي, ؤ → و, ئ → ي, ة → ه; remove tatweel.
- Matching is a substring scan. Matched character ranges map to word indices, which map to
  Uthmani words for highlighting.

**Search forms (2026-10-12)**: QUL's imla'i text is phonetic («ذالك», «هاذا», «الرحمان»), but
readers type standard spelling. Word search forms therefore come from Tanzil Simple-Clean where
the ayah's word count matches QUL (5,872 ayahs, after dropping pause-mark tokens), and from QUL
imla'i otherwise (364 ayahs, for example «يا أيها» against «ياأيها»).

**Rationale**: A linear scan of about 0.7 MB in AOT Dart takes tens of milliseconds, well under 1 s
(SC-006). It adds no native dependency, no index files and no size cost. Platform SQLite FTS5 is
not guaranteed on Android.

**Alternatives considered**: SQLite FTS4/5 (availability varies, adds index size, and word
splitting does not match Uthmani spelling anyway); a bundled search engine (size). Rejected.

## R8. Storage and dependencies (Constitution IV)

**Decision**: the runtime third-party packages are limited to these five. Each is justified in
the plan.

| Package | Purpose | Why not built in |
| --- | --- | --- |
| `sqflite` | read `quran.db`, read/write `user.db` | Uses the platform's system SQLite, so it adds no binary size. Flutter has no built-in database. |
| `wakelock_plus` | keep-screen-on (FR-018) | Needs native APIs on both platforms. A tiny, maintained plugin. |
| `share_plus` | native share sheet (FR-021) | Native share UI on both platforms. Copy uses the built-in `Clipboard`. |
| `url_launcher` | open https://tanzil.net from About | The Tanzil CC BY 3.0 terms require a link to tanzil.net. Official flutter.dev package; opens the system browser. |
| `flutter_localizations` + `intl` (SDK) | Arabic/English, RTL/LTR, plurals (FR-025) | Official Flutter localisation. Not third-party in practice. |

- Not used: state-management libraries (built-in `ChangeNotifier`/`ValueNotifier` are enough),
  routing libraries (5 screens; `Navigator` is enough), SVG runtime, analytics or crash SDKs
  (FR-027).
- `quran.db` is copied once from assets to the app's database directory on first launch
  (about 150 ms), then opened read-only.
- `user.db` is a separate database, so updating the app's `quran.db` never touches user data.

## R9. Icons, logos and fonts (brand guide)

**Decision**:
- **Icons**: the outline icons needed (about 15, from Lucide, ISC licence) are compiled into one
  custom icon font at build time. This gives zero runtime dependency and tree-shakable glyphs.
- **Logos**: brand SVGs are pre-rendered to PNG at @1x/@2x/@3x for in-app use. The app icon and
  launch screens are generated from `mathani-app-icon.svg` and `mathani-mark-gold.svg` on `bar`
  navy. Launch screens are configured natively (no runtime package).
- **Interface font**: IBM Plex Sans Arabic (SIL OFL) at weights 400/500/600/700. It includes
  Latin glyphs designed alongside IBM Plex Sans, so the English interface uses the same family.
  This needs no extra font and satisfies the brand guide's "pair" requirement.

## R10. Verifying text integrity (FR-002, SC-003)

**Decision**: `tool/verify_quran.dart` runs in CI and before every release. It:
1. Asserts 114 surahs, 6,236 ayat, 604 pages, 30 juz, 240 hizb quarters and 15 sajdas.
2. Rebuilds each ayah from `words` and compares it, after Unicode NFC normalisation and the
   documented mapping between the KFGQPC and Tanzil encodings of identical characters (the only
   accepted transformation), with the Tanzil Uthmani reference. Any other difference fails the
   build.
3. Asserts every word appears in exactly one Mushaf line, and lines cover pages 1–604 in order.
4. Checks the SHA-256 of `quran.db` against the value recorded in the release notes.

## R11. Platforms, devices and tooling

**Decision**:
- **Minimum OS**: iOS 15.0+ and Android 7.0 (API 24)+, targeting Android API 36 (Google Play
  requirement from 31 Aug 2026). API 24 instead of Flutter's floor of 21 drops a tiny share of
  devices and reduces the test matrix.
- **Orientation**: portrait locked (constitution: phones portrait first).
- **Performance reference devices** (constitution III): Samsung Galaxy A15 (Android, low-mid tier
  common in Egypt) and iPhone SE (2nd gen) (iOS, small screen, oldest supported performance tier).
- **iOS builds need macOS and Xcode.** The developer machine is Windows, so iOS builds,
  signing and TestFlight run on a cloud macOS CI (Codemagic or GitHub Actions macOS runners), or
  on a Mac when available. Android builds run locally.
- **Release builds**: `--obfuscate --split-debug-info`, R8 shrink, icon tree-shaking, Android
  App Bundle (per-device APKs).

## R12. Size estimate (Constitution IV: ≤ 30 MB download, SC-008)

| Item | Estimated download |
| --- | --- |
| Flutter engine and app code (Android AAB per device / iOS) | ~6–8 MB / ~12–15 MB |
| `quran.db` (words, layout, search forms, metadata), compressed in package | ~3–4 MB |
| Fonts (KFGQPC Hafs ~0.5 MB, Plex Arabic ×4 ~0.8 MB, icon font) | ~1.5 MB |
| Images (logos, surah frame) | < 0.5 MB |
| **Total** | **Android ~12 MB, iOS ~20 MB**, both under 30 MB |

It is measured on every release with `flutter build appbundle --analyze-size` and
`flutter build ipa --analyze-size`.

## Sources

- QUL Mushaf layouts and format: https://qul.tarteel.ai/mushaf_layouts, https://qul.tarteel.ai/docs/mushaf-layout
- KFGQPC Hafs font licence: https://scancode-licensedb.aboutcode.org/kfgqpc-uthmanic-script-hafs.html, https://fonts.qurancomplex.gov.sa/wp02/en/?p=19
- Quran Foundation font terms: https://api-docs.quran.foundation/legal/mushaf-fonts-and-images/
- Tanzil text licence: https://tanzil.net/docs/text_license
- Flutter minimum Android version: https://docs.flutter.dev/release/breaking-changes/android-kitkat-deprecation.html
