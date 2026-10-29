# Contract: Prayer UI, Audio and Reminder Platforms

**Feature**: [../spec.md](../spec.md) | **Model**: [../data-model.md](../data-model.md)

## User surface

Prayer Times is a labelled action in the existing Settings screen, reached from the reader toolbar. It pushes a normal screen, leaving the reader's page/recitation state intact. Back returns to the reader. No new mandatory onboarding step or startup permission prompt.

The schedule header shows viewed place, local date/time zone, method, madhhab and adjustment. Daily rows show six events, unavailable/adjusted labels, and five-prayer next/countdown. A visible badge identifies the active reminder location. A place picker supports add, rename, view, activate and delete; viewing is separate from the explicit Use for reminders action.

Setup offers Detect my location and Search city. After device denial/failure, offer Try approximate location with connection-based disclosure. Before device place resolution, explain coordinate sharing with Mathani/Cloudflare and GeoNames. IP results always have Confirm and Change actions and an Approximate badge. No silent overwrite or repeated permission loop.

Calculation settings provide all five specified named methods, four madhhab labels and the two explicit high-latitude rules. Explain the Asr grouping and show suggested defaults as suggestions. Loading errors retain the current valid selection.

Reminder settings show five switches, recitation catalogue with previews and attribution, requested full/opening mode, effective capability and offline-readiness status. Qiyam is an independent switch with the upcoming local date/time and last-third explanation. Sunrise has no athan toggle. All notifications start disabled. Show scheduled-through and a reopen reminder before the finite horizon expires; no indefinite-ready badge.

Arabic/English, inherited light/dark themes, RTL, portrait safe areas, font scaling, VoiceOver/TalkBack, 44pt/48dp touch targets and accessible state announcements are mandatory. The existing web PhoneColumn remains. App-controlled audio has a prominent Stop action; no automatic Quran resume.

## Capability matrix

| Platform/state | Opening mode | Full mode | Stop and overlap contract |
| --- | --- | --- | --- |
| iOS foreground | App player | App player | Shared coordinator pauses Quran and stops previews; suppress system notification sound; Stop works. |
| iOS background/locked/not running | Complete four-takbir CAF <30s if eligible | Unavailable as automatic playback; explicit opening/default fallback plus open-to-play-full action | OS owns short sound. App Stop and guaranteed Quran pause cannot be promised; show P02 disclosure. |
| Android foreground | Single audio handler | Single audio handler | One owner, visible Stop, Quran paused. |
| Android background/locked/process absent | Exact alarm -> same handler after G01; short system fallback if needed | Same handler only after cold-process/permission validation | Atomically claimed token, acknowledged start and no second player. Force-stop/power/system restrictions remain visible. |
| Android exact permission denied | Disclosed approximate short notification if accepted | Disabled for precise scheduled playback | Never represent approximate delivery as precise. |
| Web active and executing | In-page player if browser permits | In-page player if browser permits | User activation may be required; rejected playback presents Play. |
| Web closed/suspended | No precise automatic custom sound promise | Unsupported | Show limitation and mobile links; no fake background timer. |

Changes in capability preserve requested choices but update effective states. A fallback must be disclosed before it is used; if not acknowledged, keep that reminder blocked until the user chooses an available alternative. Qiyam is always a short reminder tone.

The native short-alert increment supports a standard system sound only under explicit `system_notification: 1` acknowledgement if daily recitation audio is unavailable (P06). Label it as a standard sound, not opening takbirs. Qiyam can still schedule when an enabled daily recitation is blocked, and a blocked per-kind channel must not suppress other deliverable kinds. Native full modes remain unadvertised. Android posts short sounds directly from the token-validating receiver; it does not start the headless media route. iOS installs future requests only; OS presentation has no application pre-delivery expiry hook (P07), so its strict-overdue-filter limitation must be disclosed rather than inferred from Android token tests.

## Application interfaces

These are behavioural contracts, not full implementation bodies.

