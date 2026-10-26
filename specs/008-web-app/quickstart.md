# Quickstart: Mathani on the Web

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Contracts**: [web-platform](./contracts/web-platform.md), [hosting](./contracts/hosting.md)

## Prerequisites

- Flutter 3.47.7 (pinned) with web enabled, and Chrome.
- For the hosted checks:
  - Netlify CLI access through `tool/web_deploy.mjs` and its DPAPI token;
  - the new Netlify site and team;
  - DNS for get.mthani.app.
- For S2: Emscripten (only to rebuild `web/speech/`; the output is committed) and the
  `asr-khatma-v1` files uploaded to the Hugging Face repo.
- Reference devices (research R17): a mid-range laptop running Chrome and Firefox, a Galaxy A15
  in Chrome, an iPhone SE (2nd gen) in Safari, plus Safari and Edge on desktop for the matrix.
- Network throttling for timings: 20 Mbit/s down, 40 ms round trip (Chrome DevTools custom
  profile; Safari's Network Link Conditioner on macOS and iOS).

## Run locally

```text
dart run sqflite_common_ffi_web:setup      # once; commits web/sqflite_sw.js and web/sqlite3.wasm
flutter run -d chrome --wasm               # development
flutter build web --wasm --release --no-web-resources-cdn
dart compile js -O2 -o build/web/speech/speech_worker.dart.js lib/features/memorization/web_worker_main.dart
node tool/web_deploy.mjs --dry-run         # prepares build/web and creates a draft deploy with a preview URL
```

The service worker, offline use and installation need HTTPS, so test them on the draft deploy's
URL rather than on `localhost`. Chrome allows service workers on `localhost`, but Safari's
behaviour differs.

## Tests

```text
flutter test                                # VM: shared logic, FileStore rules on the memory store, LiveFollower
flutter test --platform chrome --tags web   # web seams: OPFS FileStore, database opener, gunzip, support check
flutter drive -d web-server --driver test_driver/integration_test.dart --target integration_test/app_flow_test.dart
dart run tool/size_check.dart               # phone store sizes: growth over 1 MB fails without the size-approved label
```

## Spikes (before building on them)

### S1: shell load, frames and parity

1. Deploy a draft of the reader alone (the R1, R4 and R9 steps). On each reference device, with
   the cache cleared and throttling on:
   - time from opening the URL to the first readable Mushaf page: **≤ 5 s** (SC-001);
   - time on a return visit: **≤ 2 s** (SC-002).
2. Page through 50 pages, then scroll the flowing layout for 30 s, with the performance overlay
   or DevTools on. Frames should hold 60 fps; record the jank percentage (SC-003). Do this for
   the WebAssembly build in Chrome and the JavaScript build in Firefox and Safari.
3. Check the network log: no requests to `gstatic.com`, `googleapis.com` or any other host
   outside the contract's `connect-src` list (R1).
4. Play recitations, put the tab in the background, and lock the iPhone screen. Write down where
   playback stops (R8).

**Decision**: if SC-001 fails, trim the first-visit download first (UI font weights, database
compression), then reconsider defaults. A failure is recorded in plan.md before going on.

### S2: recognition in the browser

1. Build `web/speech/` (sherpa-onnx 1.13.8, `vad-asr`, SIMD, one thread). Confirm that the
   JavaScript API accepts the omnilingual CTC model config. If it does not, patch the glue in
   `tool/build_sherpa_wasm.sh` and note it.
2. On each reference device, load the model from OPFS. Record:
   - the time to load;
   - the peak tab memory;
   - the decode time for 3 s, 8 s and 20 s of the specs/007 test clips.
3. Decode the clips from specs/007 S1 and compare the words with the desktop sherpa-onnx output.
   They must be identical (SC-006).

**Decision**:
- A device whose live pass takes longer than `liveSlowPass` uses 006's pause-based reveal. That
  is acceptable, but recorded.
- A device that cannot load the model is excluded by the R10 gate, with the "not available in
  this browser" message.
- If the reference laptop cannot do live reveal in Chrome, revisit R2 (COEP `credentialless`).

### S3: microphone parity

Record the same recitation from the laptop's microphone and the Galaxy A15's (Chrome), with the
browser's echo cancellation, noise suppression and automatic gain off, then on. Compare the
revealed words and mistakes with the phone app's. Keep the setting that matches the phone app
(R11).

## Validation scenarios

Run the matrix in each supported browser (data-model.md › Supported browser list) on the draft
deploy, then once more on get.mthani.app after publishing.

| # | Scenario | Expected | Spec |
|---|----------|----------|------|
| V1 | First visit, clear profile: read 5 pages in each layout, search "الرحمن", bookmark 2 ayat, switch to dark and Arabic, close the browser, reopen | Same page, bookmarks, theme and language; no install step | US1, FR-005–007, FR-013 |
| V2 | Turn pages with ←/→, PageUp/PageDown and a swipe; open the index and press Back; open a sheet and press Escape | Pages turn in reading direction; Back and Escape close the index or sheet and do not leave the app | US1, FR-008, FR-009 |
| V3 | Right-click an ayah; use only the keyboard to bookmark it | Same actions as a long press; focus stays visible | FR-009 |
| V4 | Compare 20 sampled pages (1, 2, 50, 77, 106, 187, 208, 250, 293, 300, 342, 377, 404, 440, 482, 505, 545, 582, 600, 604) with the phone app's screenshots | Same lines, line breaks and decorations | SC-005, FR-006 |
| V5 | Share an ayah in Safari on iOS (share sheet) and in Firefox on desktop (no Web Share) | Share sheet, or copy with a toast | US1 scenario 6 |
| V6 | Play from an ayah with two reciters (one per-ayah, one per-surah); switch tabs; pause with the media key; download a short surah; go offline; reload; play it | Highlight follows; playback continues in the background; media key works; the download plays offline | US2, FR-020, FR-021 |
| V7 | Memorization: allow the microphone, download the model (size shown first), recite a short surah with one deliberate mistake, watch DevTools › Network during the session | Words reveal live; the mistake is marked; the result matches the phone app; no request carries audio or text (only the model files on first use) | US3, FR-022–025, SC-006, SC-007 |
| V8 | Deny the microphone; open memorization in a browser without WebAssembly SIMD (or with the gate forced off) | An explanation of how to allow it, and the app keeps working; "not available in this browser" with the supported browsers listed | FR-023, FR-026 |
| V9 | Install from Chrome (desktop and Android) and add to the Home Screen from Safari on iOS; open the app offline | Own window with the Mathani name and icon; starts offline; viewed pages, bookmarks and downloads present; unviewed pages say they need a connection | US4, FR-017, FR-018, SC-008 |
| V10 | Publish a new build; open the app twice | New version in Settings › About by the second open; data intact | FR-019, FR-029 |
| V11 | Fill the storage quota (DevTools › Application › Storage › simulate a custom quota of 50 MB), then download a reciter | "Not enough space"; no partial download listed | US2 scenario 4 |
| V12 | Open the app in two tabs; bookmark in one; reload the other | The bookmark is there exactly once | Edge Cases |
| V13 | Resize the window from 360 px to 2560 px and back; zoom the browser to 200% | Centred phone column on wide windows; same page throughout; usable at 200% | FR-012, Edge Cases |
| V14 | NVDA with Chrome, and VoiceOver with Safari (macOS and iOS): turn on accessibility, open a surah from the index, play, bookmark | All reachable and announced | FR-010 |
| V15 | Open the site in a browser missing a required feature (for example Safari 15, or Firefox with `dom.storage_manager.enabled` off) | The bilingual unsupported page with store links | FR-003, Edge Cases |
| V16 | Private window: bookmark, close, reopen | Works during the session; data gone afterwards; Settings says data is kept in this browser | Edge Cases, FR-015 |
| V17 | After publishing: load https://mthani.app and https://mthani.app/privacypolicy | Unchanged apart from the new link and the web section | SC-009, FR-002, FR-028 |
| V18 | Phone release regression: run the specs/007 quickstart's reading, recitation and memorization checks on the Galaxy A15 and the iPhone SE 2, and run the size check | No behaviour change; store size growth < 1 MB | Constitution I, IV |
