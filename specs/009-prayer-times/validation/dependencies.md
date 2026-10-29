# Dependency verification

Implementation decision, 2026-10-29: the original geolocator 14.1.2 and flutter_local_notifications 21.0.0 pins do not solve with existing wakelock_plus 1.8.1 because their Linux packages require incompatible dbus constraints. Verified public package manifests and Pub solver output rather than adding dependency overrides or changing existing wakelock behaviour.

Resolved exact direct versions: adhan_dart 2.0.1, timezone 0.11.2, geolocator 14.0.1, flutter_local_notifications 22.3.3 and flutter_secure_storage 10.3.4. Pub get succeeded; 19 packages added, existing wakelock_plus retained at 1.8.1. Plan/research/task pins updated to these compatible choices.

Downloaded Android manifests/build files confirm local_notifications minSdk24/compileSdk36/Java17; secure_storage minSdk23/compileSdk36/Java17; geolocator_android uses Flutter's minSdk24/compileSdk36. Existing project uses AGP9.1.0, Gradle9.3.1 and Java17. Flutter metadata confirms the pinned SDK. iOS 15 remains the declared target; actual iOS compilation/device verification is still pending on macOS. No platform floor was raised.

Size allowances and purposes remain in research R9; actual compressed Android/iOS size deltas have not been measured. Transitive licenses must be included by Flutter's license registry and final attribution review. Public metadata sources: https://pub.dev/api/packages/geolocator and https://pub.dev/api/packages/flutter_local_notifications .

Final native compilation result: Android debug APK built successfully with the resolved lockfile and unchanged API24/target36 configuration. Added test1.31.1 as development-only support because the pinned Flutter browser harness dereferences the application package:test entry. Its transitive package_config resolved from3.0.0 to2.2.0; test_api remains0.7.12. Browser runtime verification remains pending; development harness dependencies are not shipped runtime payloads.
