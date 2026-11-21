# Contract: Usage Events (the allowed-events list)

The only events the app sends. Defined in `lib/features/analytics/usage.dart`; anything not here
is never sent. Parameter values are strings or integers; booleans are sent as `"true"`/`"false"`.

## Automatic (from the analytics library)

`first_open`, `session_start`, `user_engagement`, `app_update`, `os_update`, `app_remove`
(Android), `page_view` is not used on the web (screens are sent as `screen_view`).

## Screens: `screen_view`

Parameter `screen_name` (and `screen_class` with the same value), one of:

| `screen_name` | Screen |
| --- | --- |
| `reader` | The mushaf / flowing reader (home) |
| `index` | Surahs, ajza and bookmarks |
| `search` | Search |
| `settings` | Settings |
| `prayer_times` | Prayer times |
| `khatma` | Khatma |
| `wird_list` | The wird list |
| `khatma_complete` | Khatma complete |
| `group_khatma` | A group khatma |
| `downloads` | Recitation downloads |
| `memorization_result` | A memorization session's result |
| `onboarding` | Onboarding |
| `mutashabihat` | Similar-wording sheet |
| `reciters` | Reciter sheet |

## Actions

| Event | Parameters (allowed values) | When |
| --- | --- | --- |
| `recitation_started` | `reciter` (catalogue id) | A recitation starts playing from a page or an ayah |
| `surah_download_started` | `reciter` (catalogue id) | A surah download is queued |
| `memorization_started` | `outcome` (`StartOutcome` name) | The reader starts a memorization session |
| `search` | none | The first search with results in a visit to the search screen |
| `bookmark_added` | none | A bookmark is added |
| `khatma_started` | none | A personal khatma starts |
| `wird_completed` | none | A wird or reading is marked read |
| `group_khatma_started` | `parts` (division, an integer) | The reader starts a group khatma |
| `group_khatma_joined` | none | The reader takes a part in a group khatma they did not start, for the first time |
| `prayer_alert_changed` | `prayer` (`PrayerKind` name), `on` | An alert or reminder switch changes |
| `announcement_opened` | `has_link` | A tapped announcement opens the app |
| `onboarding_completed` | none | Onboarding finishes |
| `setting_changed` | `setting`, `value` (below) | A setting changes |

## `setting_changed` values

| `setting` | `value` |
| --- | --- |
| `layout` | `ReadingLayout` name (`mushaf`, `flowing`) |
| `theme` | `ThemePref` name |
| `font_size` | integer 18–34 |
| `keep_screen_on` | `true` / `false` |
| `language` | `LanguagePref` name |
| `lettering` | `Lettering` name |
| `reciter` | catalogue id |
| `mistake_signal` | `MistakeSignal` name |
| `two_pages` | `true` / `false` |
| `announcements` | `true` / `false` |
| `prayer_method` | `PrayerMethod` name |
| `asr` | `AsrSetting` name |
| `high_latitude` | `HighLatitudeRule` name |
| `athan_sound` | athan catalogue id |
| `athan_length` | `AthanLength` name |

## Never sent (spec FR-004, FR-009)

Quran text; surah, ayah, page, juz or hizb numbers; search words; recognition results or audio;
bookmark notes; khatma titles, participant names, codes or links; places, coordinates, time zones
or prayer times; announcement text or links; any name, email, phone number or free text; the
advertising identifier or IDFV.

## Platforms

- Android and iOS: Firebase Analytics, collection enabled only in release builds.
- Web: the same events through the Firebase JS SDK, only on `get.mthani.app` in a release build.
