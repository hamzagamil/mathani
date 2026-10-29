# G01 single-handler alarm startup — implementation checkpoint

Status: **OPEN — no physical Android execution**. No API24/31+/33+/36, killed-process, lock-screen or Doze result is claimed.

The opt-in prototype registers an exact debug alarm carrying only opaque event ID/generation. Its receiver claims the encrypted native queue, attaches to audio_service's cached engine or creates that same engine, and dispatches through the existing media handler. A generated tone, explicit playback acknowledgement, timeout fallback, consumed tokens and acknowledged Stop exercise the route. The prototype receiver/tone remain in `src/debug`; Dart additionally requires `kDebugMode` and `PRAYER_ALARM_SPIKE=true`. Notification/alarm permission declarations are now shared with the production **short OS alert** route, which never starts a Flutter engine/media service. Production Android full scheduling remains disabled.

Run on a connected Android device after manually granting Notifications and Alarms & reminders:

```powershell
flutter test integration_test/prayer_alarm_spike_test.dart -d <device-id> --dart-define=PRAYER_ALARM_SPIKE=true
```

The foreground integration scenario checks current generation, app-audio ownership, due/start time, stable engine identity and player acknowledgement of Stop. Skipping due to unavailable grants/device is not a pass.

Before closing G01, test API24/31+/33+/36 foreground, background, locked and killed-process starts; measure foreground-promotion timing; inspect one service/notification; exercise duplicate/expired/cancelled commands, denied grants, failed startup, Stop during loading and fallback races. For cold/locked trials schedule a longer delay through the diagnostic channel, background/kill the process without force-stop, then inspect the protected token and actual audible result. Force-stop is a separate OS limitation, not a cold-process success case. Record device/OS/build, sanitized timing and observed audio/notification counts here. Do not enable production full mode until those results pass and the design gate is resolved.