- `PrayerCalculator.schedule(location, localDate, conventionVersion)` returns a schedule with UTC instants/statuses and no network access; results are deterministic for identical inputs/versions.
- `PrayerRepository.load/save/delete` operates on the dedicated encrypted snapshot, serializes writes and preserves unrelated user data. Store errors are typed and recoverable.
- `PrayerController` distinguishes viewedLocationId from activeLocationId; exposes setup, schedule, effective reminder status and actions. It never publishes unconfirmed IP results as active.
- `PrayerReminderScheduler.capabilities()` returns observable support/reasons without prompting. `requestAuthorization()` is only called from explicit enablement. `reconcile(snapshot)` returns actual queued horizon and per-event errors. `cancelLocation`/`cancelAll` are idempotent.
- `AthanPlayer.preview/play/stop` owns app-controlled athan. It shares ownership with the existing recitation handler, not a second audio_service. Claiming athan pauses Quran and memorization listening before audio starts; automatic resume of either is forbidden.
- Platform bridge methods under `app.mathani/prayer_notifications`: capability query, exact-access/settings request, replace-generation, cancel, list-pending and stop. Bridge plugin registration must work without MainActivity. Android alarm commands contain only event token/generation and asset ID, not user coordinates.
- Android media command `playAthan` includes eventId, generation, assetId and duration mode. The single handler acknowledges started/rejected/failed with eventId. A stale, expired, disabled, cancelled or already-consumed command is a no-op. Stop also prevents a late queued command from starting.

## Platform lifecycle

Use flutter_local_notifications for short system alerts, iOS foreground presentation/actions and pending request management. Android full mode additionally uses AlarmManager exact PendingIntent receiver and a media-browser/controller bridge into the existing service. Do not assume notification-delivery callbacks execute Dart.

On Android, the custom alarm queue owns scheduling for both full playback and its short fallback, rather than scheduling a second independent plugin notification for the same event. The receiver posts its fallback only after winning the delivery claim. Keep notification title/location presentation in the native protected queue (Keystore-backed AES-GCM via platform APIs), not in the plugin's plaintext scheduled-notification preferences. This derived queue is replaceable from the encrypted source snapshot; it is not another source of user settings. Do not depend on undocumented flutter_secure_storage file/key formats from Kotlin. iOS pending requests are owned by the OS notification center. Android recovery waits for first unlock when protected data is unavailable; retry on user unlock and skip expired events.

Reconciliation uses future absolute instants and stable app-owned IDs, never device-local formatted times. iOS maintains the next 60 events total and refills on app activity; Android maintains 30 days and restores future alarms on boot/time changes. Show finite expiry honestly. App-owned event generation prevents stale Android receivers after changes; iOS pending OS requests must be actively cancelled/replaced and verified.

Android requires coarse/fine foreground location declarations, POST_NOTIFICATIONS where applicable, SCHEDULE_EXACT_ALARM special access, RECEIVE_BOOT_COMPLETED and existing mediaPlayback service permissions. No background location, full-screen intent or automatic media start from BOOT_COMPLETED. Exact permission revocation cancels/rebuilds effective support. Preserve user channel decisions; use a bounded channel per short recording variant and a silent media-service notification during app-controlled playback.

iOS adds localized when-in-use location explanation and notification authorization. No always-location request or new permanent audio loop. Use supported CAF clips in Library/Sounds; register delegates without breaking existing Flutter/audio plugins. Foreground notifications suppress native sound when the coordinator plays audio. Tapping a background alert may open the app and offer full playback; it does not automatically assert consent to ignore system sound settings.

Web detection requires secure context and geolocation=(self) in Permissions-Policy, replacing the current geolocation=(). API calls use the approved Mathani origin; service worker never caches /api/prayer-* responses. Browser notifications are optional observable capabilities, not reliable closed-tab schedules.

## Error states

Expose typed states: locationDenied, locationUnavailable, timezoneUnresolved, providerUnavailable, offline, calculationUnavailable, conventionOutOfRange, audioUnavailable, notificationsDenied, exactAlarmDenied, modeUnsupported, secureStorageUnavailable, schedulePartial and horizonExpired. Each provides a localized next action. No error erases valid saved data. Permissions and sound/channel settings are never silently bypassed.
