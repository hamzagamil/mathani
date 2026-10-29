# Platform Exceptions and Verification Gates

**Feature**: [spec.md](./spec.md) | **Recorded**: 2026-10-29

These IDs are tracked within the feature and must be carried into tasks.md by speckit-tasks. They are not claims that implementation or tests have passed. Known platform exceptions are bounded design decisions; empirical gates require evidence before release.

## Justified exceptions

| ID | Requirement affected | Decision and justification | Follow-up / owner |
| --- | --- | --- | --- |
| P01 | FR-014/015, SC-004 | iOS background/terminated full automatic athan is unavailable through ordinary notifications. Offer eligible opening clip and user-initiated full playback after opening. Foreground supports both. | iOS implementer: capability copy, settings tests, physical-device matrix; revisit only if a supported OS mechanism changes. |
| P02 | FR-017, Story 3 stop/nonoverlap | iOS system-owned short notification sound cannot guarantee app Stop or pausing background Quran. Strict single-audio ownership applies to app-controlled audio; system alert interruption follows OS behaviour. Show this boundary before enablement. | Audio/iOS implementer: measure active-Quran interruption/ducking and document observed limitations; never advertise reliable app Stop for a system sound. |
| P03 | FR-015/022 | Browser closed/suspended-page precise delivery and custom automatic recitation are unavailable in this release. Schedules/settings/previews remain supported; in-page reminders are capability-dependent. | Web implementer: rejection handling, limitation text and mobile links; evaluate Web Push only as separately scoped future work. |
| P04 | FR-015/016 and restart edge case | Finite native scheduling horizon: next 60 events on iOS, 30 days on Android. No guarantee beyond shown scheduled-through without reopening/refill; no continuous background timer. | Notification implementer: visible expiry, queue counts, reopen refill, no replay after expiry, reboot restoration before horizon. |
| P05 | FR-023 and constitution secure storage | Browsers have no Keychain/Keystore. Origin-bound encrypted storage has a weaker threat model; no plaintext fallback. Explain per-browser storage and deletion. Native location data still uses protected storage. | Storage/web implementer: HTTPS/CSP/crypto/eviction tests; fail to session-only mode if secure persistence is unavailable. |

P01-P05 are also recorded in spec.md. They do not authorize further platform gaps. If G01 fails, Android full mode remains unavailable and the plan/spec must be amended with an explicit additional tracked exception before release; a fallback must not silently erase the user's requested feature.

## Required verification gates

| ID | Evidence required | Failure rule |
| --- | --- | --- |
| G01 Android headless playback | On API24, API31+, API33+ and API36, prove exact alarm -> single audio_service handler with app process absent, locked screen/Doze, acknowledged command, timely foreground promotion, one media notification, Stop, Quran pause and no late duplicate fallback. Use source corresponding to locked audio_service version, not only upstream branch. | Do not enable/advertise full scheduled Android playback until proven; investigate/revise design. |
| G02 Catalogue and platform clips | Two complete, human-reviewed recordings; preserved source/license/attribution; exact four-takbir boundaries; iOS clips <30s in supported CAF; Android fallback playable; download hash/size validation. | Replace unsuitable recording; do not truncate words or invent famous-reciter identity. No two-recording acceptance claim before this passes. |
| G03 Location services/deploy | Enabled GeoNames account, ten-city coverage, real Cloudflare cf preview response or honest unavailable result, bounded calls/rates, no-store/log redaction, same-origin web and native calls, no SPA/cache interception. | Setup remains manual/saved-only where service unavailable; do not fake GPS/IP success or ship missing mandatory manual search as complete. |
| G04 Correctness and state recovery | Independent reference fixtures, DST/Ramadan boundaries, polar unavailable states, midnight/next Fajr, Qiyam elapsed time, generation replacement, delete/revoke/restart, secure-store and browser-loss failures. | Correct discrepancy before release; never loosen one-minute accuracy or show unavailable values as midnight. |
| G05 Product/quality acceptance | SC-001..008 trials, real iOS/Android and browser matrix, size deltas, cold start/60fps/100ms, localized accessibility, privacy/attribution updates and horizon disclosures. | Missing evidence remains a release gate, not a passing checklist. |

## Planning-time status

Design and provider selection complete. G01-G05 are not executed by this planning command. No purchase, account registration, notification permission request, production deploy or audio playback was performed. GeoNames account configuration and target devices are implementation prerequisites, not unanswered architectural questions.
