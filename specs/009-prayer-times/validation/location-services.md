# G03 location-service validation

Status: BLOCKED / NOT VERIFIED (2026-10-29).

The public endpoint contract and mocked normalization/error tests pass. Wrangler4.155.0 compiled the three Functions successfully. The local web build and preparation retain /api/prayer-* invocation routing and exclude personal responses from service-worker caches. These checks do not establish live provider access or Cloudflare geographic coverage.

No GEONAMES_USERNAME was supplied or configured by this run. The user explained they do not know what a GeoNames username is. It is the identifier of a separate GeoNames account used for city and time-zone service requests, not their Mathani or device username. The free account registration page is https://www.geonames.org/login and the service documentation requires an account username on each request: https://www.geonames.org/export/web-services.html . No account was created on the user's behalf and no password was requested.

Deployment configuration remains GEONAMES_USERNAME (server binding) and PRAYER_ALLOWED_ORIGINS. No demo credential or guessed username is used. Manual city search/device place resolution return recoverable providerUnavailable until configured. IP approximation uses Cloudflare cf metadata and needs an actual deployed Function; local fixtures are not live geo proof.

Outstanding: enabled account/configuration, authorized preview deployment, live ten-city search and timezone checks, real native HTTP requests, real cf metadata, operational logging/rate policy and no-store/CORS/SPA bypass checks. No production deploy occurred. T029 remains unchecked; T030 still needs actual iOS/Android/web end-to-end validation.

## Account supplied and verified (2026-10-29)

The user supplied the GeoNames account name mthani. It is now set in wrangler.toml as the public server-side GEONAMES_USERNAME binding; no password or secret was added. This configuration has not been deployed.

A real HTTPS Cairo search using that account failed with GeoNames status value10: user account not enabled to use the free webservice. GeoNames directs the account owner to https://www.geonames.org/manageaccount to enable access. Therefore the earlier missing-username prerequisite is resolved, but account activation and T029 live validation are still blocked. T029 remains unchecked.

Attempted to inspect browser availability for activation. The browser inventory returned no connected browsers and reported that the browser access host is unavailable. No account settings were changed, no credentials were requested, and no desktop-browser workaround was used. Next step: enable free webservices on the account page, then repeat the live lookup and preview verification. No production deployment occurred.
