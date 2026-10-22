# Contract: Screens, Navigation and User-Visible Formats

The app's external interface is its UI, the text it shares, and its store presence. This
contract fixes what the screens are, what each one shows, and the exact output formats.

## Screens

| Screen | Entry | Shows | Exits |
| --- | --- | --- | --- |
| **Reader** (home) | app launch (opens at saved anchor) | Mushaf or flowing layout; header with surah name, juz, page (FR-008); bookmark indicator; buttons for index, search, layout toggle and settings | Index, Search, Settings, ayah action sheet |
| **Index** | Reader index button | three chip tabs: Surahs · Ajza' · Bookmarks (FR-009–FR-011, FR-015); a go-to control | back to Reader at the chosen location |
| **Go-to sheet** | Index | page number field (1–604), or surah picker plus ayah field (1..ayah_count) | Reader at target with the ayah highlighted for 1.5 s; invalid input shows the range and stays open (FR-012) |
| **Search** | Reader search button | query field, result count, results list with the match highlighted (FR-022) | Reader at result with the ayah highlighted |
| **Settings** | Reader settings button | layout, theme, text size (flowing only), keep-screen-on, language; About (version, data and font attributions: Tanzil link, QUL, KFGQPC) | back to Reader |
| **Ayah action sheet** | long-press on an ayah | Copy · Share · Bookmark | dismiss |

> **Updated by 002**: in the Mushaf layout the header and toolbar are an overlay shown on tap, and the page carries its own surah, juz and page number. See [002 reader-page-view](../../002-print-like-mushaf-page/contracts/reader-page-view.md).

No screen or button exists for features that are not built yet (FR-028).

## Direction rules

- The interface follows the language: Arabic is RTL and English is LTR. Back and forward icons
  mirror with it, and media icons never mirror (brand guide).
- The Mushaf area (both layouts) is **always RTL**, and its page turn is always "next page to the
  left", in both languages (FR-004).
- Numerals: ayah markers and Mushaf page numbers inside the Mushaf area use Eastern Arabic
  numerals (١٢٣) in both languages. Interface numbers follow the language: Eastern Arabic in
  Arabic and Western in English.

## Shared and copied text format (FR-021)

```text
Arabic interface:
﴿<exact Uthmani ayah text, without the ayah-end marker>﴾
سورة <name_ar>: <ayah in Eastern Arabic numerals>

English interface:
﴿<exact Uthmani ayah text, without the ayah-end marker>﴾
Surah <name_translit> <surah>:<ayah>
```

Example (Arabic): `﴿ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ...﴾`, then a line break, then `سورة البقرة: ٢٥٥`.

## Accessibility and touch

- Every icon button has a label in the interface language.
- Touch targets are at least 44×44 pt on iOS and at least 48×48 dp on Android (constitution II).
  This overrides the brand guide's single `touch-min` 44 on Android.
- Screen readers: index rows read as "<surah name>, <ayah count> ayat, page <n>". Mushaf pages
  read as "Page <n>, Surah <name>". Reading the Quran text through the screen reader is out of
  scope for v1, because Uthmani TTS quality is poor.
- System font scaling applies to interface text. Quran text size is controlled only by the in-app
  setting (flowing layout) or by screen fit (Mushaf layout).

## Store presence (FR-023)

| | Arabic | English |
| --- | --- | --- |
| App name (home screen) | مثاني | Mathani |
| Store listing name | مثاني: تلاوة وتدبر المتشابه | owner to decide (suggested: "Mathani: Quran & Mutashabihat") |
| Privacy disclosures | App Store "Data Not Collected"; Play Data safety "No data collected / shared" (FR-027) | same |
