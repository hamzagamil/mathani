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

## Browser/localization increment — 2026-10-29

T057 is complete: Arabic/English reminder, recording attribution, audio readiness, requested/effective mode, notification/exact-access, platform limits, fallback acknowledgement, scheduling horizon and Stop/Play text has been added and localization output regenerated. These strings are ready for settings integration; no enabled reminder UI is claimed.

T053 is partially implemented. `prayer_notifications.dart` conditionally selects the browser factory; native remains explicitly unsupported until its gated adapters are implemented. `PrayerPageNotifications` owns an in-memory, generation-checked queue and one active player, with a 30-day/192-event bound, current future horizon readback, cancellation/disposal and silent optional browser notifications. Capability reads do not prompt or claim exact/background support. Hiding/pagehide stops owned audio; resume drops missed events rather than replaying a backlog. Rejected autoplay emits a needs-Play state. The explicit Play callback is separate from scheduled delivery; `AthanPlayer.playFromUser` preserves consumed scheduled tokens while allowing a deliberate playback action.

Validation:

- Initial contract run failed for the missing page adapter (`build/prayer-page-red.log`).
- Prayer, page adapter and existing media regression run: **49 passed** (`build/prayer-browser-regressions.log`).
- Final focused run including Stop during a pending start: **12 passed** (`build/prayer-page-final-tests.log`).
- Browser bindings were compiled by the Chrome test runner after correcting a JavaScript method-tear-off error. The runner then stalled at loading with no test result and was stopped. This is **not** a passing browser execution (`build/prayer-page-chrome-tests.log`). Real notification grants, suspended-page lifecycle, OS presentation and supported-browser acceptance remain unverified.
- Flutter analysis passes (`build/prayer-page-analysis.log`).

The page adapter is not installed into the production controller yet. T053 remains open for that wiring and visible P03/mobile-link recovery UI under T058/T059, plus browser acceptance. G01/G02 continue to block dependent production native/full/audio work; neither is waived by this increment. No store build, deployment or upload was performed by this implementation invocation.

