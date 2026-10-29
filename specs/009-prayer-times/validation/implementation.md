# Implementation decisions and automated evidence

2026-10-29.

## Changes from initial plan

- Dependency solving required geolocator14.0.1 and flutter_local_notifications22.3.3; see dependencies.md. Existing wakelock1.8.1 remains unchanged. No dependency overrides or OS-floor changes were used.
- Repository inspection found a fixed reader toolbar, not a navigation sheet. Prayer Times is reached through a labelled Settings tile. The route owns lazy services; no new global scope/startup IO is necessary. This avoids narrow-phone toolbar overflow and preserves reader home/audio scopes. Plan/contract/T025 updated accordingly.
- Pinned adhan_dart2.0.1 has a finite hour-angle substitution when a solar altitude cannot occur, and evaluates the Asr shadow angle with midnight declination. Initial tests exposed fabricated polar sunrise and two-minute northern Asr differences. The adapter explicitly rejects out-of-domain polar sunrise/sunset, applies valid night-fraction twilight caps, and iterates the Asr shadow angle at the event instant through the pinned library's existing Meeus solver. This requires three documented internal imports; keeping the exact package pin and independent fixture matrix is mandatory until upstream behaviour changes.
- No reference tolerances were relaxed, no expected times were copied from production output, and preset offsets remain intact. The expanded independent PrayTimes source-hash-pinned matrix has 1800 cases, ten cities, five methods, two Asr conventions, two high-latitude rules, summer twilight, DST and Ramadan first/last evenings. Polar and out-of-calendar-range cases are explicit.

## Observed results

- Initial scaffold tests: six Node endpoint failures and six missing-calculator/setup failures as expected; three shared-model/storage tests passed.
- Calculator after fixes: four tests passed, including the full 1800-case matrix within one minute, unavailable polar events, next-day Fajr and calendar coverage rejection.
- Endpoint suite: nine tests passed, including no-store, confirmation-only IP results, missing cf, coordinate validation, native/CORS, unresolved zones, preservation of device coordinates, no raw provider errors, body limits, methods/quota and a measured approximately five-second timeout.
- Narrow-screen setup widgets: Arabic and English at 320px, 1.5x text passed. Search remains reachable by scrolling; no location call occurs merely from loading the route.
- Whole-project Flutter analysis: no issues after the owned code/style corrections.
- Final whole-suite and web-build results are recorded separately after their processes finish. This file does not certify native runtime, provider coverage, user-study or release-size evidence.

## Scope boundary

Current code is the first-location schedule/setup increment and shared infrastructure. Multi-location management UI, editable calculation settings, daily athan notifications and Qiyam reminders are later open task phases. Native system permission declarations and data model fields do not mean those later features are complete.

T029/G03 needs an enabled GeoNames username, deployed endpoint configuration, live ten-city checks and actual cf metadata on HTTPS. No username is present in the current environment and no value was guessed. A concise text question was sent while independent validation continued. No provider account was created and no live deploy was performed.
