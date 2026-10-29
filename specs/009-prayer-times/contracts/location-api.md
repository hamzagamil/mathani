# Contract: Location Endpoints

**Feature**: [../spec.md](../spec.md) | **Research**: [R4](../research.md)

## Hosting and shared rules

Deploy three public, read-only normalization endpoints on the existing Cloudflare Pages project at https://get.mthani.app. Native builds use that base URL; web builds use same origin. Local/preview builds use an explicit development base URL, never a hard-coded production fallback. They do not calculate prayer times or store profiles.

Use Pages Functions with a configured enabled `GEONAMES_USERNAME` binding, optional provider capacity configuration, and no credentials in Flutter, committed files or responses. The username is provider configuration, not an authentication mechanism. Endpoints are public; CORS is not security for native clients. Apply Cloudflare rate controls where available and bounded provider work/timeouts; never trust client-supplied forwarding headers. On quota exhaustion return a recoverable error without buying capacity automatically.

Allow browser Origin only for get.mthani.app, explicit development localhost and configured preview origins. No wildcard with credentials, no cookies and no authentication requirement. Native requests may omit Origin; allow them subject to the same input/rate controls. OPTIONS permits only the endpoint's method and Content-Type. Function responses must set their own headers because static _headers does not govern all Function responses.

All responses: JSON, `Cache-Control: private, no-store`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, `Vary: Origin` when origin handling applies. Never cache endpoints in service worker/CDN/shared caches. No application logs containing URLs with search values, bodies, coordinates, IPs or returned place metadata. Provider request coordinates in upstream URL queries must not be copied into logs/errors. Cloudflare's infrastructure privacy/retention must be disclosed accurately.

Route only `/api/prayer-*` through Functions using _routes.json. API failures must not become index.html/SPA responses. Existing build tooling must include Functions and preserve routes, CORS and no-store headers. Host full audio as static versioned resources on the same project; no provider secret is needed for audio.

## Normalized place object

```json
{
  "placeId": "geonames:360630",
  "city": "Cairo",
  "region": "Cairo",
  "countryCode": "EG",
  "latitude": 30.0444,
  "longitude": 31.2357,
  "timezoneId": "Africa/Cairo",
  "source": "manual",
  "approximate": false,
  "requiresConfirmation": true
}
```

Coordinates must be finite and within geographic bounds. Timezone must be a valid IANA identifier recognized by the client; no numeric-offset substitute. Unknown/incomplete fields must not be turned into plausible defaults. `approximate=false` on a manual city means explicitly selected city coordinates, not street-level position accuracy. Provider place IDs are opaque.

## GET /api/prayer-places

Query: `q` trimmed 2-80 characters; `lang` ar/en, default en; optional ISO country filter; `limit` integer 1-10, default 10. Invalid parameters return 400 without an upstream request. The client debounces about 350ms, cancels stale searches and never resolves an older search over newer input.

Call HTTPS GeoNames searchJSON using featureClass=P, style=FULL, bounded maxRows and configured username. Normalize populated places and include region/country for disambiguation. Every saveable item must have a timezone. If absent, return selectable=false, resolvable=true and reason=timezoneUnresolved, with a Resolve action that calls prayer-resolve before confirmation. Do not fan out ten timezone requests per keystroke.

Success 200: `{ "places": [place], "attribution": { "name": "GeoNames", "url": "https://www.geonames.org/" } }`. Empty results return an empty list, not a provider failure. Selecting a result is an explicit manual confirmation and can save it. Selecting a timezone-unresolved result instead runs resolution and asks the user to confirm the resolved candidate.

## POST /api/prayer-resolve

JSON body: latitude, longitude, lang=ar/en, and optional source=device/manual. Limit request body to 2 KB, reject non-JSON, invalid ranges, nonfinite values and unsupported source. Coordinates belong in this POST body, not the client URL.

Resolve nearest name using findNearbyPlaceNameJSON and the IANA zone using timezoneJSON. Preserve submitted device coordinates, not the city's centroid. A place name may be absent; valid coordinates plus timezone can return a localized coordinate label and explicit unnamed-place state. If timezone cannot be resolved, return timezoneUnresolved; never use device timezone as a guess. Return 200 normalized candidate and attribution. Confirmation only persists the chosen candidate locally; there is no server save endpoint.

## GET /api/prayer-location

Called only after explicit IP-approximation disclosure. No query, body, coordinates or client IP parameter. Read Cloudflare's trusted `context.request.cf` metadata: latitude, longitude, timezone, city/region/country where present. Do not infer identity or use an external IP provider.

Success 200 returns normalized place with source=ip, approximate=true, requiresConfirmation=true and no raw IP. It never activates or saves a location itself. Missing/invalid coordinate or zone fields return 503 locationUnavailable. Local environments inject fixtures; deployed preview validates real metadata rather than fabricating success from the device timezone.

## Errors and operational bounds

Error envelope: `{ "error": { "code": "providerUnavailable", "retryable": true } }`. Human-readable user text is localized on the client; no upstream raw body, token, query or coordinate echo.

| HTTP | Code | Behaviour |
| --- | --- | --- |
| 400 | invalidRequest | Fix input; do not retry automatically. |
| 403 | originNotAllowed | Reject unapproved browser origin. |
| 405 | methodNotAllowed | Return Allow header; no provider call. |
| 413 / 415 | invalidRequest | Oversized body or unsupported content type. |
| 422 | timezoneUnresolved | Preserve prior location; offer manual selection. |
| 429 | rateLimited | Include safe Retry-After; client respects it. |
| 502 | providerUnavailable | Upstream invalid data/error; preserve prior state. |
| 503 | locationUnavailable or providerUnavailable | Missing geo metadata/configuration/quota; manual fallback remains. |
| 504 | providerTimeout | Stop work after bounded deadline; offer retry. |

Limit a search to one upstream request. Resolve may use at most two. Upstream request timeout 5 seconds each and total endpoint deadline 8 seconds; abort remaining work on deadline. No indefinite retry loop; client offers explicit retry and respects connectivity. Do not retry denied location permission as network failure.

## Privacy and coverage acceptance

Before enabling production, verify GeoNames account, commercial terms/attribution and service coverage for the ten reference cities. Audit Function logging configuration, error paths, CORS, no-store and service-worker bypass. Verify input cannot change the upstream host/path or username. IP approximation is best-effort; VPN/wrong/missing results require confirmation/manual correction. No endpoint retains the user's search history or locations. Static asset requests continue bypassing Functions.