Browser behavior is based on the [Notifications Standard](https://notifications.spec.whatwg.org/) and [HTML timer rules](https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#timers), with the existing package:web binding checked by Flutter compilation. Browser capability is an active-page opportunity, not a delivery guarantee.

## Reminder preferences/settings increment

T056 is complete. The encrypted snapshot now receives daily enable/disable, selected eligible recording, requested duration and versioned fallback acknowledgement changes through controller actions. Save precedes reconciliation; a failed save preserves previous intent. Requested full mode is retained while effective delivery remains blocked or uses an explicitly acknowledged supported alternative. Authorization is a separate explicit action, never a constructor/startup prompt. Capability and audio-readiness errors clear ready horizons and leave delivery blocked. Unsupported adapters are labelled unsupported rather than incorrectly reporting a denied permission.

T058/T059 have partial implementation: the Prayer Times screen opens a reminder sheet with five switches (no sunrise), active-location context, requested/effective mode, named eligible catalogue entries and attribution, offline readiness, platform disclosures, finite horizon and fallback controls. It exposes no unapproved recordings. Stop remains visible outside the scrolling content during a loading preview and bypasses the controller busy guard. Closing the sheet stops an owned preview. Resume triggers capability/readiness reconciliation while the route is alive. The full app-scope lifecycle, notification-open routes, real native permission/settings recovery, downloaded-audio wiring and production adapters remain incomplete, so T058/T059 are **not** checked off.

Production still constructs the unsupported notification adapter with an empty recording catalogue. Users can save choices, but reminders correctly remain blocked. Test injections exercise the supported paths without enabling production Android full playback or bypassing G01/G02.

Evidence:

- Red test run for missing reminder preference/settings implementation: `build/prayer-settings-red.log`.
- Full prayer/page-adapter/media regression run: **56 passed**, including encrypted intent retention after denial, fallback acknowledgement, failed persistence, sunrise exclusion, Stop during loading and Arabic/English settings at 320×568 with 1.5× text (`build/prayer-settings-regressions.log`).
- Flutter analysis: **no issues found** (`build/prayer-settings-analysis.log`).
- Android app debug build passed (`build/prayer-settings-android-build.log`). No device execution, startup/frame measurement, store size comparison or iOS build was performed for this increment; those acceptance gates stay open.
- User corrected the former El-Minshawi candidate identity. It is excluded from preparation; `build/prayer-egyptian-review-corrected/athan_catalogue.review.json` now has **one** candidate and `readyForShipping: false`. See `athan-assets.md`.

No deployment, store upload, commit or push was performed by this invocation. No extension hooks are configured.

## Native notification increment — 2026-10-30

Production no longer uses the unsupported adapter on phones. The native short-alert route is now wired from Prayer Times, lazily after the feature opens. Daily standard system sounds require the explicit `system_notification: 1` choice; requested recording and full/opening intent remain saved and the effective sound is labelled accurately. No unapproved athan is bundled and G01 full playback is still disabled.

Android registers an Activity-independent Flutter plugin and token-only AlarmManager receiver. The Keystore/AES-GCM queue supplies presentation; the receiver validates generation, timing and an allowlisted short asset, atomically consumes one system delivery, and posts without starting Flutter or a media service. Reboot/unlock/clock/access changes restore future alarms only. Exact access is queried/requested explicitly; an inexact route needs acknowledgement and drops alerts over 60 seconds late. Two stable user-controlled channels cover standard daily and Qiyam sounds; blocked per-kind channels leave other deliverable kinds available. Channel recreation is not used to bypass settings.

iOS uses the locked notification plugin with initialization permission requests disabled, explicit authorization, future absolute UTC scheduling, the generated short CAF in Library/Sounds and pending-request verification. It keeps at most 60 total requests and cancels only app-owned requests. iOS system sound timing/Stop/Quran limitations are disclosed (P02/P07). Real iOS compilation and device presentation remain unverified; T051 stays open for eligible athan clips/full-open flow and acceptance.

Native replacement verifies all expected future tokens, not merely the last horizon. Cancellation reads back pending state and fails before location/source deletion if alerts remain. Existing padded base64 location IDs are supported without rewriting encrypted snapshots. Notification taps are handled after the first frame and open one Prayer Times route without starting audio; normal launch still opens the reader. Existing Prayer Times routes are preserved.

Implementation tasks T052/T054/T058/T060 are complete for these supported paths. T049/T050/T051/T053/T055/T059/T061/T062/T063/T064 remain open where full playback, real recording assets, browser/whole-app lifecycle wiring or acceptance are still incomplete. See the separately implemented Qiyam tasks and evidence in [us4.md](us4.md).

Automated evidence: **123 expanded Dart tests**, **18 final focused tests**, clean Flutter analysis; logs are `build/prayer-native-tests.log`, `build/prayer-native-final-focused.log`, `build/prayer-native-analysis.log`. Native queue tests and release packaging evidence are recorded in the final build checkpoint below. A passing mock/compile does not establish device notification timing or G01/G02.

The previous statements about an unsupported production adapter describe earlier checkpoints and are superseded by this increment. No extension hooks are configured.

### Final Android build checkpoint

- Native queue: **9 tests, zero failures/errors/skips**, including padded saved-location ID compatibility, encrypted persistence, generation/claim races, once-only OS posts and cancellation/refill (`build/prayer-native-queue-tests.log`; JUnit XML under `build/app/test-results/testDebugUnitTest/`).
- Android release bundle was produced with obfuscation/resource shrinking at `build/app/outputs/bundle/release/app-release.aab` (255271212 bytes at the inspected checkpoint), log `build/prayer-native-release-build.log`. This is a local compile check with the existing build number, not a new store delivery or a store-download-size measurement.
- ZIP inspection confirmed `base/res/raw/qiyam_tone.wav` (52964 bytes) and the bundled iOS CAF (14205 bytes). The debug spike tone, disputed Minshawi source and unapproved Husary recording are absent. The merged release manifest has POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, RECEIVE_BOOT_COMPLETED and the non-exported receiver; no background-location/full-screen permission was added.
- Final Dart verification: **123 expanded regression tests**, **18 focused tests after final copy changes**, and **clean analysis**. No iOS build or physical notification execution was available; those remain explicit acceptance work.

No store upload, deployment, commit or push was performed for this increment. Full athan audio and G01/G02 remain open. The original prior release artifacts are unchanged in their preserved release directory; do not confuse this local compile-check bundle with a published iOS/Android pair.
