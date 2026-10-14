# Release Guide

## Version

`version: x.y.z+build` in `pubspec.yaml` is the only version source. Android reads it as
`versionName`/`versionCode`, iOS as `CFBundleShortVersionString`/`CFBundleVersion`. Bump `build`
for every store upload, and keep both platforms on the same `x.y.z+build`.

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

iOS builds and signing run on macOS CI, because the developer machine is Windows. In App Store
Connect, create an API key (Users and Access → Integrations, App Manager role), then store these
as repository secrets: `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID` and
`APP_STORE_CONNECT_PRIVATE_KEY`. The bundle ID `app.mathani.mathani` must be registered in the
Apple Developer account first.

## Release builds

```powershell
flutter build appbundle --release --obfuscate --split-debug-info=symbols/android --analyze-size
flutter build ipa --release --obfuscate --split-debug-info=symbols/ios --analyze-size   # macOS CI
```

Keep `symbols/` from each release (gitignored) to symbolicate crash stack traces.

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
