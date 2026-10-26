# Release Guide

## Version

`version: x.y.z+build` in `pubspec.yaml` is the only version source. Android reads it as
`versionName`/`versionCode`, iOS as `CFBundleShortVersionString`/`CFBundleVersion`. Bump `build`
for every store upload, and keep both platforms on the same `x.y.z+build`.

## Android package name

The Play Console app is `com.mthani.app` (`applicationId` in `android/app/build.gradle.kts`). It is
permanent: every upload must keep it.

## Android signing (upload key)

Create the upload keystore once, **outside the repository**, and keep an offline backup. Losing
it means asking Google Play support for an upload-key reset.

```powershell
keytool -genkeypair -v -keystore C:\Users\Hamza\keys\mathani-upload.jks `
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties` (gitignored, never committed):

```properties
storePassword=<store password>
keyPassword=<key password>
keyAlias=upload
storeFile=C:\\Users\\Hamza\\keys\\mathani-upload.jks
```

`android/app/build.gradle.kts` signs release builds with it when present, and falls back to debug
keys otherwise. A store upload must never be built without it. Enrol in Play App Signing on first
upload.

The upload key also lives in the GitHub repository secrets, for a future CI release job:
`ANDROID_UPLOAD_KEYSTORE_BASE64` (the `.jks`, base64), `ANDROID_UPLOAD_STORE_PASSWORD`,
`ANDROID_UPLOAD_KEY_PASSWORD` and `ANDROID_UPLOAD_KEY_ALIAS`. GitHub secrets cannot be read back,
so they are not a backup: keep the offline copy too.

## iOS signing (CI)

iOS builds and signing run on macOS CI (`.github/workflows/ios-release.yml`, started by hand
from the Actions tab), because the developer machine is Windows. It builds a signed `.ipa` and
uploads it to App Store Connect, where it appears in TestFlight.

- **Team**: Mercury Engineering & Consultations LLC (`YJBH85NYZU`), the seller shown on the store.
- **Bundle ID**: `com.mthani.app`, the same as the Android package name, and permanent once the
  App Store Connect app exists.
- **Signing**: manual for Release and Profile (`ios/Runner.xcodeproj`, `ios/ExportOptions.plist`):
  certificate "Apple Distribution: Mercury Engineering & Consultations LLC" and profile
  "Mathani App Store" (IOS_APP_STORE). Both expire on **22 Oct 2027**: create new ones then
  and update the secrets.
- **Repository secrets**: `IOS_DIST_CERT_P12_BASE64`, `IOS_DIST_CERT_PASSWORD`,
  `IOS_APPSTORE_PROFILE_BASE64`, and the App Store Connect team API key
  `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_PRIVATE_KEY`.
  Offline copies of the `.p12` (and its password), the certificate key and the `.p8` are kept with
  the Android upload key.

Every upload needs a new build number: bump `+build` in `pubspec.yaml`, or set the workflow's
`build_number` input.

## Release builds

```powershell
flutter build appbundle --release --obfuscate --split-debug-info=symbols/android
flutter build ipa --release --obfuscate --split-debug-info=symbols/ios   # macOS CI
```

Keep `symbols/` from each release (gitignored) to symbolicate crash stack traces. `--analyze-size`
cannot be combined with `--split-debug-info`: measure size with a separate build, as CI does
(`flutter build appbundle --release --target-platform android-arm64 --analyze-size`).

## Web (specs/008)

The web app is published to https://get.mthani.app from **Cloudflare Pages** (moved from Netlify
on 2026-10-26).

- **Project:** `mthani-web` in the Cloudflare account "Hamzagamil@gmail.com's Account". The
  production branch is `main`; it is also served at https://mthani-web.pages.dev.
- **Why Cloudflare:** static files on Pages carry no bandwidth charge (Netlify's free plan is a
  credit pool). Cloudflare Web Analytics is off, and stays off (FR-027).
- **The landing site** (mthani.app, www, `/privacypolicy`) moved to Cloudflare Pages the same day:
  project `mthani-landing`, deployed with `node _deploy/deploy.mjs` from the landing folder.
  Email for @mthani.app goes through Cloudflare Email Routing (catch-all to the owner's Gmail).
- **DNS:** mthani.app is registered at Namecheap with Cloudflare's nameservers, so records are
  edited in the Cloudflare dashboard. `get` (and `read`) are CNAMEs to `mthani-web.pages.dev`,
  and get.mthani.app is a custom domain of the Pages project. The certificate comes from Google's CA
  through Cloudflare.
- **Sign-in:** run `npx wrangler@4 login` once per machine. The deploy script uses wrangler's
  session. The development machine inspects HTTPS, so the script runs Node with
  `--use-system-ca` (and IPv4 first, or the parallel uploads time out).

Release from the same commit and version as the store builds (FR-029):

```powershell
flutter build web --wasm --release --no-web-resources-cdn
node --use-system-ca tool/web_deploy.mjs --dry-run   # a preview: https://<hash>.mthani-web.pages.dev
node --use-system-ca tool/web_deploy.mjs             # publish to get.mthani.app
```

The deploy script:
- gzips the Quran database;
- compiles the speech worker;
- writes `asset-hashes.json`;
- stamps the service worker;
- fills in the inline-script hash in `_headers`;
- refuses a build whose version, engine settings, browser list or placeholders are wrong.

To roll back, open Cloudflare dashboard › Workers & Pages › mthani-web › Deployments, then use
"Rollback to this deployment" on an earlier one. No upload is needed.

Pages limits (free plan): 20,000 files per deployment and 25 MiB per file. The build has about
680 files; the largest is sherpa-onnx's WebAssembly at about 15 MB.

## Release checklist

- [ ] `dart run tool/verify_quran.dart` prints PASS; record the `quran.db` SHA-256 below.
- [ ] D1 (KFGQPC font) and D2 (QUL data) resolved in `docs/licences.md`.
- [ ] Download size grows by no more than 1 MB over `docs/size_baseline.json` on each platform, or
      the growth is explained and approved (`size-approved` label); then update the baseline with
      `tool/size_check.dart --update` (constitution IV, v2.0.0: no absolute budget).
- [ ] Every quickstart scenario passes on both reference devices; numbers recorded below.
- [ ] About screen shows Tanzil (with link), QUL and KFGQPC attributions.
- [ ] Store privacy answers match `docs/store/privacy.md`.

## Release log

| Version | Date | quran.db SHA-256 | Android size | iOS size | Cold start (A15 / SE2) | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1.0.0+1 | 2026-10-14 | `0561d2fa1d59908609246add9c8244671a3608d1a8c732e8112a8ea940018bd2` | 20.2 MB (arm64 APK) | — | 0.49 s on Galaxy S24 FE / — | First Google Play release. Upload key SHA-256 `43:65:6C:58:…:CE:9B:20:C9` |
| 1.1.0+2 | 2026-10-22 | `694db8ed42ebdd6b339145b778a9a732865223122d0376ad82d28856bf88bf5d` | 10.34 MB (arm64 download, CI method) | — (CI) | not measured | Print-like Mushaf page (002), search fixes (003). Device checks T037/T040 not yet run |
| 1.2.0+3 | 2026-10-23 | `fe92eb72a4c030b6999ded9c05103f4b873f6f1fac773a0ee76d21bc834881df` | ~139 MB (arm64 download; bundle 148.8 MB) | — (CI) | not measured | Printed lettering: King Fahd Complex V2 page fonts bundled (128 MB), default. Over the 30 MB constitution budget (owner decision; amendment pending). D3 request not yet sent |
| 1.3.0+4 | 2026-10-24 | `1f3e2cb68e9b80116af5f0b29795a61dcac48ba7f324ee5a0785da2a89142f26` | 140.20 MB (arm64 download, CI method) | 153.93 MB (CI) | not measured | Ayah-by-ayah recitations (004): Al-Husary and El-Minshawi, streaming and per-surah downloads. **Released by owner decision before D4 (EveryAyah permission) is granted and before any device checks** (004 T033, T047, T057, T062, T065, T066 open). Android +1.09 MB over 1.2.0+3 |
| 1.3.0+5 | 2026-10-24 | `1f3e2cb68e9b80116af5f0b29795a61dcac48ba7f324ee5a0785da2a89142f26` | ~140.2 MB (code-only change from 1.3.0+4) | (CI) | not measured | Fixes from device testing of 1.3.0+4: next/previous play on the first press; the Mushaf turns with the recitation. Same open items as 1.3.0+4 (D4, device checks) |
| 1.4.0+6 | 2026-10-24 | `1f3e2cb68e9b80116af5f0b29795a61dcac48ba7f324ee5a0785da2a89142f26` | (CI; bundle 182.2 MB) | (CI) | not measured | First-run onboarding (005): preferences, tour, skip; also shown once to readers updating from 1.3.0. Removes the one-time controls hint. Checked on the Google Play Games emulator only; **released by owner decision before the device, speed/size and usability checks** (005 T038–T040). Same open items as 1.3.0 (D4) |
| 1.4.0+9 | 2026-10-25 | `2899d15b0607060cbf0f6bebfe3ca8dbf01ac69910ff351de81a7b45c2e7078e` | 169.94 MB (CI method, all ABIs; +10.52 MB per arm64 phone, approved) | ~171 MB `.ipa` (CI; +10.8 MB) | not measured | 46 reciters from EveryAyah and QUL (006 US1) and memorization: recite from memory with the words hidden and revealed as recited, then a score (US2, US3). **Released by owner decision before D2 (QUL timings and Tarteel audio) and D4 (EveryAyah and Quran.com audio) are granted, before the S1 accuracy spike and before any device checks** (006 T024, T026, T030, T035, T054, T057, T059 open). Privacy policy updated for the microphone (2026-10-25). 1.4.0+7 and +8 went to TestFlight only |
| 1.5.0+10 | 2026-10-25 | `2899d15b0607060cbf0f6bebfe3ca8dbf01ac69910ff351de81a7b45c2e7078e` | (code-only change from 1.4.0+9; not measured) | (CI) | not measured | Memorization uses the Khatma model (NVIDIA FastConformer, CC BY 4.0) and shows each word as it is recited, before the pause (007). After updating, memorization downloads a new model (≈ 108 MB, 133 MB on the phone; release `asr-khatma-v1`) and the old one is deleted. Built from the `007-khatma-live-recognition` branch, not merged to main. **Released by owner decision before the device spikes S2/S3, the test-recording comparison and any device checks** (007 T002, T025–T031, T036, T041–T044 open). iOS only (TestFlight / App Store Connect) |
