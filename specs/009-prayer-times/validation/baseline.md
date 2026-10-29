# Implementation baseline

Recorded 2026-10-29 before feature code changes.

- Actual Git branch: 008-web-app. Active feature: specs/009-prayer-times via .specify/feature.json.
- Pre-existing changes: modified lib/platform/file_store_web.dart; untracked .agents/ and feature specification directory. These are preserved.
- Checklist: requirements.md 16/16 checked, zero unchecked. Read-only gate passed; no markers changed.
- SDK verified: Flutter 3.47.7, Dart 3.13.5; installed Java 17.0.17; Node 24.11.1.
- Minimums read from host files: Android API24, target API36; iOS deployment target 15.0.
- Flutter devices reported Windows, Chrome 156.0.8078.48 and Edge 156.0.4314.50. No Android or iOS device is connected. This Windows host has no Xcode/iOS build capability.
- Existing size baseline: Android 178193381 bytes; iOS 161407303 bytes. No size measurement performed for this feature.
- Existing dependency versions are retained in the original pubspec.lock; feature additions are checked separately in dependencies.md.
- No extension hooks file exists. No production deployment, provider-account change or notification permission request has occurred.
- Flutter launcher required access to its normal SDK cache/preferences. Direct installed flutter_tools.snapshot invocation verified the SDK/devices; no SDK update performed.

Physical-device gates G01/G05 cannot be marked passed with the currently reported device inventory. Provider configuration and recording review remain unverified.
