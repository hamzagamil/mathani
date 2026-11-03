# Quickstart: Online Mutashabihat Editor

**Feature**: [spec.md](./spec.md) | **Contracts**: [content-api](./contracts/content-api.md),
[editor-api](./contracts/editor-api.md), [editor-ui](./contracts/editor-ui.md)

## Setup (once)

### By Claude Code, with wrangler's login

1. Create the database, then add the printed `database_id` to `wrangler.toml`:
   ```powershell
   npx wrangler@4 d1 create mthani-mutashabihat
   ```
   ```toml
   [[d1_databases]]
   binding = "DB"
   database_name = "mthani-mutashabihat"
   database_id = "<printed id>"
   ```
2. Apply the schema:
   ```powershell
   npx wrangler@4 d1 execute mthani-mutashabihat --remote --file functions/_lib/mutashabihat-schema.sql
   ```
3. Add `OWNER_EMAIL`, `ACCESS_TEAM_DOMAIN` and `ACCESS_AUD` to `wrangler.toml` `[vars]`. The last
   two come from step 4.

### By the owner, in the Cloudflare dashboard

4. **Cloudflare Access** (Zero Trust › Access › Applications › Add › Self-hosted):
   - **Name**: «Mathani editor».
   - **Hostnames and paths**:
     - `get.mthani.app/editor`
     - `get.mthani.app/api/editor`
     - `mthani-web.pages.dev/editor`
     - `mthani-web.pages.dev/api/editor`
     - `*.mthani-web.pages.dev/editor` and `*.mthani-web.pages.dev/api/editor`, so previews are
       covered.
   - **Policy**: Allow · Include · "Login Methods: One-time PIN". Who may edit is decided by the
     editor itself (research R2).
   - **Session duration**: 24 hours.
   - **Copy**: the *Application Audience (AUD) tag* (→ `ACCESS_AUD`) and the team domain
     `<team>.cloudflareaccess.com` (→ `ACCESS_TEAM_DOMAIN`).
5. Deploy (`docs/release.md` › Web). Open `https://get.mthani.app/editor/`, sign in with the owner
   email and press «استيراد المحتوى الحالي». **Expect**: version 1 with 72 groups.

## Automatic checks

```powershell
node --test tool/mutashabihat/*.test.mjs        # server: access, checks, drafts, publish, restore, editors, content endpoint
flutter test --exclude-tags golden,web # app: updater, version choice, live swap; Dart and JS parsers agree
dart run tool/check_mutashabihat.dart
```

## E1. Fix an explanation, see it on phones (Story 1, SC-001, SC-002)

1. Install release builds made **before** the change on the Galaxy A15 and the iPhone SE, and
   open the web app.
2. In the editor, time it: search `2:35`, change one word of the explanation, «حفظ», «نشر»,
   «نشر الآن». **Expect**:
   - under 2 minutes;
   - «نُشر الإصدار ٢: عُدّلت ١».
3. Force-close and reopen each app on Wi-Fi. The updater checks at most every 6 hours, so either
   clear the app's `mutashabihat/meta.json` (debug builds) or wait. **Expect**:
   - the overlay on 2:35 shows the new word;
   - there was no store update.
4. Airplane mode, reopen. **Expect**: the new word is still there.

## E2. Groups (Story 2)

- **New group**: add one with `2:300`. **Expect**: refused, naming 2:300. Fix it to `2:30 7:11`
  with an explanation, «حفظ», then publish.
- **Remove an ayah**: remove one ayah from another group. **Expect**: after the update it is no
  longer coloured on the phone.
- **Delete and undo**: delete a group, then «تراجع عن الحذف». **Expect**: it is back and the
  Publish count drops.
- **Several groups**: open 2:35. **Expect**: links to its other groups.

## E3. Editors (Story 3, SC-007)

1. Add a second email. On another device, sign in with it. **Expect**: editing and publishing
   work, and «المحررون» is not shown.
2. Edit the same group on both devices. Save on one, then on the other. **Expect**: the second
   is refused, naming the first email.
3. Remove the editor while they are signed in. **Expect**: their next save gets «هذا البريد …
   ليس من المحررين».
4. Sign in with an email that was never added. **Expect**: the same message, and no content.
5. Without signing in, `curl https://get.mthani.app/api/editor/groups`. **Expect**: the Access
   sign-in page or `401`.
6. `curl https://mthani-web.pages.dev/api/editor/groups` with no token. **Expect**: `401`.

## E4. Undo a publish (Story 4, SC-006)

Publish a change. In «السجل», restore the previous version, and time it. **Expect**:
- under 1 minute;
- a new version «مستعاد من الإصدار …»;
- phones return to the old text after their next check.

## E5. Releases (Story 5, FR-018)

1. `dart run tool/pull_mutashabihat.dart`. **Expect**: `assets/mutashabihat/mutashabihat.md`
   now starts with `<!-- version: N -->`, the latest published version.
2. Build the app, install it on a phone with no internet, and open it. **Expect**: the latest
   content.
3. Publish once more without pulling, then run `node tool/web_deploy.mjs --prepare-only`.
   **Expect**: it stops with "bundled content vN is older than published vM: pull and rebuild".
4. Block the network and run the pull. **Expect**: a clear error, and the file unchanged.

## E6. Performance and data (SC-003, SC-004)

- Cold start on the reference phones, with and without a pending update. **Expect**: no change
  beyond noise, and ≤ 2 s.
- With the browser's network panel open on the web app, reopen it after the 6-hour window.
  **Expect**:
  - one request to `/api/mutashabihat`;
  - a `304` of under 1 KB;
  - on an update, a `200` of under 200 KB compressed.
