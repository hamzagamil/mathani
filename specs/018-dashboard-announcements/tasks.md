# Tasks: Send Announcements from the Owner Dashboard

**Input**: Design documents from `specs/018-dashboard-announcements/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included. The plan and quickstart name `node --test tool/announcements/*.test.mjs`,
matching the project's existing Function tests (`tool/mutashabihat`, `tool/khatma`).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1 write and send, US2 link, US3 history, US4 deliverable period

## Phase 1: Setup

- [X] T001 Create `functions/_lib/announcements-schema.sql` with table `announcements` exactly as in `data-model.md`: `id INTEGER PRIMARY KEY AUTOINCREMENT`, `request_id TEXT NOT NULL UNIQUE`, `audience TEXT NOT NULL` (`all`, `lang_ar` or `lang_en`), `title TEXT NOT NULL`, `body TEXT NOT NULL`, `link TEXT`, `ttl INTEGER NOT NULL`, `sent_by TEXT NOT NULL`, `created_at INTEGER NOT NULL` (milliseconds), `status TEXT NOT NULL`, `message TEXT`, `detail TEXT`, `finished_at INTEGER`, plus `CREATE INDEX IF NOT EXISTS announcements_created ON announcements (created_at)`; header comment naming the D1 database `mthani-mutashabihat` (binding `DB`) and the apply command `npx wrangler@4 d1 execute mthani-mutashabihat --remote --file functions/_lib/announcements-schema.sql`
- [X] T002 [P] Create `tool/announcements/support.mjs`: re-export `accessKeys`, `request`, `base` from `../mutashabihat/support.mjs`; `environment()` that builds the mutashabihat environment and runs `announcements-schema.sql` on `env.DB.raw`, sets `OWNER_EMAIL` to the owner used by `accessKeys`, and optionally `FCM_SERVICE_ACCOUNT` (a JSON string with `project_id: "mthani"`, `client_email`, and a `private_key` PEM from a freshly generated RSA key); and `fakeGoogle()` returning a `fetch` stand-in that records calls, answers `https://oauth2.googleapis.com/token` with `{access_token, expires_in: 3600}` and `https://fcm.googleapis.com/v1/projects/mthani/messages:send` with `{name: "projects/mthani/messages/<n>"}`, with switches to answer any status/body or to throw (network)
- [X] T003 [P] Add a step `Owner announcements functions` running `node --test tool/announcements/*.test.mjs` after the group khatma step in `.github/workflows/ci.yml`

---

## Phase 2: Foundational (blocks all stories)

- [X] T004 Create `functions/_lib/fcm.js` (research R1, R2, R7): `parseServiceAccount(text)` → `{projectId, clientEmail, privateKey}` or null when missing fields or bad JSON; `isConfigured(env)`; `accessToken(account, {fetch, now})` signing an RS256 JWT (`iss` = `sub` = client email, `scope` `https://www.googleapis.com/auth/firebase.messaging`, `aud` `https://oauth2.googleapis.com/token`, `iat`, `exp` = iat + 3600) with Web Crypto `importKey('pkcs8', …)` from the PEM, posting `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=…` form-encoded, caching the token in module memory until 5 minutes before expiry; `send(env, message, {fetch, now})` → `{status: 'sent', message: name}` or `{status, detail}` mapped exactly as the R7 table (no secret / bad JSON / token 400–401 / FCM 401–403 → `notConfigured`; FCM 400 → `rejected`; FCM 429 → `busy`; FCM 5xx, network error or 10 s `AbortSignal.timeout` → `unavailable`), `detail` cut to 500 characters and never containing the key; export `clearTokenCache()` for tests. Injected `fetch` defaults to `globalThis.fetch`
- [X] T005 Create `functions/_lib/announcements.js` exporting `announcementsAdmin(method, body, env, who, {now, fetch})` → `{status, body}` with the shared helpers: `row → JSON` mapping (`sentBy`, `createdAt`, camelCase per `contracts/announcements-api.md`), a `count(text)` of code points (`[...text].length`), and the topic table `all | lang_ar | lang_en`; returns 404 for any method other than GET and POST, 503 `unavailable` without `env.DB`
- [X] T006 Route `path[0] === 'announcements'` in `functions/_lib/editor-api.js` beside the `khatma` branch: 403 `{error: 'ownerOnly'}` unless `isOwner`, otherwise `announcementsAdmin(method, body, env, who, {now})`; only `/api/editor/announcements` with no further path segment, 404 otherwise
- [X] T007 [P] Tests in `tool/announcements/fcm.test.mjs`: `parseServiceAccount` accepts the fixture and rejects missing `private_key`/bad JSON; the JWT sent to the token endpoint has the R1 claims and verifies with the fixture's public key; a second send within the hour reuses the token (one token call); each R7 mapping row, including a thrown fetch and a timeout; `detail` never contains `PRIVATE KEY`
- [X] T008 [P] Tests in `tool/announcements/access.test.mjs`: GET and POST without a token → 401 `signIn`; as an editor who is not the owner → 403 `ownerOnly` and FCM is never called; as the owner → 200; `/api/editor/announcements/x` → 404; a POST from another `Origin` → 403

**Checkpoint**: an owner-only route exists and can send one FCM message in tests.

---

## Phase 3: User Story 1 - Write and send an announcement (P1) 🎯 MVP

**Goal**: The owner writes title and text, picks an audience, previews, confirms and sends; the
attempt is recorded; at most one message per confirmation; 10 an hour.

**Independent Test**: quickstart Manual 1–4 and 6; `tool/announcements/send.test.mjs`.

### Tests for User Story 1

- [X] T009 [P] [US1] Tests in `tool/announcements/send.test.mjs`: a valid POST → 201, `status: 'sent'`, one FCM call whose body is `{message: {topic, notification: {title, body}, android: {ttl: '86400s', notification: {channel_id: 'announcements_v1'}}, apns: {headers: {'apns-expiration': <now/1000 + 86400 as a string>}}}}` with no `data` key; `audience` `all`/`lang_ar`/`lang_en` → the same topic; title/text trimmed; 422 `{error:'invalid', field}` for empty or spaces-only title or text, title over 65 or text over 240 code points (65/240 Arabic characters with diacritics pass when ≤ the limit in code points), unknown audience, missing or non-string `requestId`; the same `requestId` twice → second answer 200 with the stored row and still one FCM call; a failed FCM send → 201 with the R7 `status` and the row stored; without `FCM_SERVICE_ACCOUNT` → 201 `notConfigured`, no Google call; 10 `sent` rows in the last hour → 429 `{error: 'limit', retryAt: oldest.created_at + 3600000}` and nothing stored; failed rows do not count; a row 61 minutes old does not count

### Implementation for User Story 1

- [X] T010 [US1] POST in `functions/_lib/announcements.js`: validate per `data-model.md` — `requestId` string 8–64 characters; `audience` one of `all`, `lang_ar`, `lang_en`; `title` trimmed "1–65 characters"; `body` trimmed "1–240 characters" (code points); `ttl` default 86400 here (US4 widens it); then replay check by `request_id` (return 200 + stored row); then the hourly limit (research R6: `status IN ('sending','sent') AND created_at > now - 3600000`, at 10 → 429 with `retryAt`); then `INSERT … status 'sending'` (a unique-constraint race → read and return the stored row, 200); then `fcm.send` with the research R3 message (topic, notification, `android.ttl` `"<ttl>s"`, `android.notification.channel_id` `announcements_v1`, `apns.headers['apns-expiration']` = `String(Math.floor(now/1000) + ttl)`); then `UPDATE … SET status, message, detail, finished_at`; answer 201 with the row
- [X] T011 [US1] GET in `functions/_lib/announcements.js` returning `{configured, limit: {perHour: 10, used, retryAt}, announcements: []}` (history list filled in US3; `configured` from `fcm.isConfigured(env)` without calling Google)
- [X] T012 [P] [US1] Create `web/editor/announcements.html` (`lang="ar" dir="rtl"`, `noindex`, `editor.css`, `announcements.js` deferred, header bar with title «الإشعارات» and the logout link like `khatma.html`, status line `role="status"`): form with title input (`maxlength` not set, live count «n / 65»), text textarea (count «n / 240»), both `dir="auto"`; audience radio group «جميع القراء» (checked) / «قراء العربية» / «قراء الإنجليزية»; a preview card (app name «مثاني», title, text); a Send button; a confirm `<dialog>`-free panel (no browser dialogs) that names the audience in words with «تأكيد الإرسال» and «إلغاء»; an empty `<section id="history">`
- [X] T013 [US1] Create `web/editor/announcements.js` (plain JavaScript, `'use strict'`, the same `$`, `say`, `api`, `failed`, `el` helpers as `web/editor/khatma.js`, calling `/api/editor/announcements`): on load GET, and if `configured` is false say «الإرسال غير مُعدّ بعد» and keep Send disabled; live counts and preview on input, preview `dir` per field from the first strong character (research R8: Arabic → `rtl`, Latin letter → `ltr`); Send enabled only when both trimmed fields are 1–65 / 1–240 code points; Send opens the confirm panel and creates `crypto.randomUUID()` once per opening; Confirm disables itself, POSTs, and on `sent` says «تم الإرسال» and clears the form, on another status shows the R7 Arabic text and keeps the form, on 429 says when sending is possible again (`retryAt` in `ar-EG` time), on 401/403/network uses `failed`; the form survives a 401
- [X] T014 [P] [US1] Link to the page: an «الإشعارات» link in the header `nav` of `web/editor/khatma.html`; in `web/editor/index.html` an owner-only link `id="announcements-link" hidden` beside `editors-link`, shown in `web/editor/editor.js` next to `$('editors-link').hidden = !state.me.isOwner;`; and on the announcements page a link back to «بلاغات الختمات»; on load, a 403 says «هذه الصفحة لمالك التطبيق وحده.»

**Checkpoint**: the owner can send a message to an audience from the page (MVP).

---

## Phase 4: User Story 2 - Add a link that opens a place in the app (P2)

**Goal**: An optional Mathani link goes out as `data.link`; other links are refused.

**Independent Test**: quickstart Manual 5; link cases in `tool/announcements/send.test.mjs`.

- [X] T015 [P] [US2] Tests in `tool/announcements/link.test.mjs`: `https://mthani.app/x`, `https://www.mthani.app/`, `https://get.mthani.app/k/ABCDEFGHJKMNPQRS` accepted and sent as `message.data = {link}`; `null`, omitted and `""` → no `data` key; `http://mthani.app/`, `https://example.com/`, `https://mthani.app.evil.com/`, `https://user@evil.com@mthani.app`-style tricks that `new URL` parses to another host, `javascript:…`, and over 500 characters → 422 `{field: 'link'}`
- [X] T016 [US2] In `functions/_lib/announcements.js` validate `link`: null/omitted/empty → null; otherwise `new URL(link)` must succeed with `protocol === 'https:'`, `hostname` exactly `mthani.app`, `www.mthani.app` or `get.mthani.app`, no `username`/`password`, length ≤ 500; store it and add `data: {link}` to the FCM message only when set
- [X] T017 [US2] In `web/editor/announcements.html` and `announcements.js` add an optional link input (`dir="ltr"`, `inputmode="url"`), shown under the text in the preview; the same host check on input with the message «يُسمح بروابط مثاني فقط (mthani.app)» and Send disabled while invalid

**Checkpoint**: messages with links open the right place in the app.

---

## Phase 5: User Story 3 - See what has been sent (P2)

**Goal**: History newest first, with result; reuse a past message without sending.

**Independent Test**: quickstart Manual 7; `tool/announcements/history.test.mjs`.

- [X] T018 [P] [US3] Tests in `tool/announcements/history.test.mjs`: after three sends (one failed), GET lists them newest first with every field in the contract (`id, audience, title, body, link, ttl, sentBy, createdAt, status, message, detail`); at most 100 of 105 rows; a row still `sending` is returned as `sending` with its `createdAt`; `limit.used` and `limit.retryAt` match the rows
- [X] T019 [US3] GET in `functions/_lib/announcements.js`: `SELECT * FROM announcements ORDER BY created_at DESC, id DESC LIMIT 100`, mapped with the row helper
- [X] T020 [US3] History list in `web/editor/announcements.js`: one card per row with time (`ar-EG`, medium date, short time), «أرسله» + `sentBy`, audience in words, title and text each with their own `dir`, link, deliverable period in words, and a result badge: «أُرسل» for `sent`; the R7 Arabic text plus `detail` for failures; for `sending` older than 1 minute «غير معروف، تحقّق قبل إعادة الإرسال» (data-model › Status); a «استخدام مرة أخرى» button that fills the form (title, text, link, audience, period) and scrolls to it without sending; refresh the list after each send

**Checkpoint**: every attempt is visible and reusable.

---

## Phase 6: User Story 4 - Choose how long a message may still be delivered (P3)

**Goal**: 1 hour, 1 day (default), 1 week or 4 weeks.

**Independent Test**: quickstart Manual 8; TTL cases in `tool/announcements/send.test.mjs`.

- [X] T021 [P] [US4] Tests in `tool/announcements/ttl.test.mjs`: `ttl` 3600, 86400, 604800, 2419200 each → `android.ttl` `"<ttl>s"` and `apns-expiration` now + ttl; omitted → 86400; 0, 1800, `"86400"` (string) and 2419201 → 422 `{field: 'ttl'}`
- [X] T022 [US4] In `functions/_lib/announcements.js` accept `ttl` "seconds: 3600, 86400, 604800 or 2419200" (numbers only), default 86400
- [X] T023 [US4] In `web/editor/announcements.html` and `announcements.js` add a select «مدة محاولة التوصيل»: «ساعة» (3600), «يوم» (86400, selected), «أسبوع» (604800), «٤ أسابيع» (2419200); sent with the POST, shown in history and restored by reuse

**Checkpoint**: all four stories work.

---

## Phase 7: Polish & Cross-Cutting

- [X] T024 [P] Add an "Owner announcements setup (specs/018)" section to `docs/release.md`: service account with only "Firebase Cloud Messaging API Admin", `npx wrangler@4 pages secret put FCM_SERVICE_ACCOUNT --project-name mthani-web` for production only (never preview), delete the downloaded key, and apply `functions/_lib/announcements-schema.sql` to `mthani-mutashabihat`; as unchecked boxes for the owner
- [X] T025 [P] Point spec 015's announcements contract to the new page: one line under "What the admin sends" in `specs/015-jumuah-duha-announcements/contracts/announcements.md` saying the owner page (specs/018) sends the same message and is preferred to the console
- [X] T026 Check the page at 375 px width in a browser (no horizontal scroll, buttons ≥ 44 px, works in dark mode via `editor.css`) with the Function running under `npx wrangler@4 pages dev` and the fake-free path showing «الإرسال غير مُعدّ بعد» — *done 2026-11-23 with a local stub API instead of `pages dev` (Access cannot sign tokens locally): 375 px, no horizontal scroll, all controls ≥ 44 px, link check, per-field direction, confirm, and a double Confirm adding one row*
- [X] T027 Run `node --test tool/announcements/*.test.mjs tool/mutashabihat/*.test.mjs tool/khatma/*.test.mjs` and confirm all pass (the editor dispatcher change must not break 011 or 014) — *2026-11-23: announcements 40/40 and khatma pass; 6 mutashabihat tests fail on a clean `main` too (shipped content vs. test expectations), unrelated to this feature*
- [X] T028 Secret check (SC-005): `git grep -n "private_key\|BEGIN PRIVATE KEY"` finds only the test fixture generator, and `build/web` after `tool/web_deploy.mjs`'s build has no match
- [ ] T029 Owner: run quickstart › Owner setup, then quickstart › Manual checks 1–9 on one Android and one iPhone

---

## Dependencies & Execution Order

- **Setup (T001–T003)**: none; T002 needs T001's file to exist when its tests run.
- **Foundational (T004–T008)**: after Setup. T005 before T006. T007 needs T004; T008 needs T006.
- **US1 (T009–T014)**: after Foundational. T010 → T011 (same file). T012 before T013. T014 any time after T012.
- **US2, US3, US4**: each after US1's T010 (they extend the same POST/GET and page). They touch the same files (`announcements.js` on both sides), so run them one after another: US2 → US3 → US4.
- **Polish**: T024, T025 any time; T026–T029 after all stories.

## Parallel Example

```text
# Setup
T002 tool/announcements/support.mjs   |   T003 .github/workflows/ci.yml

# Foundational tests, once T004 and T006 exist
T007 tool/announcements/fcm.test.mjs  |   T008 tool/announcements/access.test.mjs

# User Story 1
T009 tool/announcements/send.test.mjs |   T012 web/editor/announcements.html   |   T014 header links

# Each later story: its test file [P] alongside the previous story's page work
T015 link.test.mjs | T018 history.test.mjs | T021 ttl.test.mjs
```

## Implementation Strategy

1. **MVP**: Phases 1–3. The owner can send to any audience with the default deliverable period,
   and every attempt is recorded (even before the history list exists, it can be read in D1).
   Stop, run T027, do the owner setup, and check quickstart Manual 1–4 and 6.
2. **US2** (links), then **US3** (history list and reuse), then **US4** (deliverable period),
   each releasable alone with a site deploy; no app release is ever needed.
3. **Polish**: docs, the 015 cross-reference, phone-width check, secret check, owner device checks.

## Notes

- No Dart, Kotlin or Swift files change; readers' apps are untouched (spec, plan).
- No browser `alert`/`confirm`/`prompt`; confirmation is an in-page panel.
- Commit after each phase, with no AI attribution lines in commit messages (owner preference).
