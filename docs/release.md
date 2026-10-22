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

## Release checklist

- [ ] `dart run tool/verify_quran.dart` prints PASS; record the `quran.db` SHA-256 below.
- [ ] D1 (KFGQPC font) and D2 (QUL data) resolved in `docs/licences.md`.
- [ ] Download size ≤ 30 MB on each platform (`tool/size_check.dart`).
- [ ] Every quickstart scenario passes on both reference devices; numbers recorded below.
- [ ] About screen shows Tanzil (with link), QUL and KFGQPC attributions.
- [ ] Store privacy answers match `docs/store/privacy.md`.

## Release log

| Version | Date | quran.db SHA-256 | Android size | iOS size | Cold start (A15 / SE2) | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1.0.0+1 | 2026-10-14 | `0561d2fa1d59908609246add9c8244671a3608d1a8c732e8112a8ea940018bd2` | 20.2 MB (arm64 APK) | — | 0.49 s on Galaxy S24 FE / — | First Google Play release. Upload key SHA-256 `43:65:6C:58:…:CE:9B:20:C9` |
| 1.1.0+2 | 2026-10-22 | `694db8ed42ebdd6b339145b778a9a732865223122d0376ad82d28856bf88bf5d` | 10.34 MB (arm64 download, CI method) | — (CI) | not measured | Print-like Mushaf page (002), search fixes (003). Device checks T037/T040 not yet run |
