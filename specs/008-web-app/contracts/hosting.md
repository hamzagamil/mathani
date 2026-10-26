# Contract: Hosting and Deploy

**Feature**: [../spec.md](../spec.md) | **Research**: R4, R5, R6, R9, R14, R15

> **Updated 2026-10-26**: the web app moved to Cloudflare Pages (project `mthani-web`). See
> research.md › Changes made during implementation, row 14, and docs/release.md › Web.
> `_headers`, the files and the checks below are unchanged. Deploys go through `wrangler pages
> deploy`, and rollback through the Pages dashboard.

## Sites

| Address | What | Netlify site | Netlify team | Deployed by |
|---------|------|--------------|--------------|-------------|
| https://mthani.app | landing pages, `/privacypolicy` | existing (`c3e3e583-…`) | existing | `Mathani-landing/_deploy/netlify-deploy.mjs` (partial deploys, unchanged) |
| https://get.mthani.app | the web app | **new** | **new, separate** (R5) | `tool/web_deploy.mjs` (full deploys) |

DNS: `get.mthani.app` is a CNAME to the new site's `*.netlify.app` name. Netlify issues the
certificate, and HTTP redirects to HTTPS (FR-004).

## Build and deploy

```text
flutter build web --wasm --release --no-web-resources-cdn
dart compile js -O2 -o build/web/speech/speech_worker.dart.js lib/features/memorization/web_worker_main.dart
node tool/web_deploy.mjs [--dry-run]
```

`tool/web_deploy.mjs`:

1. Prepares `build/web`:
   - writes `assets/assets/db/quran.db.gz` and deletes `quran.db` (R4);
   - writes `asset-hashes.json`, the hashes of the files under `assets/` (R9);
   - stamps `sw.js` with the version and the build id from `version.json`.
2. Refuses to deploy when:
   - the version in `version.json` differs from `pubspec.yaml`;
   - `web/speech/` is missing;
   - a request to a Google font or engine host is found in the built JavaScript (R1);
   - the supported-browser names in `index.html` and `supported_browsers.dart` differ.
3. Deploys every file in `build/web` as a new production deploy, using the token at
   `C:\Users\Hamza\keys\netlify-token.dpapi` (never printed). With `--dry-run`, it creates a
   draft deploy and prints its preview URL.
4. Prints the deploy id, the previous deploy id (for rollback) and the team's bandwidth use this
   month.

**Rollback**: `node tool/web_deploy.mjs --restore <deploy id>` publishes an earlier deploy.
Readers move to it through the normal service worker update (data-model.md).

## Files and headers

`web/_headers`, copied into the build:

| Path | Cache-Control | Other |
|------|---------------|-------|
| `/`, `/index.html`, `/sw.js`, `/version.json`, `/asset-hashes.json`, `/manifest.json` | `no-cache` | |
| `/flutter_bootstrap.js`, `/main.dart.*`, `/canvaskit/*`, `/sqlite3.wasm`, `/sqflite_sw.js`, `/speech/*` | `no-cache` (the service worker caches them per build) | `.wasm` is served as `application/wasm` |
| `/assets/assets/qcf/*` | `public, max-age=31536000, immutable` | page fonts never change for a name; a new font is a new name |
| `/assets/*` (other) | `public, max-age=86400` | |
| `/*` | | `Content-Security-Policy` (below), `Referrer-Policy: no-referrer`, `X-Content-Type-Options: nosniff`, `Permissions-Policy: microphone=(self), camera=(), geolocation=()` |

There are no `Cross-Origin-Opener-Policy` or `Cross-Origin-Embedder-Policy` headers (R2).

**Content-Security-Policy**:

```text
default-src 'self';
script-src 'self' 'wasm-unsafe-eval' '<sha256 of the inline support check>';
worker-src 'self';
connect-src 'self' https://everyayah.com https://mirrors.quranicaudio.com https://download.quranicaudio.com https://audio-cdn.tarteel.ai https://huggingface.co https://*.hf.co;
media-src 'self' blob:;
img-src 'self' data: blob:;
font-src 'self' data:;
style-src 'self' 'unsafe-inline';
```

`connect-src` lists every host the app talks to. A new recitation host or model host has to be
added here, which keeps FR-027 checkable by reading one line.

`web/_redirects`: none. The app has a single page, and unknown paths return Netlify's 404.

## index.html and the manifest

- `index.html`:
  - `lang` and `dir` follow `navigator.language` (Arabic → `ar`/`rtl`, otherwise `en`/`ltr`).
  - The title is "Mathani · مثاني", with a description, `theme-color` for light and dark, and
    `apple-touch-icon`.
  - The inline support check (R14) runs before `flutter_bootstrap.js`. If it fails, it renders
    the unsupported page and stops.
  - The service worker is registered from the bootstrap's `onEntrypointLoaded`, so registering
    never delays the first frame.
- `manifest.json`:
  - `name` "Mathani · مثاني", `short_name` "Mathani";
  - `start_url` "/", `scope` "/", `display` "standalone";
  - the theme and background colours from `lib/app/theme`;
  - maskable 192 and 512 icons from `tool/brand`.

## Landing site changes

These go out with the existing partial deploy script and change only the named files:

- `index.html`: an "Open in your browser" link to https://get.mthani.app (FR-002).
- `privacypolicy/index.html`: a web section (R15, FR-028). It is published before the web app is
  announced.
