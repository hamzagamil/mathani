# Contract: Published Content for the Apps

**Endpoint**: `GET /api/mutashabihat` on `get.mthani.app` (and the web app's own origin).
**Function**: `functions/api/mutashabihat.js`. Public, with no sign-in.

## Request

| Header | When |
| --- | --- |
| `If-None-Match: "v12"` | The app already has version 12. Omitted when it has none downloaded. |

The request has no query parameters and no cookies, and no identifiers are sent (FR-017).

## Responses

### `200 OK`: a version newer than `If-None-Match`, or any version when none was sent

| Header | Value |
| --- | --- |
| `Content-Type` | `text/markdown; charset=utf-8` |
| `ETag` | `"v12"` |
| `X-Content-Version` | `12` |
| `X-Content-Format` | `1` |
| `X-Content-SHA256` | hex SHA-256 of the body |
| `Cache-Control` | `public, max-age=300` |

Body: the rendered content ([data-model.md](../data-model.md) › Rendered content). Cloudflare
compresses it in transit.

### `304 Not Modified`: `If-None-Match` equals the current version

No body. Same `ETag` and `Cache-Control`.

### `404 Not Found`: nothing published yet (before the first import)

`{"error": "notPublished"}`. Apps keep their bundled content.

### `503 Service Unavailable`: storage unreachable

`{"error": "unavailable"}`, with `Retry-After: 600`.

## What the app does (FR-012 to FR-016)

| Result | App |
| --- | --- |
| `304`, `404`, `503`, timeout (10 s) | Keeps its content. |
| `200` with `X-Content-Format` ≠ 1 | Keeps its content (made for a newer app). |
| `200` whose length or SHA-256 does not match | Keeps its content. |
| `200` with `X-Content-Version` ≤ the version in use | Keeps its content. |
| `200` whose parse has an error or no groups | Keeps its content. |
| `200` passing all of the above | Saves it, then uses it at once. |

## Caching

The function keeps the rendered body in the edge cache under the key `mutashabihat:v{N}`, and the
current `N` under the key `mutashabihat:current` for 60 seconds. A publish therefore reaches every
edge within about a minute, and D1 is read about once a minute per edge location.
