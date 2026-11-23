# Implementation Plan: Send Announcements from the Owner Dashboard

**Branch**: `018-dashboard-announcements` (feature ID; no branch created yet) | **Date**: 2026-11-23 |
**Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/018-dashboard-announcements/spec.md`

## Summary

A new owner page, `/editor/announcements.html`, writes and previews an announcement and sends it
through a new route in the existing editor API, `/api/editor/announcements`. The route checks the
Access token and the owner's address as the khatma reports route does, records the attempt in D1,
then sends one FCM HTTP v1 message to topic `all`, `lang_ar` or `lang_en`. That message has the
same fields as a console message under the feature 015 contract, so readers' apps are unchanged.

- **Sending** (research R1): a service-account JWT signed with Web Crypto, exchanged for an
  access token that is reused for its hour. No npm package.
- **Credential** (R2): the Pages secret `FCM_SERVICE_ACCOUNT`, production only. Preview
  deployments therefore can never reach readers.
- **Safety** (R4, R6): one `requestId` per confirmation, stored before FCM is called; 10 sends an
  hour.
- **History** (R5): table `announcements` in the owner area's existing database.

**Points the owner should know**:
- One owner step before it works: create a service account with only the messaging role, store
  its JSON as a production secret, and apply the new table ([quickstart.md](./quickstart.md)).
- Planning added one state the spec did not name: if a send is interrupted after it was recorded
  but before Google answered, the history shows it as "unknown, check before resending" rather
  than guessing (data-model › Status).
- History is kept with no delete button; rows can be removed in D1 (spec FR-017).

## Technical Context

**Language/Version**: JavaScript (ES modules) for the Pages Function and the page; Node 24 for
tests. No Dart, Kotlin or Swift change.

**Primary Dependencies**: none new. Web Crypto, `fetch` and the D1 binding in the Function; plain
JavaScript and `editor.css` on the page. External service: FCM HTTP v1 and Google's OAuth token
endpoint.

**Storage**: D1 `mthani-mutashabihat` (binding `DB`), new table `announcements`
([data-model.md](./data-model.md)). The access token is cached in module memory only.

**Testing**: `node --test tool/announcements/*.test.mjs`, reusing `tool/mutashabihat/support.mjs`
(signed Access tokens, fake D1, requests), added to the CI step that runs the other Function
tests. Manual checks in [quickstart.md](./quickstart.md).

**Target Platform**: Cloudflare Pages Functions (`mthani-web`). The owner page in current desktop
and mobile browsers. Readers' apps: no change; minimum OS versions stay those of the current app
(feature 015).

**Project Type**: web service + owner web page inside the existing mobile app repository.

**Performance Goals**: a send answers within 12 s at worst (10 s timeout to Google plus D1);
the history loads in one request.

**Constraints**: credential never in the repo, the page or the build (FR-003); at most one FCM call
per `requestId`; 10 sends an hour; Arabic, right-to-left page.

**Scale/Scope**: one sender (the owner), a handful of messages a week; one route, one table,
one page, about 300 lines of JavaScript plus tests.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
| --- | --- | --- |
| I. Cross-platform parity | Messages reach Android and iOS through the 015 code paths on both; the message sets the Android channel and the APNs expiry. Minimum OS versions are stated (unchanged). | Pass |
| II. Mobile-first | No app screen changes. The owner page uses `editor.css`, which already works at phone width; buttons meet 44 px. | Pass |
| III. Performance | No change to start time, frames or memory in the app; nothing runs on readers' devices that 015 did not already run. | Pass |
| IV. Lean | No new dependency in the app or the Function; 0 bytes added to store downloads. No background work. | Pass |
| V. Simplicity | Reuses the editor dispatcher, Access check, owner check, `DB` and the owner-page pattern. One new table, no new service or database. | Pass |
| Platform & store | No new permission or data collected from readers; privacy disclosures unchanged. The service-account key is a server secret, not device storage. | Pass |
| Workflow | Verification on one Android and one iOS device is in the quickstart (checks 3–5). | Pass |

**Post-design re-check (after Phase 1)**: unchanged, all pass. Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/018-dashboard-announcements/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── announcements-api.md
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
functions/_lib/
├── announcements.js            # new: validation, history, limit, requestId replay, send
├── fcm.js                      # new: service-account JWT, token cache, messages:send, error mapping
├── announcements-schema.sql    # new: table announcements
└── editor-api.js               # route /api/editor/announcements (owner only), like khatma

web/editor/
├── announcements.html          # new: form, preview, confirm, history
├── announcements.js            # new: plain JavaScript, same api()/status pattern as khatma.js
├── khatma.html                 # header link to announcements
└── index.html, editor.js       # owner-only header link, like the editors link

tool/announcements/
└── announcements.test.mjs      # new

.github/workflows/ci.yml        # run tool/announcements tests
docs/release.md                 # owner setup steps and the schema command
```

**Structure Decision**: everything lives in the existing Pages project. Owner endpoints go
through `functions/_lib/editor-api.js`, owner pages in `web/editor/`, and Function tests in
`tool/<feature>/`, as features 011 and 014 do. `fcm.js` is separate from `announcements.js` so
the Google calls can be faked in tests.

## Complexity Tracking

No violations.
