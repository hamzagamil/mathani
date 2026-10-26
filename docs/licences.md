# Licences and Attributions

Every third-party source and asset shipped in Mathani, the licence it is used under, and what
that licence requires of the app. The About screen (`lib/features/settings/about_section.dart`)
must show every attribution marked **required**.

## Quran text and data

| Source | Used for | Licence | Requirements |
| --- | --- | --- | --- |
| Tanzil Project, Uthmani text v1.1 and metadata (https://tanzil.net) | Integrity reference for every ayah; surah, juz, hizb, page and sajdah metadata | Creative Commons Attribution 3.0 | **Required**: verbatim copies only (CHANGING IT IS NOT ALLOWED); clearly name the source "Tanzil Project"; link to https://tanzil.net; keep the copyright notice with verbatim copies |
| Quranic Universal Library (QUL, https://qul.tarteel.ai): KFGQPC Mushaf layout, KFGQPC Hafs word-by-word script, Imla'i word-by-word script | Page and line layout; displayed words; search forms | **Unconfirmed** (no licence stated; site terms at https://tarteel.ai/terms) | Attribution expected. **Dependency D2**: confirm in writing before release |
| King Fahd Glorious Quran Printing Complex (KFGQPC) | Origin of the Mushaf layout and Hafs text | See the font row below for the font; text origin credited | **Required**: credit "King Fahd Glorious Quran Printing Complex" |

## Fonts

| Font | Used for | Licence | Requirements |
| --- | --- | --- | --- |
| KFGQPC Uthmanic Script HAFS | Quran text (production, preferred) | **Proprietary**: no reproduction or modification without written approval from KFGQPC | **Dependency D1**: not bundled until written approval is received |
| Amiri Quran | Quran text (fallback; used until D1 is resolved) | SIL Open Font License 1.1 | Ship the OFL text; do not sell the font by itself |
| KFGQPC Madinah Mushaf page fonts, edition V2 (1421 AH), one per page (`assets/qcf/`) | Printed lettering of the Mushaf layout, the default (specs/002, User Story 4) | **Proprietary**, as above | **Dependency D3**: bundled unmodified; requires written approval |
| IBM Plex Sans Arabic (Regular, Medium, SemiBold, Bold) | Interface text, Arabic and Latin | SIL Open Font License 1.1 | Ship the OFL text |

## Recitations

Streamed or downloaded on request; nothing is bundled (specs/004-ayah-recitations,
specs/006-reciters-memorization). The file sizes in `quran.db` (`recitation_sizes`) come from
these servers; the clip offsets of surah recordings come from QUL's ayah timings.

| Recording | Used for | Licence | Requirements |
| --- | --- | --- | --- |
| Sheikh Mahmoud Khalil Al-Husary, Murattal, EveryAyah `Husary_64kbps` (https://everyayah.com, mirror https://mirrors.quranicaudio.com/everyayah) | Ayah-by-ayah recitation (default reciter) | **Unconfirmed** (no terms stated on the site) | **Dependency D4**: written permission before release. **Required** until D4 says otherwise: the About screen credits both reciters and EveryAyah.com with a link (`recitationAttribution`) |
| Sheikh Mohamed Siddiq El-Minshawi, Murattal, EveryAyah `Minshawy_Murattal_128kbps` (same hosts) | Ayah-by-ayah recitation | **Unconfirmed** (no terms stated on the site) | **Dependency D4**: as above |
| The 41 further EveryAyah folders listed in [permissions/everyayah-request.md](permissions/everyayah-request.md) (specs/006) | Ayah-by-ayah recitation | **Unconfirmed** | **Dependency D4**. The About screen credits EveryAyah.com |
| Mustafa Ismail; Mahmoud Khalil Al-Husary (Ijazah); Bandar Baleela; Khalid Al-Jalil; Hady Toure: surah recordings on `download.quranicaudio.com`, played as per-ayah byte ranges | Ayah-by-ayah recitation (specs/006 research R18) | **Unconfirmed** | **Dependency D4** (audio) and **D2** (QUL ayah timings) |
| Ahmad Al-Nufais (ayah files); Mohamed Siddiq El-Minshawi with children and Mansour Al-Salimi (surah files) on `audio-cdn.tarteel.ai` | Ayah-by-ayah recitation | **Unconfirmed** (QUL: "We don't have copyright information for this resource") | **Dependency D2**. The About screen credits QUL |

## Memorization (specs/006, specs/007)

On-device recognition of the reader's voice. The libraries are bundled. The model is downloaded
once from the project's GitHub release `asr-khatma-v1` and is never bundled. The web app
(specs/008) downloads the same files from a Hugging Face mirror, `hamzagamil/mathani-asr`
(browsers cannot read GitHub release files), with the same NOTICE. It runs sherpa-onnx's own
WebAssembly build from the `sherpa_onnx_web` package (Apache-2.0, as sherpa-onnx), which
includes ONNX Runtime.

| Component | Used for | Licence | Requirements |
| --- | --- | --- | --- |
| sherpa-onnx 1.13.8 (`sherpa_onnx` and its platform packages) | Voice activity detection and recognition | Apache-2.0 | Ship the licence: the package's `LICENSE`, collected by Flutter into the licences page |
| ONNX Runtime (inside sherpa-onnx's native libraries) | Running the models | MIT | Ship the licence: `assets/licences/LICENSE-onnxruntime.txt` |
| `record` 7.1.2 | Microphone stream | MIT | Ship the licence: the package's `LICENSE`, collected by Flutter |
| Khatma FastConformer (https://huggingface.co/adnanfet/khatma-model): NVIDIA FastConformer-Hybrid PCD Large (ar) (https://huggingface.co/nvidia/stt_ar_fastconformer_hybrid_large_pcd_v1.0), from Tilawa's ONNX export (https://github.com/yazinsai/tilawa), unpacked to one int8 ONNX file | Recognition model (downloaded) | CC BY 4.0 (NVIDIA, the model); MIT (Tilawa, the export) | Credit NVIDIA, link the licence and **state the changes** (Khatma's and ours), and ship Tilawa's MIT text: `assets/licences/LICENSE-khatma-model.txt`, and `NOTICE.txt` in the release |
| Silero VAD (https://github.com/snakers4/silero-vad), via sherpa-onnx's model release | Voice activity model (downloaded) | MIT | Ship the licence: `assets/licences/LICENSE-silero-vad.txt`, and in the release |

## Icons and images

| Asset | Used for | Licence | Requirements |
| --- | --- | --- | --- |
| Lucide icons, `lucide-static` 1.48.0 font (`assets/fonts/Lucide.ttf`, tree-shaken in release builds) | Interface icons | ISC (`assets/fonts/LICENSE-Lucide.txt`) | Keep the ISC notice |
| Mathani logos and app icon (brand guide «مثاني — دليل الهوية») | App icon, launch screen, About | Owned by the project | — |

## Permissions

| ID | What | Asked | Status | Date | Notes |
| --- | --- | --- | --- | --- | --- |
| D1 | KFGQPC: embed the unmodified KFGQPC Uthmanic Script HAFS font in a free app on the App Store and Google Play, and (specs/008) in the free web app at get.mthani.app | not yet | requested / granted / refused | — | Contact via https://fonts.qurancomplex.gov.sa. Draft: [permissions/kfgqpc-request.md](permissions/kfgqpc-request.md) (with D3) |
| D2 | QUL / Tarteel: redistribute the KFGQPC layout and word-by-word data inside the app (and, specs/008, the web app); and (specs/006) use the ayah timings of 7 surah recitations and stream/download the 3 Tarteel-hosted recordings | not yet | requested / granted / refused | — | Contact via https://qul.tarteel.ai. Draft: [permissions/qul-request.md](permissions/qul-request.md) |
| D3 | KFGQPC: bundle the unmodified Madinah Mushaf page fonts (604) in the app (since 2026-10-23; previously planned as a hosted download); in the web app (specs/008), served only from get.mthani.app to draw each page | not yet | granted | — | Same request as D1. Unblocks specs/002 task T026 |
| D4 | Quran.com Foundation / EveryAyah: stream, cache and let readers download the Al-Husary and El-Minshawi Murattal recordings in a free app on the App Store and Google Play (and, specs/008, the web app); widened (specs/006) to the 43 EveryAyah folders and 5 quranicaudio surah recordings in the draft | not yet | requested / granted / refused | — | Contact via https://quran.zendesk.com/hc/en-us. Draft: [permissions/everyayah-request.md](permissions/everyayah-request.md). **Blocks the store release** of specs/004 and specs/006 |
