# Quran data tools

These scripts turn licensed source files into the app's bundled database,
`assets/db/quran.db`, and verify it. Contracts:
[quran-db.md](../specs/001-quran-mushaf-reader/contracts/quran-db.md).

```powershell
dart run tool/build_quran_db.dart --record        # tool/sources/* → assets/db/quran.db
flutter test tool/measure_line_widths_test.dart   # writes meta line widths
dart run tool/verify_quran.dart --release         # integrity checks; must print PASS
dart run tool/build_recitation_manifest.dart     # recitations: size of every ayah file (network, ~5–20 min)
dart run tool/add_recitations.dart               # recitations: reciters + sizes into quran.db
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
| `quran-simple-clean.xml` | Tanzil Simple-Clean text: standard-spelling search forms (and dev data) | `curl -L -o quran-simple-clean.xml "https://tanzil.net/pub/download/index.php?marks=false&sajdah=false&rub=false&alef=false&tatweel=false&quranType=simple-clean&outType=xml&agree=true"` | `8cb1833df9cd0033fd7e014eb35bdec9737f9b942e82cfdc09d74ab7f42d2731` (downloaded 2026-10-10) |
| `quran-data.xml` | Tanzil metadata v1.0: suras, juzs, hizbs (quarters), pages, sajdas | `curl -L -o quran-data.xml "https://tanzil.net/res/text/metadata/quran-data.xml"` | `8867c1d88191472adec9db694b3cd9f135b1a2ef580574d32cf888dcb22c5c7a` (downloaded 2026-10-10) |
| `qul-layout-kfgqpc-v4.db` | QUL "KFGQPC V4 layout (1441H print)", resource 19: 604 pages × 15 lines, table `pages` | Manual: https://qul.tarteel.ai/resources/mushaf-layout/19 → Download sqlite (QUL login needed). Downloads as `qpc-v4-tajweed-15-lines.db.zip`; unzip and rename | `4b3fb1cbe8dff749ab0173c4b86cb40fe3c48dd072f41d3c7e715654a9f843cd` (downloaded 2026-10-12) |
| `qul-script-kfgqpc-hafs-wbw.db` | QUL "KFGQPC Hafs script - Word by word", resource 312: words(id, location, surah, ayah, word, text) | Manual: https://qul.tarteel.ai/resources/quran-script/312 → Download sqlite. Downloads as `qpc-hafs-word-by-word.db.zip` | `e1cf266ed47a56e58100c08f69499f635f84c97233318cc53daf17200fb9048e` (downloaded 2026-10-12) |
| `qul-script-imlaei-simple-wbw.db` | QUL "Imlaei simple - Word by word", resource 60 (search-form fallback) | Manual: https://qul.tarteel.ai/resources/quran-script/60 → Download sqlite. Downloads as `imlaei-simple.db.zip` | `0ffcc50b72678f89d8ec8ef4547aecb851805d4a282f0eaccdd0c00ffbd4e5f8` (downloaded 2026-10-12) |

The layout and the two QUL scripts share QUL's global word id (`words.id`, 1–83,668, including one ayah-end marker per ayah). The build script
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

## Recitation catalogue (specs/004)

`quran.db` lists the reciters and the size of every ayah recording, so the app can show download
sizes offline and reject damaged files. Contract:
[recitation-catalogue.md](../specs/004-ayah-recitations/contracts/recitation-catalogue.md).

```powershell
dart run tool/build_recitation_manifest.dart   # HEAD every ayah file of each reciter in tool/recitations.json
dart run tool/add_recitations.dart             # write the reciters and recitation_sizes tables into quran.db
```

- `tool/recitations.json` (committed) defines the reciters: names, short names, style, base and
  mirror URLs. Adding a reciter means adding a row here and running both commands; no app code
  changes.
- The manifest tool writes `tool/sources/recitations/<id>.json` (gitignored) and records its
  SHA-256 in `sources.lock.json`. It exits with an error if any of the 6,236 ayat is missing
  (FR-002, SC-003). It asks EveryAyah's CDN 4 files at a time; more gets throttled.
- `add_recitations.dart` patches the existing `quran.db` in place, like the line-width and
  printed-lettering steps; `build_quran_db.dart` writes the same tables in a full rebuild.

## Memorization model (specs/006, specs/007)

Memorization recognises the reader's voice on the device with Khatma FastConformer (NVIDIA's
Arabic FastConformer, CC BY 4.0; Tilawa's ONNX export, MIT), run by sherpa-onnx as a raw-audio
CTC model. The app downloads the model once from a GitHub release; it is not bundled. Research:
[007 R1–R4](../specs/007-khatma-live-recognition/research.md).

```powershell
py -3.12 -m venv build/asr/venv
build/asr/venv/Scripts/python -m pip install onnx onnxruntime numpy sherpa-onnx==1.13.8
build/asr/venv/Scripts/python tool/export_khatma_model.py --out build/asr/khatma-v1 --check build/asr/check
```

- The tool unpacks Khatma's package (its int4 weights rebuilt as int8, embedded in one ONNX
  file) and computes the graph's audio-length input from the audio, so sherpa-onnx can feed it
  raw samples; Khatma's own features stay in the graph. It writes `model.int8.onnx`, its gzip
  `model.int8.onnx.gz` (the file the app downloads), `tokens.txt`, `silero_vad.onnx`,
  `NOTICE.txt` and `SHA256SUMS`. The same inputs always give the same bytes.
- `--check DIR` decodes every 16 kHz mono float32 clip in DIR with the original graph and with
  the converted model through sherpa-onnx, and fails below 97% agreement (spike S1).
  `tool/wav_to_f32.py` converts WAV recordings into such clips.
- Every download is checked against a SHA-256 pinned in the tool, so `--hf-endpoint` (or
  `HF_ENDPOINT`) can point to a mirror when huggingface.co is unreachable.
- Upload `model.int8.onnx.gz`, `tokens.txt`, `silero_vad.onnx` and `NOTICE.txt` to a release
  named after the model version (`asr-khatma-v1`), and pin the download and unpacked sizes and
  SHA-256 in `lib/features/memorization/asr_model.dart`. A new export is a new release and a new
  version; never replace files in a published release.
