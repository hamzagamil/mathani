# Baseline: 006 recogniser (T003)

Measured 2026-10-25 on `main` at `883f41f`, before any 007 change, with
`flutter test test/unit/speech_recogniser_test.dart` on Windows (sherpa-onnx 1.13.8, desktop).
Model `build/asr/tarteel-tiny-v1` (Tarteel Whisper tiny int8), clips `build/asr/check/`.

| Set | Clips | (a) Correct ayat completed with 0 mistakes | (b) Planned mistakes caught |
| --- | --- | --- | --- |
| Alafasy check clips (1:7, 2:255, 36:1, 55:13, 67:1, 67:2, 103:3, 112:1) | 8 | **7 / 8 = 87.5%** | — (no mistake clips) |

The only failure was 2:255, a false "wrong" at word 46 (ولا يؤوده). Whisper heard «يَأُولُهُ», and
split «وسعكرسيه» as «وَسِعَكُرْ سِيُّهُ» (matched as a joined reading).

**Still to add** (T002): the Memorize-Ayah recordings (Surah Al-Mulk, correct and with planned
mistakes) and the 006 S1 volunteer sets. These live in the test project's browser storage and must
be exported from its UI ("Export audio", "Export CSV"). After they are converted with
`tool/wav_to_f32.py`, rerun this baseline: check out `883f41f`, keep `build/asr/tarteel-tiny-v1`,
and record (a) and (b) here.
