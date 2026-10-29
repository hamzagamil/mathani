# US2 saved locations and calculation settings

Status: IMPLEMENTED / AUTOMATED CHECKS PASSED / DEVICE ACCEPTANCE OPEN (2026-10-29).

The user explicitly authorized continuing implementation with device validation open. T031-T040 are complete. T030 and T041 remain unchecked; this increment does not claim physical-device or supported-browser acceptance.

## Implemented behavior

- Save independently named places, including multiple entries for the same city, with stable random IDs and per-place calculation preferences. View a saved place without activating it. Only the first saved place becomes active automatically; later saves open that place's schedule and retain the active reminder location.
- Rename with trimmed 1-80 character/control-character validation. Delete an inactive place after confirmation. Deleting the active place requires an explicit replacement or disabling all daily/Qiyam reminders. Clear only prayer data after explicit confirmation; the prayer repository does not open reader storage.
- Cancel through the injected notification boundary before erasing a location or its source snapshot. Cancellation failure leaves the saved data available for retry. The default pre-US3 adapter explicitly owns no queue. Production notification reconciliation is still T060, not a completed capability.
- Show viewed versus active status and the active reminder-location name. Provide an explicit Use for reminders action. Viewing, naming and calculation settings are usable with every reminder disabled.
- Offer five methods, all four madhhab labels and both high-latitude rules. Show the country suggestion, default Shafi'i label and middle-of-night rule, and explain Asr grouping. A draft changes only on Save. Unknown convention versions fail before persistence; explicit overrides survive restart and failed detection.
- Persist reminder generation separately from revision. Existing schema-1 snapshots without generation load as 0; no data reset or reader database migration is needed.
- Recompute only viewed/active schedules. The route-owned timer checks both location dates and wall-clock changes; the route observer refreshes on resume. This extends the existing lazy route instead of adding prayer IO or global location polling to app startup. Neither device-zone changes nor movement silently replace saved zones/preferences.

## Verification

`flutter test test/features/prayer_times` passed all 29 tests, including:

- Three-place persistence, distinct IDs for duplicate cities, transient viewing, active replacement and disabled reminders.
- Invalid labels/conventions rejected before writes; failed persistence retains active/viewed state; cancellation failure preserves data.
- Five methods × four madhhab labels × two high-latitude choices with per-place persistence and two derived Asr factors.
- All calculation dropdown choices at 320×568 with 1.5 text scaling in English and Arabic; rename validation and cancelled/confirmed active deletion through actual dialogs.
- Shared VM/device integration scenario for three saved locations, all methods/labels, viewing, activation, New York DST transition, resume across midnight, offline controller recreation, rename, replacement deletion and clear. Registered in `integration_test/prayer_times_test.dart` through the shared scenario file; run on the VM wrapper, not on a connected device.
- Existing setup, encrypted-store failure handling and independent solar reference checks remain passing.

`flutter analyze` reported no issues after the final implementation. Local ignored logs: build/prayer-us2-tests.log and build/prayer-us2-analysis.log.

The web release build passed for WebAssembly and JavaScript using `flutter build web --wasm --release --no-web-resources-cdn`. It reported the existing unused Cupertino icon-family warning; Lucide/Material icons were optimized successfully. No new dependency or full audio asset was added. This source increment has not been deployed or uploaded to stores.

The final source also passed `flutter build apk --debug` (29.4 seconds), producing build/app/outputs/flutter-apk/app-debug.apk. This is a compile check, not an Android device run. No extension hooks are configured.

## Open acceptance and next phase

T041 still needs the registered integration suite on iOS/Android and the supported browser matrix. The encrypted production adapters and real OS permission paths are not replaced by the scripted integration fixtures. Follow the commands and limitations in [us1.md](us1.md).

US3 athan work is not implemented by this increment. Before dependent production playback, T045/G01 requires actual Android cold-process/locked/Doze evidence and T046/G02 requires reviewed complete recordings and exact four-takbir clips. Full playback remains unavailable; no success or recording review has been inferred from metadata or a build.
