# Prayer tooling

Runtime: Flutter 3.47.7, Dart 3.13.5, Node 24.11.1; Python tools may run with `uv run --python 3.12 --with hijridate==2.6.0`.

Web location calls use the current origin by default. Native defaults to https://get.mthani.app. For local/preview native runs use `--dart-define=PRAYER_API_BASE=https://your-preview.pages.dev`; native devices cannot use the workstation's localhost. Browser overrides must explicitly target an approved local/preview origin.

Pages bindings: GEONAMES_USERNAME (real enabled account, never demo) and PRAYER_ALLOWED_ORIGINS (comma-separated exact origins). Configure account binding through Pages; for local development place it in ignored .dev.vars. No credentials belong in Flutter or wrangler.toml. Requests do not require a browser Origin header on native builds; CORS is not endpoint authentication.

API paths: /api/prayer-places, /api/prayer-resolve and /api/prayer-location. Static assets bypass Functions; personal endpoint replies must not be cached or logged. No IP vendor or server-side prayer calculation is introduced.

Dependency correction: geolocator14.0.1 and local_notifications22.3.3 solve with existing wakelock1.8.1; see validation/dependencies.md. All native floors remain unchanged. Physical iOS/Android validation is not available on the current connected device list.

## Reproduce offline calculation inputs

`uv run --python 3.12 --with hijridate==2.6.0 --no-project tool/prayer/build_ramadan_table.py`

`node tool/prayer/build_reference_fixtures.mjs`

The calendar asset covers 2020-01-01 inclusive through 2038-01-01 exclusive. Ramadan night membership uses the civil date after Maghrib: the evening before Ramadan day 1 is included, the evening before Shawwal day 1 is excluded. Out-of-range conventions must remain unavailable.

PrayTimes.js2.5 is unmodified build-time-only LGPL3 reference code. Its copyright/terms are retained in tool/prayer/vendor/PrayTimes.js; it is not listed as a Flutter asset. The source SHA256 is pinned in the generator. Fixtures cover 1800 combinations across ten cities, five methods, two Asr conventions and two high-latitude choices, including summer twilight plus DST and first/last Ramadan evening dates; polar cases are explicit. Reference fixtures are not production-calculator output. Numerical comparison remains to be run in US1.

Native encrypted preferences are excluded from Android backup/transfer because their Keystore keys are not portable; the existing SQLite reader data is unaffected. iOS storage is this-device-only after first unlock. Browser encrypted origin storage has the documented weaker threat model; failed persistent reads never overwrite ciphertext and session-only recovery is explicit.
