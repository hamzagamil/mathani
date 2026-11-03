# Contract: Editor API

**Base**: `/api/editor/`, behind Cloudflare Access ([research R2](../research.md#r2-signing-in-and-who-may-edit)).
**Function**: `functions/api/editor/[[path]].js` → `functions/_lib/editor-api.js` `dispatch()`.

## Every request

1. **Signed in**: the `Cf-Access-Jwt-Assertion` header must be a valid Access token:
   - signed RS256 with a key from `https://{ACCESS_TEAM_DOMAIN}/cdn-cgi/access/certs`;
   - `aud` contains `ACCESS_AUD`;
   - not expired;
   - it has an `email`.

   Otherwise the request gets `401 {"error":"signIn"}`.
2. **Allowed**: the lower-cased email must be `OWNER_EMAIL` or a row in `editors`. Otherwise
   `403 {"error":"notAnEditor"}`.
3. **Responses**: JSON, `Cache-Control: private, no-store`.
4. **Writes**: they must also send `Content-Type: application/json` and come from the same origin.
   A browser sends `Origin`, and it must equal the request's own origin; anything else gets
   `403 {"error":"origin"}`.

## Endpoints

| Method and path | Who | Request | Success | Errors |
| --- | --- | --- | --- | --- |
| `GET me` | editor | none | `{email, isOwner}` | none |
| `GET groups` | editor | none | `{groups: [Group], published: {number, publishedAt, publishedBy} \| null}` | none |
| `POST groups` | editor | `{ayat, note, explanation}` | `201 Group` | `422 {error:"invalid", problems:[…]}` |
| `PUT groups/{id}` | editor | `{ayat, note, explanation, revision}` | `Group` | `404`; `409 {error:"conflict", group: Group}`; `422` |
| `DELETE groups/{id}` | editor | `{revision}` | `Group` (`deleted: true`) | `404`; `409` |
| `POST groups/{id}/undelete` | editor | `{revision}` | `Group` | `404`; `409` |
| `GET publish` | editor | none | `{changes: [Change], problems: [Problem]}` | none |
| `POST publish` | editor | `{expect: [id, …]}` | `201 Version` | `409 {error:"draftChanged"}` when the changes differ from `expect`; `422` when any group fails the checks; `400 {error:"nothingToPublish"}` |
| `GET versions` | editor | none | `{versions: [Version]}`, newest first, without `content` | none |
| `GET versions/{n}` | editor | none | `Version` with `groups` | `404` |
| `POST versions/{n}/restore` | editor | `{discardDraft: bool}` | `201 Version` | `404`; `409 {error:"draftNotEmpty"}` when unpublished changes exist and `discardDraft` is false |
| `GET editors` | owner | none | `{editors: [{email, addedAt}]}` | `403` for editors |
| `POST editors` | owner | `{email}` | `201` | `422 {error:"email"}`; `409 {error:"exists"}` |
| `DELETE editors/{email}` | owner | none | `204` | `404` |
| `POST import` | owner | `{markdown}` | `201 Version` (version 1) | `409 {error:"notEmpty"}` when any group or version exists; `422` with problems |

## Shapes

```text
Group   = {id, ayat: "2:35 7:19", note, explanation, deleted, revision,
           updatedBy, updatedAt, status: "published"|"added"|"changed"|"removed"}
Change  = {id, status: "added"|"changed"|"removed", ayat, updatedBy, updatedAt}
Problem = {id, kind: "badReference"|"noSuchAyah"|"tooFewAyat"|"emptyExplanation", message}
Version = {number, format, sha256, bytes, summary: {added, changed, removed},
           publishedBy, publishedAt, restoredFrom}
```

## Checks (FR-006, FR-010)

`functions/_lib/mutashabihat-content.js` applies the specs/010 rules:
- references are `surah:ayah`, in Western or Arabic-Indic digits;
- every ayah exists (`ayahCounts`);
- at least two distinct ayat;
- a non-empty explanation;
- a duplicate ayah is dropped.

The server stores `ayat` normalised: Western digits, Mushaf order, one space between references.
A `note` may not contain a line break. An `explanation` may not contain a line that starts with
`## `, because that would start a new group in the rendered file.
