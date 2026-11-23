# Research: Send Announcements from the Owner Dashboard

## R1. How to send: FCM HTTP v1 from a Pages Function

- **Decision**: `POST https://fcm.googleapis.com/v1/projects/mthani/messages:send` with a Google
  OAuth access token. The token comes from the service account: a JWT (`RS256`, scope
  `https://www.googleapis.com/auth/firebase.messaging`, audience
  `https://oauth2.googleapis.com/token`, lifetime 1 hour) signed with Web Crypto and exchanged at
  `https://oauth2.googleapis.com/token` (`grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer`).
  The access token is kept in module memory until 5 minutes before it expires.
- **Rationale**: HTTP v1 is the only FCM send API Google still supports (the legacy server-key API
  was shut down in 2024). Web Crypto imports the PKCS#8 key from the service account file and
  signs RS256, the same primitive `access.js` already verifies with, so no npm package is needed.
- **Alternatives**: `firebase-admin` (Node-only, large, does not run in Workers); a Google Cloud
  Function as a relay (another platform and deploy for the owner); calling the console (no API).

## R2. Where the credential lives

- **Decision**: one Cloudflare Pages secret, `FCM_SERVICE_ACCOUNT`, holding the service account
  JSON, set for the **production** environment only. The service account gets only the
  "Firebase Cloud Messaging API Admin" role.
- **Rationale**: Pages secrets are encrypted, per environment, and never in `wrangler.toml` or the
  build (spec FR-003, SC-005). Leaving it out of preview means a preview deployment can show the
  page but can never reach readers (preview shares the `DB` binding, see R5). The narrow role
  limits what a leaked key could do to sending messages.
- **Alternatives**: a per-request upload of the key by the owner (clumsy, the key passes through
  the browser); a Worker of its own with the secret (another deploy for no gain).

## R3. Message shape

- **Decision**: exactly the console message the feature 015 contract describes:

  ```json
  { "message": {
      "topic": "all | lang_ar | lang_en",
      "notification": { "title": "…", "body": "…" },
      "data": { "link": "https://…" },
      "android": { "ttl": "86400s", "notification": { "channel_id": "announcements_v1" } },
      "apns": { "headers": { "apns-expiration": "<unix seconds>" } } } }
  ```

  `data` is left out when there is no link. TTL is 3600, 86400, 604800 or 2419200 seconds.
- **Rationale**: the app (015) reads `notification` and `data.link` and shows Android messages on
  `announcements_v1`; sending the same fields means no app change (spec SC-003). Topic `all`
  reaches every subscribed device once, so "All readers" is never doubled (Story 1 scenario 5).
- **Alternatives**: a condition such as `'lang_ar' in topics || 'lang_en' in topics` for
  everyone (works, but `all` is what the app subscribes to for exactly this).

## R4. One confirmation, one message

- **Decision**: the page makes a random `requestId` (UUID) when the owner opens the confirmation;
  the server stores it with a unique index. The row is written as `sending` **before** calling
  FCM. A repeated request with the same id returns the stored row and never calls FCM again.
- **Rationale**: covers double clicks, a retried request after a timeout, and two tabs (spec
  FR-011). Writing first means a crash mid-send leaves a visible `sending` row, not a silent
  duplicate later.
- **Alternatives**: disabling the button only (does not cover retries); deduplicating on the
  text (would block a deliberate resend).

## R5. Storage

- **Decision**: a new `announcements` table in the existing `mthani-mutashabihat` database
  (binding `DB`), from a new file `functions/_lib/announcements-schema.sql`.
- **Rationale**: `/api/editor/*` already requires `DB` and the owner area's data lives there; a
  third database would add a binding and a setup step for one small table. Preview shares this
  binding, so a preview send attempt is recorded as `notConfigured` and nothing reaches readers
  (R2).
- **Alternatives**: `KHATMA_DB` (reader data; keeping owner data out of it is cleaner); KV (no
  ordering or uniqueness).

## R6. Limit of 10 sends per hour

- **Decision**: before sending, count rows with `status IN ('sending','sent')` and
  `created_at` in the last hour; at 10, refuse with 429 and `retryAt` = the oldest of those
  rows + 1 hour.
- **Rationale**: the table already holds every attempt, so the limit needs no new store. Failed
  attempts do not count, so a setup problem does not lock the owner out.
- **Alternatives**: a Cloudflare rate limiting rule (counts requests, not sends, and cannot say
  when it resets).

## R7. Failures in plain words

| FCM / network result | `status` | Shown to the owner |
| --- | --- | --- |
| 200 | `sent` (keeps the returned `name`) | تم الإرسال |
| no secret, bad JSON, token exchange 400/401, FCM 401/403 | `notConfigured` | الإرسال غير مُعدّ |
| FCM 400 `INVALID_ARGUMENT` | `rejected` | رفضت خدمة الإشعارات الرسالة |
| FCM 429 `QUOTA_EXCEEDED` | `busy` | الخدمة مشغولة، أعد المحاولة لاحقًا |
| FCM 5xx, timeout (10 s), network | `unavailable` | الخدمة غير متاحة الآن |

The FCM error text is kept in `detail` for the owner; it never holds the key.

## R8. Text direction in the preview

- **Decision**: each field gets `dir` from its first strong character (Arabic range → `rtl`,
  Latin letter → `ltr`), the rule phones use for notifications. The page sets `dir="auto"` on the
  inputs as well.
- **Rationale**: matches what readers will see (spec edge case "Mixed language").

## R9. Page

- **Decision**: `web/editor/announcements.html` and `announcements.js`, plain JavaScript with
  `editor.css`, the same `api()` and status-line pattern as `khatma.js`. Links to it from the
  khatma reports page header and from the editor header (owner only, like the editors link).
- **Rationale**: one way to build owner pages (Principle V); `/editor/*` and `/api/editor/*` are
  already behind the Access application, so no Access change is needed.
