# Quickstart: Send Announcements from the Owner Dashboard

## Automated tests

```sh
node --test tool/announcements/*.test.mjs
```

They run the editor dispatcher with a fake D1 and a fake `fetch` for Google. They cover: owner
only (401, editor 403), field rules and limits, link host check, the message sent to FCM (topic,
channel, TTL, `data.link` only when set), the JWT claims and token reuse, `requestId` replay not
calling FCM twice, 10 per hour and `retryAt`, each failure in research R7, and `configured`.

## Owner setup (once)

1. **Service account**: Google Cloud console for project `mthani` › IAM › Service accounts ›
   Create `mthani-announcements`, role **Firebase Cloud Messaging API Admin** only. Keys › Add
   key › JSON. Check that the "Firebase Cloud Messaging API (V1)" is enabled for the project.
2. **Secret, production only**:

   ```sh
   npx wrangler@4 pages secret put FCM_SERVICE_ACCOUNT --project-name mthani-web
   ```

   Paste the whole JSON file, then delete the downloaded file. Do not set it for preview.
3. **Table**:

   ```sh
   npx wrangler@4 d1 execute mthani-mutashabihat --remote --file functions/_lib/announcements-schema.sql
   ```

4. Deploy the site as usual (`docs/release.md`).

## Manual checks

Use one Android and one iPhone with announcements on, one in Arabic and one in English.

1. **Owner only** (SC-004): open `/editor/announcements.html` as an editor who is not the owner;
   the page says it is for the owner only. `curl` a POST without the Access cookie gets 401.
2. **Preview set-up** (R2): on a preview deployment the page says sending is not set up and Send
   is unavailable.
3. **Send to one language** (Story 1, SC-002): send to Arabic readers. The Arabic phone gets it
   within 5 minutes, on the Announcements channel on Android; the English phone does not.
4. **Everyone** (Story 1 scenario 5): send to all readers; each phone gets it once.
5. **Link** (Story 2): send with a group khatma link; tapping opens that khatma. Enter
   `https://example.com` and check Send is unavailable with the message about Mathani links.
6. **Double send** (FR-011): click Confirm twice quickly; one message arrives and the history has
   one row.
7. **History and reuse** (Story 3): the sends above are listed newest first; Reuse fills the form
   without sending.
8. **Deliverable period** (Story 4): send with 1 hour to a phone in airplane mode; after 2 hours
   offline it does not arrive.
9. **Secret check** (SC-005): `git grep -n private_key` and a search of `build/web` find nothing.
