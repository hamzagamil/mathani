# Contract: Announcements

## What the admin sends (Firebase console › Messaging › New campaign › Notifications)

| Field | Value |
| --- | --- |
| Notification title | Required |
| Notification text | Required |
| Target | Topic `all`, or `lang_ar` / `lang_en` for one language |
| Android notification channel | `announcements_v1` (also the default, so it can be left empty) |
| Custom data (optional) | key `link`, value an `https://mthani.app/…`, `https://www.mthani.app/…` or `https://get.mthani.app/…` link |
| Expires | The admin's choice (spec edge case "Old messages") |

Sending to a single device token or to any other topic is not used.

## App behaviour

- Switch on (default) → after the first frame on Android/iOS: initialise Firebase, enable
  auto-init, subscribe to `all` and `lang_<language>`. Language change → unsubscribe old,
  subscribe new.
- Switch off → unsubscribe from the topics last subscribed (kept in the `announcement_topics`
  preference, so this also works on a later launch). Firebase is never started on an install
  where the switch was off from the first launch.
- Switching on asks for notification permission only if it was never asked.
- Foreground: Android shows the message on `announcements_v1`; iOS shows banner and list, no
  sound.
- Tap → `data.link` if it passes the host check is handed to the app's link stream; otherwise
  the app opens normally.
- Any Firebase failure (no network, no configuration) is caught and logged in debug only; the
  app is unaffected.
- Every reader change notifies; the controller acts only when the setting or the language
  changed.

## Platform interface

```text
abstract interface class AnnouncementsPlatform {
  Future<bool> start();                         // false when unavailable
  Future<void> subscribe(Set<String> topics);
  Future<void> unsubscribe(Set<String> topics);
  Future<void> requestPermission();
  Stream<String> get openedLinks;               // data.link of tapped messages, incl. launch
}
```

Web, desktop and tests use a no-op implementation.
