# Contract: Owner Announcements API

Under `/api/editor/announcements`, through the existing editor dispatcher
(`functions/_lib/editor-api.js`): a valid Access token is required (401 `signIn` otherwise) and
the address must be `OWNER_EMAIL` (403 `ownerOnly` otherwise, also for editors). POST bodies are
JSON, same-origin only, as for the other editor endpoints. Responses are `private, no-store`.

## GET /api/editor/announcements

```json
{
  "configured": true,
  "limit": { "perHour": 10, "used": 2, "retryAt": null },
  "announcements": [
    {
      "id": 7, "audience": "lang_ar", "title": "…", "body": "…", "link": null, "ttl": 86400,
      "sentBy": "owner@example.com", "createdAt": 1795000000000,
      "status": "sent", "message": "projects/mthani/messages/123", "detail": null
    }
  ]
}
```

- `configured`: `FCM_SERVICE_ACCOUNT` is set and parses as a service account with
  `project_id`, `client_email` and `private_key`. It does not call Google.
- `announcements`: newest first, at most 100.
- `limit.retryAt`: milliseconds, set only when `used` is 10.

## POST /api/editor/announcements

Request:

```json
{ "requestId": "3f1c…", "audience": "all", "title": "…", "body": "…",
  "link": "https://get.mthani.app/k/ABCD…", "ttl": 86400 }
```

`link` may be omitted or null. `ttl` defaults to 86400.

| Case | Status | Body |
| --- | --- | --- |
| Field missing or outside the rules in [data-model.md](../data-model.md) | 422 | `{ "error": "invalid", "field": "title" }` |
| `requestId` already stored | 200 | the stored announcement, unchanged; FCM is not called |
| 10 sends in the last hour | 429 | `{ "error": "limit", "retryAt": 1795003600000 }`, nothing stored |
| Sent | 201 | the announcement, `status: "sent"` |
| Not sent | 201 | the announcement with its `status` and `detail` (research R7) |

A failed send is still 201: the attempt was recorded, and the page reads `status`.

## Message to FCM

As in research R3, which matches
[015 contracts/announcements.md](../../015-jumuah-duha-announcements/contracts/announcements.md).
The app needs no change.
