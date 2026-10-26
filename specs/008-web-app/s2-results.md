# Spike S2: recognition in the browser (partial)

**Feature**: [spec.md](./spec.md) | **Quickstart**: [quickstart.md](./quickstart.md) › S2 | **Date**: 2026-10-26

## What changed from the plan

sherpa-onnx 1.13.8 already ships its own WebAssembly build: the `sherpa_onnx_web` package that
`sherpa_onnx` depends on, as web-only Flutter assets.
- It is the same version as the phones and includes the omnilingual CTC config Khatma needs.
- It is single-threaded (no `SharedArrayBuffer`), so it runs without cross-origin isolation
  (research R2).
- Its assets are marked `platforms: [web]`, so the phone builds do not grow.

So **T050's Emscripten build is not needed**:
- `web/speech/speech_worker.js` loads these files with `importScripts`. The package's own loader
  uses `eval`, which the Content-Security-Policy forbids.
- It hands `Vad` and `OfflineRecognizer` to the Dart worker.

The model download stays in `AsrModel` on the page, as on phones (FileStore + `package:http`):
- The worker only reads the saved files from the private file system into sherpa-onnx's
  in-memory file system.
- It builds the engine, then frees those copies.

## Run 1: development laptop, Chrome 155, headless (2026-10-26)

The harness was `build/web/s2.html`, not committed:
- the release files of `asr-khatma-v1` (SHA-256 sums match `asrModelFiles`) were written to OPFS;
- the real worker ran, with the trace build (`-DMEMO_TRACE=true`);
- the specs/007 clips were fed at real time in 0.1 s chunks.

| Measure | Result |
|---|---|
| Model files into OPFS (local server) | 1.3 s |
| Worker: model into sherpa-onnx, VAD and recogniser built | 3.3 s |
| Live passes, windows 0.5–9.7 s | 52–778 ms each (all under `liveSlowPass`, 2 s) |
| Pause pass, 10.8 s window | 2.05 s |
| 112:1 (3.0 s) | live: قل ال → قل هو → قل هو الله → قل هو الله احد; pause: قل هو الله احد |
| 67:1 (10.8 s) | ends تبارك الذي بيده الملك وهو علي كل شيء قدير (live and pause) |

The harness committed every live pass at its window start, so windows grew with the clip. The
app commits after each accepted word, so its windows, and its passes, are shorter.

## Still to do (T052)

- [ ] The same run on the reference devices (research R17), recording load time, peak tab memory
      and pass times:
  - the mid-range laptop in Chrome and Firefox;
  - the Galaxy A15 in Chrome;
  - the iPhone SE (2nd gen) in Safari.
- [ ] Word-for-word comparison with desktop sherpa-onnx on all eight specs/007 clips (SC-006).
- [ ] Set the gate: `webMinDeviceMemoryGb` in `device_support.dart`, and whether iOS Safari can
      hold the model (about 134 MB in the engine, plus the file read).
- [x] Memorization turned on for the web on 2026-10-26 by owner decision, **before** the device
      runs above (`speechEngineAvailable`, default true). A browser that cannot load the model
      gets "not available on this device", and the session is undone
      (`MemorizationController.start`, tested). These device runs are still owed.
