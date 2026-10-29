# Data Model: Prayer Times

**Feature**: [spec.md](./spec.md) | **Contracts**: [UI/reminders](./contracts/prayer-ui-and-reminders.md), [location](./contracts/location-api.md)

## Persistence boundary

Use a dedicated encrypted snapshot, schemaVersion=1, separate from user.db. A serialized writer commits complete validated snapshots, then reconciles derived native reminders. Do not add coordinate columns to SQLite. Native recoverable alarm state contains only opaque event/location IDs, due instants, generation, audio asset IDs and delivery state; no coordinates, IP addresses or location display names. Sensitive app-owned notification presentation data remains in protected storage. A locked/unavailable store is a recoverable blocked state, never a reason to reset bookmarks.

Browser storage is origin-local encryption with the P05 limitation. If persistence is unavailable, offer session-only operation and explicitly say changes will not survive closing. No plaintext fallback. Cache schedules in memory; recompute offline from saved places and versioned conventions. Audio files contain no user data and may use FileStore.

## Entities and relationships

### PrayerState (snapshot root)

| Field | Type / constraint |
| --- | --- |
| schemaVersion | Integer, initially 1; unknown future versions fail safely without overwrite |
| revision | Monotonic integer for serialized user changes |
| generation | Monotonic reminder invalidation counter; defaults to 0 when reading earlier schema-1 snapshots. Schedule-affecting changes advance it; renaming and transient viewing do not. |
| locations | List of SavedLocation, unique IDs |
| activeLocationId | Nullable ID referencing an existing confirmed location |
| reminders | ReminderPreferences |
| calculationVersion | Version of app convention mapping, timezone data and Ramadan table |

At most one active location. Any enabled daily/Qiyam reminder requires a confirmed active location. Viewing a different location is transient controller state, not activeLocationId. Removing the active location requires explicit replacement or disable-all confirmation.

### SavedLocation

| Field | Type / validation |
| --- | --- |
| id | Random opaque stable ID; independent of label/coordinates |
| label | Trimmed user label, 1-80 characters; no control characters |
| city, region, countryCode | Display name, optional region, ISO country code; city/region may be absent for a valid coordinate fix |
| latitude, longitude | Finite numbers, latitude -90..90 and longitude -180..180 |
| timezoneId | Valid resolvable IANA ID; no inferred device-zone fallback |
| source | device, manual, ip |
| approximate | True for IP and approximate-only device fixes |
| accuracyMeters | Optional finite nonnegative device-reported accuracy |
| confirmedAtUtc | UTC instant; required for saved/active state |
| geonamesId | Optional provider place identifier |
| calculation | CalculationPreferences |

A detected candidate is transient until timezone resolution and confirmation rules succeed. IP candidates always require explicit confirmation. Keep actual device coordinates when resolving nearby place names. No movement history or raw IP retained. Explicit refresh replaces the intended location only after a successful result; failure preserves the old record.

### CalculationPreferences

- methodId: muslim_world_league, egyptian, karachi, umm_al_qura, north_america.
- madhhabLabel: hanafi, shafii, maliki, hanbali. Derived Asr factor is Hanafi=2; other labels=1. Labels are preserved independently of that grouping.
- highLatitudeRule: middle_of_night or seventh_of_night. Default middle_of_night, explicitly shown; never silently switch rules because a result fails.
- conventionVersion: stable integer tying method offsets, Ramadan handling and rounding to reviewed fixtures.

Initial suggested method: Egypt=egyptian; Saudi Arabia=umm_al_qura; Pakistan/Bangladesh=karachi; US/Canada=north_america; elsewhere=muslim_world_league. This is an overridable app suggestion, not a claim of universal local religious practice. Default madhhab label shafii (standard Asr timing), visibly selectable. Each location retains its choices.

### DailyPrayerSchedule (derived)

- locationId, localDate (year/month/day in location zone), timezoneId.
- calculation fingerprint: coordinates + preferences + calculator/timezone/Ramadan versions.
- events: fajr, sunrise, dhuhr, asr, maghrib, isha.
- Each event: status=available/adjusted/unavailable; dueAtUtc nullable; reason code; adjustment label.
- followingFajrUtc and qiyamUtc nullable, Qiyam reason code.
- generatedAtUtc and calculationVersion for invalidation, not freshness based solely on wall-clock age.

Validate available results are finite and correctly associated with the selected date/convention. Retain cross-midnight event instants if the convention produces them; do not sort an invalid time into another prayer silently. nextPrayer scans five daily prayers across today and following days; after Isha it becomes next-day Fajr, never sunrise. The countdown compares instants, not formatted clock strings.

Qiyam uses the previous evening's Maghrib and following Fajr. qiyamUtc = maghribUtc + 2*(fajrUtc-maghribUtc)/3, rounded consistently to the displayed minute. Require positive valid boundaries. A Qiyam after midnight belongs to that night, with its actual local delivery date visible. No valid boundaries means no Qiyam event.

