# Quran data tools

These scripts turn licensed source files into the app's bundled database,
`assets/db/quran.db`, and verify it. Contracts:
[quran-db.md](../specs/001-quran-mushaf-reader/contracts/quran-db.md).

```powershell
dart run tool/build_quran_db.dart          # tool/sources/* → assets/db/quran.db
dart run tool/verify_quran.dart            # integrity checks; must print PASS
flutter test tool/measure_line_widths_test.dart   # writes meta.max_line_width_em
```

## Source files

Download each file into `tool/sources/` (gitignored), with the exact filename below. After
downloading, record its SHA-256 here (`Get-FileHash -Algorithm SHA256 <file>`). The build script
refuses to run if a checksum differs.

| File | Source | How to get it | SHA-256 |
| --- | --- | --- | --- |
| `quran-uthmani.xml` | Tanzil Uthmani text v1.1, with pause marks and sajdah signs | `curl -L -o quran-uthmani.xml "https://tanzil.net/pub/download/index.php?marks=true&sajdah=true&rub=false&alef=false&tatweel=false&quranType=uthmani&outType=xml&agree=true"` | `c5052534d63d3856ce25413ff464d0b609f90169a202a1615aa8707efec81244` (downloaded 2026-10-10) |
| `quran-data.xml` | Tanzil metadata v1.0: suras, juzs, hizbs (quarters), pages, sajdas | `curl -L -o quran-data.xml "https://tanzil.net/res/text/metadata/quran-data.xml"` | `8867c1d88191472adec9db694b3cd9f135b1a2ef580574d32cf888dcb22c5c7a` (downloaded 2026-10-10) |
| `qul-layout-kfgqpc-v4.db` | QUL "KFGQPC V4 layout (1441H print)", resource 19, SQLite: 604 pages × 15 lines | Manual: https://qul.tarteel.ai/resources/mushaf-layout/19 → Download sqlite (QUL account may be needed) | *(replace after download)* |
| `qul-script-kfgqpc-hafs-wbw.db` | QUL "KFGQPC Hafs script - Word by word", resource 312, SQLite | Manual: https://qul.tarteel.ai/resources/quran-script/312 → Download sqlite | *(replace after download)* |
| `qul-script-imlaei-simple-wbw.db` | QUL "Imlaei simple - Word by word", resource 60, SQLite (search forms) | Manual: https://qul.tarteel.ai/resources/quran-script/60 → Download sqlite | *(replace after download)* |

The layout and the two QUL scripts share QUL's global word index (`word_index`). The build script
asserts that all three agree on the word count and on the surah:ayah of every word.

Licences: see [docs/licences.md](../docs/licences.md). Tanzil files must stay byte-for-byte as
downloaded, including their copyright block.
