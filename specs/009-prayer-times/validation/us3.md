# US3 implementation checkpoint — 2026-10-29

Status: **IN PROGRESS**. T042–T044 tests and T048 protected native queue are implemented. T045/G01 and T046/G02 remain open; dependent production playback and story acceptance are incomplete.

## Automated evidence

- Initial missing-class test runs failed before implementation (`build/prayer-queue-red.log`, `build/athan-player-red.log`).
- Prayer feature tests plus existing recitation media handler tests: **43 passed**, `build/prayer-us3-tests.log`.
- Final affected audio/scheduler/media handler rerun: **14 passed**, `build/prayer-us3-final-tests.log`.
- Android protected queue tests: **6 passed, zero failures/errors/skips**. Gradle `:app:testDebugUnitTest --tests app.mathani.mathani.PrayerAlarmStoreTest`; XML under `build/app/test-results/testDebugUnitTest/` and log `build/prayer-queue-tests.log`.
- Flutter analysis: **no issues found**, `build/prayer-us3-analysis.log`.
- Opt-in prototype compile: `flutter build apk --debug --no-pub --dart-define=PRAYER_ALARM_SPIKE=true` passed; local APK at `build/app/outputs/flutter-apk/app-debug.apk`, log `build/prayer-spike-build.log`. This is a diagnostic build, not a store release or device validation.

The pure scheduler verifies permissions/capabilities, acknowledged fallback, future finite queues, actual pending-event readback and stale/duplicate eligibility. Download/coordinator tests cover integrity, interrupted/bad responses, preview ownership, Stop during loading, pausing Quran/memorization without resuming and autoplay rejection. Native tests exercise encrypted reopen/tamper, competing claims, generation/expiry/cancellation, simulated first-unlock gating and failed writes. They do not prove Android Keystore behavior or alarm/audio startup on real hardware.

## Capability matrix

| Area | Implemented evidence | Remaining |
| --- | --- | --- |
| Protected Android queue | AES-GCM, Keystore backend, backup exclusions, atomic claims and JVM tests | Real-device Keystore/unlock recovery |
| Android single-handler route | Debug receiver/engine bridge, generated tone, acknowledged Stop, compile | G01 API/locked/cold/Doze/deadline/service-count trials |
| Catalogue/download/player core | Pure validated components and tests | Cleared two-recording catalogue, production handler integration |
| Shared scheduling policy | Pure reconciliation and capability tests | Production adapters/controller/settings/lifecycle integration |
| iOS and web reminders | Existing facade contracts | Production scheduling, foreground behavior and acceptance |
| Egyptian audio | User-reviewed Husary 0:00–0:12 local preparation | Rights for both sources and second recording review |

See [android-headless.md](android-headless.md) and [athan-assets.md](athan-assets.md). Full scheduled Android playback stays disabled. No device result, redistribution permission, completed US3 acceptance, deployment or upload is claimed.
