# G03 location-service validation

Status: DEPLOYED / LIVE API CHECKS PASSED (2026-10-29). Physical-device acceptance and operational policy review remain open.

## Production deployment and live checks (2026-10-29)

GeoNames account mthani is confirmed and live search now succeeds. The user authorized deployment to get.mthani.app. Built the current 008-web-app branch at 3cdbcf79091ab5dda215b3e7addf037d9b56f4f7 with Flutter 3.47.7 using `flutter build web --wasm --release --no-web-resources-cdn`; web version is 1.5.0+10. The nine endpoint contract tests passed before deployment.

Preview https://cf739fd8.mthani-web.pages.dev passed live validation before publishing. Production https://get.mthani.app is now served by deployment https://fa01cb02.mthani-web.pages.dev, including the compiled Pages Functions, configured GeoNames binding and bounded API routes.

Both preview and production passed ten-city search and coordinate/timezone resolution for Cairo, Makkah, Karachi, London, Oslo, New York, Los Angeles, Singapore, Jakarta and Sydney. Resolutions matched the reference IANA zones, preserved submitted coordinates and required confirmation. Real Cloudflare metadata returned an approximate IP candidate requiring confirmation; personal metadata was deliberately omitted from validation output.

Live checks also passed native-style no-Origin HTTP requests, approved-origin CORS, rejection of an unapproved Origin, POST preflight, invalid-input rejection, JSON content types and no-store response headers. These are endpoint checks from the workstation, not physical native-app or browser UI acceptance. Local validation logs and the checker are in ignored build/location-preview-validation.log, build/location-production-validation.log and build/check-location-live.mjs. Production homepage and version.json were checked separately.

T029 is complete: the account is enabled and the authorized preview/production endpoint checks above passed. Native-style requests here means HTTP requests without a browser Origin header; native app permission and storage acceptance remains T030. The broader operational review remains tracked by T077/G03, rather than being represented as a completed security audit. T030 remains open for real iOS/Android/web GPS permission, manual selection, IP confirmation and offline-restart flows. The earlier account/deployment blockers below are historical and are now resolved.

### Provider and application operational review

Reviewed the current [GeoNames terms](https://www.geonames.org/export/) and [credit table](https://www.geonames.org/export/credits.html): commercial usage is permitted with attribution, free capacity is 10,000 credits/day and 1,000/hour, search costs one credit and coordinate resolution costs four (nearest populated place three plus timezone one). No paid capacity was purchased. Both endpoint replies and the setup UI retain GeoNames attribution.

The deployed application source has no location logging, accepts no caller-controlled upstream host or username, and bounds search to one upstream call and resolution to two calls. Provider quota failures produce 429 with Retry-After; the client debounces search and backs off. There is no configured per-client Cloudflare rate-limit rule in wrangler.toml; these bounds do not constitute an abuse-resistant distributed rate limiter. Dashboard observability/retention and any account-level rate rules were not inspected or changed. Keep that review open in T077; do not claim Cloudflare has no infrastructure retention.

## Earlier validation history

The public endpoint contract and mocked normalization/error tests pass. Wrangler4.155.0 compiled the three Functions successfully. The local web build and preparation retain /api/prayer-* invocation routing and exclude personal responses from service-worker caches. These checks do not establish live provider access or Cloudflare geographic coverage.

No GEONAMES_USERNAME was supplied or configured by this run. The user explained they do not know what a GeoNames username is. It is the identifier of a separate GeoNames account used for city and time-zone service requests, not their Mathani or device username. The free account registration page is https://www.geonames.org/login and the service documentation requires an account username on each request: https://www.geonames.org/export/web-services.html . No account was created on the user's behalf and no password was requested.

Deployment configuration remains GEONAMES_USERNAME (server binding) and PRAYER_ALLOWED_ORIGINS. No demo credential or guessed username is used. Manual city search/device place resolution return recoverable providerUnavailable until configured. IP approximation uses Cloudflare cf metadata and needs an actual deployed Function; local fixtures are not live geo proof.

Outstanding: enabled account/configuration, authorized preview deployment, live ten-city search and timezone checks, real native HTTP requests, real cf metadata, operational logging/rate policy and no-store/CORS/SPA bypass checks. No production deploy occurred. T029 remains unchecked; T030 still needs actual iOS/Android/web end-to-end validation.

## Account supplied and verified (2026-10-29)

The user supplied the GeoNames account name mthani. It is now set in wrangler.toml as the public server-side GEONAMES_USERNAME binding; no password or secret was added. This configuration has not been deployed.

A real HTTPS Cairo search using that account failed with GeoNames status value10: user account not enabled to use the free webservice. GeoNames directs the account owner to https://www.geonames.org/manageaccount to enable access. Therefore the earlier missing-username prerequisite is resolved, but account activation and T029 live validation are still blocked. T029 remains unchecked.

Attempted to inspect browser availability for activation. The browser inventory returned no connected browsers and reported that the browser access host is unavailable. No account settings were changed, no credentials were requested, and no desktop-browser workaround was used. Next step: enable free webservices on the account page, then repeat the live lookup and preview verification. No production deployment occurred.
