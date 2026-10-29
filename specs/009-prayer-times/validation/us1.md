# US1 setup and schedule acceptance

Status: PARTIAL / T030 OPEN (2026-10-29).

## Completed automated checks

- `flutter test test/features/prayer_times`: 17 tests passed. Includes T012 independent solar fixtures (1,800 combinations within one minute), T014 controller/repository/race/accessibility cases and four new shared UI flows.
- `flutter analyze`: no issues found.
- Location endpoint tests: nine passed before the deployment; real preview/production results are recorded in [location-services.md](location-services.md). T029 is complete.

The four UI scenarios live in `test/support/prayer_setup_scenarios.dart`, with a VM wrapper in `test/features/prayer_times/prayer_setup_flow_test.dart` and a device entry point in `integration_test/prayer_times_test.dart`:

1. Opening the schedule causes no location call; denied detection permits manual city selection; no snapshot is saved before confirmation; a new controller reopens the saved six-event schedule with the location client offline and makes no location request.
2. IP approximation remains transient, can be rejected, and is persisted only after confirmation.
3. Failed location replacement preserves the existing confirmed place and snapshot.
4. Polar events render Unavailable instead of a midnight value.

These tests deliberately use scripted permission/location responses and a test snapshot store. Route/controller recreation is not an OS process restart, and the test store does not establish native Keychain/Keystore or browser encrypted persistence. No hardware permission success is claimed.

## Target availability and remaining evidence

`flutter devices --machine` reported Windows, Chrome 156.0.8078.48 and Edge 156.0.4314.50. No Android or iOS target was available. This Windows machine cannot run an iOS simulator.

`flutter test --platform chrome test/features/prayer_times/prayer_setup_flow_test.dart` remained at loading without starting a scenario and was interrupted. Browser execution is not a pass. Its local ignored log is `build/prayer-flow-chrome-tests.log`.

T030 remains unchecked until the real iOS, Android and supported browser flows establish native GPS grant/denial, real manual lookup, disclosed IP confirmation, encrypted saved-state recovery after restart/offline, and unavailable-time rendering. Run the shared device suite as:

```powershell
flutter test integration_test/prayer_times_test.dart -d DEVICE_ID
```

For web integration, start a matching ChromeDriver and use the existing driver:

```powershell
flutter drive -d web-server --driver test_driver/integration_test.dart --target integration_test/prayer_times_test.dart
```

After those deterministic scenarios, run the real-service/manual device matrix in [quickstart.md](../quickstart.md), with the deployed API and actual secure persistence. Do not reset production prayer state or reader bookmarks as part of test cleanup.

## Workflow and repository checks

The requirements checklist passed 16/16 without modification. Existing ignore rules cover Flutter output, native caches, local bindings, credentials, Node modules and Python tooling. The only Node package is private brand-rendering tooling; no publishing ignore is needed. No Docker, ESLint, Prettier, Terraform or Helm setup was detected. `.specify/extensions.yml` is absent, so no pre- or post-implementation hooks are registered.

The user explicitly authorized continuing implementation with device validation open. US2 proceeded on that basis; T030 remains unchecked. See [us2.md](us2.md) for the implemented increment and its actual verification.