Umm al-Qura Ramadan intervals are versioned and zone-local evening-aware (research R3). An out-of-coverage table must produce conventionUnavailable, not a silently incorrect Isha.

### ReminderPreferences

- enabledPrayers: set drawn only from fajr/dhuhr/asr/maghrib/isha; initially empty.
- selectedAthanId: stable catalogue ID; default first eligible entry, not proof audio is ready.
- requestedMode: full/opening; initially opening.
- qiyamEnabled: false initially.
- acknowledgedFallbacks: capability-specific disclosure versions, reset if the alternative changes.

Keep requested preferences separate from effective capabilities. Denied permission preserves intent but sets blocked status. A full preference carried from foreground to iOS background is not displayed as effective full playback.

### AthanRecording (versioned catalogue, not user data)

- id, titleAr/titleEn, creditedRecorder, sourceUrl, sourceRevision, licenseId/licenseUrl, attribution/change notice.
- fullAssetUrl, SHA-256, expectedBytes, durationMs, encoding.
- openingAssetId, openingEndMs, durationMs, platform clip hashes/encodings.
- eligibility: completeRecordingReviewed, fourTakbirsReviewed, iosShortEligible (complete four takbirs and duration <30000ms).
- availability: absent/downloading/verified/failed per full recording and platform clip.

Only verified audio is offlineReady. The downloaded full asset is atomically promoted after size/hash validation. An interrupted download remains unavailable. Audio source hosts must match catalogue allowlists. Never truncate a spoken phrase to force eligibility. The selected recording applies to all five prayers; Qiyam uses a generated short tone.

### ReminderCapability (runtime, not user preference)

Permission status, exactAlarmAccess, foregroundModeSupport, backgroundModeSupport, channel/system restrictions when observable, reason and recovery action. Include scheduledThroughUtc and appMustReopenByUtc. Do not infer audible delivery from permission alone or claim to inspect unobservable iOS Focus/silent state.

### ScheduledReminder (derived/native reconciliation ledger)

- eventId: deterministic opaque token of location ID + local schedule date + prayer/Qiyam + generation.
- generation: persisted monotonic counter advanced by schedule-affecting changes.
- kind, dueAtUtc, expiresAtUtc, audio ID/mode, effective delivery mechanism.
- state: pending/claimed/playing/delivered/cancelled/failed.
- claimOwner: appAudio/systemFallback; started/consumed token for deduplication.

Android stores an immutable future recovery queue usable without an Activity. App-owned sensitive fields are protected with native Keychain/Keystore facilities; encrypted queue recovery before first device unlock may remain blocked and is disclosed. Do not expose location values in intents or notification IDs. OS-created notification storage is subject to platform protection rather than application database encryption.

## State transitions and reconciliation

1. Setup: empty -> detecting/searching -> candidate -> confirmed saved location. Denied/failed returns recoverable setup, preserving prior data. IP candidate cannot skip confirmation.
2. User update: validate complete new snapshot -> durable revision/generation -> cancel obsolete pending notifications/alarms -> install future current-generation events -> read back pending state -> publish effective status. UI does not show ready before completion. A failure is partial/blocked with retry, not hidden success.
3. Android delivery: receiver validates current generation, still-enabled event and due/expiry; atomically claims token -> sends acknowledged command to the single handler -> player owns token -> delivered. Fallback can win the claim only before audio has started; a late handler sees the lost claim and must not play. A Stop/cancel invalidates pending start as well as current playback.
4. iOS delivery: system notification owns short audio in background; foreground delegate suppresses system sound and routes through the app coordinator. Cancellation races at the exact moment of delivery cannot retroactively retract a system-owned sound; P02 documents the boundary.
5. Refresh on open/resume, locale changes, saved-location or calculation changes, audio readiness, permissions/capabilities, device clock/timezone changes and reboot recovery. Locale changes refresh pending notification text. No polling for location.
6. Drop missed events; do not deliver an event more than 60 seconds overdue. Mark horizon expiry explicitly. iOS queues at most 60 total; Android queues at most the next 30 days. Reboot restores future valid records, not immediate playback.
7. Remove location -> invalidate generation -> cancel its reminders -> delete location and related sensitive state -> select explicit replacement or disable. Clear-all also deletes secure snapshot/native ledger and cancels scheduled alerts, without touching Quran bookmarks or audio downloads unless requested separately.

## Migration and failure rules

Unknown method, missing catalogue entry or invalid timezone yields visible needsAttention; do not silently change religious conventions. Missing optional new fields use documented defaults. Failed secure-store reads do not overwrite ciphertext. Versioned invalidation discards only derived schedules/queues. Storage loss in private browsing or eviction returns to setup. Raw provider responses are not persisted.
