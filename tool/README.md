# Quran data tools

These scripts turn licensed source files into the app's bundled database,
`assets/db/quran.db`, and verify it. Contracts:
[quran-db.md](../specs/001-quran-mushaf-reader/contracts/quran-db.md).

```powershell
dart run tool/build_quran_db.dart --record        # tool/sources/* → assets/db/quran.db
flutter test tool/measure_line_widths_test.dart   # writes meta line widths
dart run tool/verify_quran.dart --release         # integrity checks; must print PASS
flutter test tool/font_spike_test.dart            # font coverage + page images in build/font_spike/
```

### Until the QUL files are downloaded (development only)

```powershell
dart run tool/make_dev_sources.dart               # Tanzil → QUL-format stand-ins in tool/sources/dev/
dart run tool/build_quran_db.dart --dev
flutter test tool/measure_line_widths_test.dart
dart run tool/verify_quran.dart                   # passes; --release fails on a dev layout
```

Dev data has the right page starts but **approximate line breaks**, and the database records
`dev_layout=true`. It contains only Tanzil text (CC BY 3.0), so it may be committed, but it must
never be released.

## Source files

Download each file into `tool/sources/` (gitignored), with the exact filename below. After
downloading, record its SHA-256 here (`Get-FileHash -Algorithm SHA256 <file>`). The build script
refuses to run if a checksum differs.

| File | Source | How to get it | SHA-256 |
| --- | --- | --- | --- |
| `quran-uthmani.xml` | Tanzil Uthmani text v1.1, with pause marks and sajdah signs | `curl -L -o quran-uthmani.xml "https://tanzil.net/pub/download/index.php?marks=true&sajdah=true&rub=false&alef=false&tatweel=false&quranType=uthmani&outType=xml&agree=true"` | `c5052534d63d3856ce25413ff464d0b609f90169a202a1615aa8707efec81244` (downloaded 2026-10-10) |
| `quran-simple-clean.xml` | Tanzil Simple-Clean text, used only for dev search forms | `curl -L -o quran-simple-clean.xml "https://tanzil.net/pub/download/index.php?marks=false&sajdah=false&rub=false&alef=false&tatweel=false&quranType=simple-clean&outType=xml&agree=true"` | `8cb1833df9cd0033fd7e014eb35bdec9737f9b942e82cfdc09d74ab7f42d2731` (downloaded 2026-10-10) |
| `quran-data.xml` | Tanzil metadata v1.0: suras, juzs, hizbs (quarters), pages, sajdas | `curl -L -o quran-data.xml "https://tanzil.net/res/text/metadata/quran-data.xml"` | `8867c1d88191472adec9db694b3cd9f135b1a2ef580574d32cf888dcb22c5c7a` (downloaded 2026-10-10) |
| `qul-layout-kfgqpc-v4.db` | QUL "KFGQPC V4 layout (1441H print)", resource 19: 604 pages × 15 lines, table `pages` | Manual: https://qul.tarteel.ai/resources/mushaf-layout/19 → Download sqlite (QUL login needed). Downloads as `qpc-v4-tajweed-15-lines.db.zip`; unzip and rename | `4b3fb1cbe8dff749ab0173c4b86cb40fe3c48dd072f41d3c7e715654a9f843cd` (downloaded 2026-10-12) |
| `qul-script-kfgqpc-hafs-wbw.db` | QUL "KFGQPC Hafs script - Word by word", resource 312, SQLite | Manual: https://qul.tarteel.ai/resources/quran-script/312 → Download sqlite | *(replace after download)* |
| `qul-script-imlaei-simple-wbw.db` | QUL "Imlaei simple - Word by word", resource 60, SQLite (search forms) | Manual: https://qul.tarteel.ai/resources/quran-script/60 → Download sqlite | *(replace after download)* |

The layout and the two QUL scripts share QUL's global word index (`word_index`). The build script
asserts that all three agree on the word count and on the surah:ayah of every word.

Licences: see [docs/licences.md](../docs/licences.md). Tanzil files must stay byte-for-byte as
downloaded, including their copyright block.

## Browser preview (development only)

```powershell
flutter run -d chrome -t tool/web_preview.dart
```

Uses WebAssembly SQLite from `sqflite_common_ffi_web` (a dev dependency, so it never enters the
Android or iOS app) and `web/sqlite3.wasm`, which must match the locked `sqlite3` version
(currently 3.7.0). The browser is not a target platform; verify behaviour on a phone.
