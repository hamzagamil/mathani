# Contract: Location Endpoints

**Spec**: [../spec.md](../spec.md) | **Research**: [R4, R5](../research.md)

Three read-only endpoints on the existing Cloudflare Pages project, live on
`https://get.mthani.app` since 2026-10-29. Code: `functions/api/prayer-*.js` and
`functions/_lib/prayer-location.js`. Tests: `tool/prayer/location_api_test.mjs`. **The server
contract does not change in this plan.** Only the client changes, as listed at the end.

## Shared rules (as deployed)

- **Base URL**: native apps call `https://get.mthani.app`; the web app calls its own origin.
- **Routing**: only `/api/prayer-*` goes through Functions (`web/_routes.json`). The service worker
  never caches these paths.
- **Headers**: every response is JSON with `Cache-Control: private, no-store`,
  `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, `Vary: Origin`.
- **CORS**: browser `Origin` is allowed for get.mthani.app, mthani.app, localhost and preview
  origins. Requests without `Origin` (native) are allowed.
- **Logging**: nothing logs queries, coordinates, IPs or results.
- **Configuration**: the GeoNames username is a Pages binding (`GEONAMES_USERNAME`), never in
  the app.
- **Upstream limits**: 5 s per upstream call and an 8 s total deadline. Search makes 1 upstream
  call, resolve makes 2.

## Place object

```json
{
  "placeId": "geonames:360630",
  "city": "Cairo",
  "region": "Cairo",
  "countryCode": "EG",
  "latitude": 30.04,
  "longitude": 31.24,
  "timezoneId": "Africa/Cairo",
  "source": "manual",
  "approximate": false,
  "requiresConfirmation": true,
  "selectable": true
}
```

The client maps `source`: `device` → `location`, `manual` → `search`, `ip` → `estimate`. A row
with `selectable: false` and `reason: "timezoneUnresolved"` is resolved with `prayer-resolve`
when tapped.

## GET /api/prayer-places?q=&lang=&limit=

City search. `q` is 2–80 characters, `lang` is `ar` or `en`, `limit` is 1–10. The response is
`{ "places": [...], "attribution": { "name": "GeoNames", "url": "https://www.geonames.org/" } }`.

## POST /api/prayer-resolve

Body: `{ "latitude", "longitude", "lang", "source" }`, at most 2 KB. The response is one place
with the submitted coordinates and the nearest place name and time zone.

## GET /api/prayer-location

The internet-based estimate from Cloudflare request metadata. No parameters. Returns a place
with `source: "ip"`, or `503 locationUnavailable`.

## Errors

The response body is `{ "error": { "code", "retryable" } }`. The client shows its own localized
text.

| HTTP | Code | Client behaviour |
| --- | --- | --- |
| 400 / 413 / 415 | `invalidRequest` | Show "Couldn't search", no retry. |
| 403 | `originNotAllowed` | Not expected from the app; treat as unavailable. |
| 422 | `timezoneUnresolved` | Keep the current place and offer search. |
| 429 | `rateLimited` | Respect `Retry-After` and offer retry. |
| 502 / 503 / 504 | `providerUnavailable` / `locationUnavailable` / `providerTimeout` | Keep the current place and offer retry or search. |

## Client changes in this plan

1. Round latitude and longitude to 2 decimals before `POST /api/prayer-resolve` (R4).
2. Request `GET /api/prayer-location` when city search opens, the phone is online and device
   location is unavailable or refused. Show the result as a "Suggested" first row (R5). No
   separate disclosure or confirm step.
3. "My location" refresh calls `prayer-resolve` only after a move of more than 10 km (R4).
4. Search keeps its 350 ms debounce and discards stale responses (existing behaviour).
