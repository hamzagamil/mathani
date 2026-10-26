# Validation log: Mathani on the Web

**Feature**: [spec.md](./spec.md) | **Quickstart**: [quickstart.md](./quickstart.md)

## 2026-10-26: local build, headless Chrome 155 (development laptop)

This is the release build (`flutter build web --wasm --release --no-web-resources-cdn`, then
`node tool/web_deploy.mjs --prepare-only`), served from `127.0.0.1` with the MIME types Netlify
sends. It is not yet a Netlify deploy.

| Check | Result |
|---|---|
| First visit, clean profile | Onboarding (step 1 of 4), no errors |
| Skip onboarding | Al-Fatiha, page 1, in the printed lettering; header and toolbar shown |
| Return visit, same profile, 1440×900 window | Opens on the reader (onboarding done, kept in `user.db`), in the centred 480 px column (FR-012) |
| ← key | Turns to page 2, Al-Baqarah (FR-009) |
| Network | No request outside the site (FR-027); the Arabic fallback font comes from `font-fallback/` |
| WebAssembly build | skwasm, single-threaded, as research R2 expected |

### Bugs found and fixed on the way

- **Every database was the same file.** The browser's databases directory is `/`, so the paths
  became `//quran.db`, `//quran.version` and `//user.db`. The browser file system takes `//name`
  as `/`, so writing the version file overwrote the Quran database ("file is not a database").
  - Fix: `databasePath()` in `lib/platform/database_*.dart`.
  - The old preview had the same latent bug: `user.db` and `quran.db` shared a file.
- **Engine settings ignored.** With a custom `onEntrypointLoaded`, settings given to
  `_flutter.loader.load` must be passed to `initializeEngine()` again, or the engine fetches
  fallback fonts from fonts.gstatic.com.
  - Fix: `web/flutter_bootstrap.js` passes them.
  - The one fallback font the reader needs is mirrored in `web/font-fallback/` (OFL).
- **`_headers` missing from some builds.** Flutter does not always copy `web/_headers` into
  `build/web`; `tool/web_deploy.mjs` now copies it every time.

## Not yet run

- The draft deploy on Netlify (needs T005), and every V-scenario in the supported-browser matrix.
- `flutter test --platform chrome`: on this machine the runner stays at "loading" and then
  reports "Connection closed before test suite loaded", for both test/web files. Not resolved.
  The same checks were exercised in the real app above.
- Phones (V18): the Phase 2 refactors pass every VM test, including the desktop sherpa-onnx run,
  but have not been run on the Galaxy A15 or the iPhone SE 2.
