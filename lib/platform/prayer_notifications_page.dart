import 'dart:async';

import '../features/prayer_times/prayer_models.dart';
import '../features/prayer_times/prayer_services.dart';

/// Browser APIs are isolated so timer/lifecycle races can be tested without grants.
abstract interface class PrayerPagePort {
  bool get active;
  bool get secureContext;
  bool get notificationsSupported;
  String get notificationPermission;
  Stream<bool> get activityChanges;
  Future<void> requestNotificationPermission();

  /// Must be silent: only the shared app player owns custom audio.
  void Function()? showSilentNotification(ScheduledReminder event);
}

enum PrayerPageDeliveryStatus { playing, needsPlay, stopped, expired }

class PrayerPageDelivery {
  const PrayerPageDelivery(this.event, this.status);
  final ScheduledReminder event;
  final PrayerPageDeliveryStatus status;
}

/// Best-effort active-page delivery. No worker, durable queue or closed-page claim.
/// Constructing/querying this adapter does not prompt or start a timer/listener.
class PrayerPageNotifications implements PrayerNotificationAdapter {
  PrayerPageNotifications({
    required this.port,
    required this.audio,
    required this.onDelivery,
    required this.playFromUser,
    this.clock = prayerNow,
  });
  final PrayerPagePort port;
  final PrayerAudio audio;
  final Future<void> Function(ScheduledReminder event) playFromUser;
  final void Function(PrayerPageDelivery) onDelivery;
  final PrayerClock clock;
  final _pending = <String, ScheduledReminder>{};
  final _consumed = <String>{};
  final _notices = <String, void Function()>{};
  StreamSubscription<bool>? _activity;
  Timer? _timer;
  int _generation = -1, _epoch = 0;
  bool _disposed = false, _checking = false, _wasInactive = false;
  ScheduledReminder? _current, _needsPlay;
  String get notificationPermission =>
      port.notificationsSupported ? port.notificationPermission : 'unsupported';

  String _key(ScheduledReminder event) =>
      '${event.generation}:${event.eventId}';
  void _publish(ScheduledReminder event, PrayerPageDeliveryStatus status) {
    if (!_disposed) onDelivery(PrayerPageDelivery(event, status));
  }

  @override
  Future<ReminderCapability> capabilities() async {
    final available = !_disposed && port.active;
    final future =
        _pending.values
            .where((event) => event.dueAtUtc.isAfter(clock()))
            .toList()
          ..sort((a, b) => a.dueAtUtc.compareTo(b.dueAtUtc));
    return ReminderCapability(
      permissionStatus: 'notRequired',
      foregroundModes: available ? {AthanMode.opening, AthanMode.full} : {},
      backgroundModes: const {},
      reason: available ? 'webForegroundOnly' : 'webPageInactive',
      recoveryAction: available ? 'keepPageOpen' : 'openPage',
      scheduledThroughUtc: available && future.isNotEmpty
          ? future.last.dueAtUtc
          : null,
      appMustReopenByUtc: available && future.isNotEmpty
          ? future.last.dueAtUtc
          : null,
    );
  }

  @override
  Future<ReminderCapability> requestAuthorization() async {
    // Only an explicit UI action calls this method; notification denial does not
    // revoke in-page audio. Constructors and capabilities never request permission.
    if (!_disposed &&
        port.active &&
        port.secureContext &&
        port.notificationsSupported &&
        port.notificationPermission == 'default') {
      try {
        await port.requestNotificationPermission();
      } on Object {
        /* optional */
      }
    }
    return capabilities();
  }

  @override
  Future<ReminderCapability> replace(
    PrayerState state,
    List<ScheduledReminder> events,
  ) async {
    if (_disposed || state.generation < _generation) {
      throw const PrayerException(PrayerFailure.needsAttention);
    }
    final now = clock(), ids = <String>{};
    final next = <String, ScheduledReminder>{};
    for (final event in events) {
      final enabled = event.kind == PrayerKind.qiyam
          ? state.reminders.qiyamEnabled
          : state.reminders.enabledPrayers.contains(event.kind);
      if (!ids.add(event.eventId) ||
          event.generation != state.generation ||
          event.locationId != state.activeLocationId ||
          !enabled ||
          event.kind == PrayerKind.sunrise ||
          event.deliveryMechanism != 'inPage' ||
          event.state != ReminderState.pending ||
          event.consumed ||
          event.claimOwner != null ||
          event.expiresAtUtc.isBefore(event.dueAtUtc) ||
          event.expiresAtUtc.difference(event.dueAtUtc) >
              const Duration(seconds: 60) ||
          event.dueAtUtc.difference(now) > const Duration(days: 30) ||
          (event.kind == PrayerKind.qiyam && event.mode != AthanMode.opening)) {
        throw const PrayerException(PrayerFailure.needsAttention);
      }
      if (event.dueAtUtc.isAfter(now) && !_consumed.contains(_key(event))) {
        next[event.eventId] = event;
      }
    }
    if (events.length > 192) {
      throw const PrayerException(PrayerFailure.schedulePartial);
    }
    if (state.generation == _generation &&
        _consumed.length + next.length > 192) {
      throw const PrayerException(PrayerFailure.schedulePartial);
    }
    final changing = state.generation != _generation;
    _generation = state.generation;
    if (changing) {
      _pending.clear();
      _consumed.clear();
      await stop();
      if (_generation != state.generation || _disposed) return capabilities();
    }
    if (!changing &&
        ((_current != null && !ids.contains(_current!.eventId)) ||
            (_needsPlay != null && !ids.contains(_needsPlay!.eventId)))) {
      await stop();
    }
    _pending
      ..clear()
      ..addAll(next);
    _wasInactive = !port.active;
    _activity ??= port.activityChanges.listen((active) {
      if (!active) {
        _wasInactive = true;
        unawaited(stop());
      } else {
        unawaited(checkDue());
      }
    });
    _arm();
    return capabilities();
  }

  void _arm() {
    _timer?.cancel();
    _timer = null;
    if (!_disposed && _pending.isNotEmpty) {
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(checkDue()),
      );
    }
  }

  Future<void> checkDue() async {
    if (_disposed || _checking) return;
    if (!port.active) {
      _wasInactive = true;
      return;
    }
    _checking = true;
    try {
      final now = clock();
      final due =
          _pending.values
              .where((event) => !event.dueAtUtc.isAfter(now))
              .toList()
            ..sort((a, b) => a.dueAtUtc.compareTo(b.dueAtUtc));
      final missedWhileInactive = _wasInactive;
      _wasInactive = false;
      for (final event in due) {
        if (_disposed || event.generation != _generation || !port.active) break;
        _pending.remove(event.eventId);
        if (!_consumed.add(_key(event))) continue;
        if (missedWhileInactive || now.isAfter(event.expiresAtUtc)) {
          _publish(event, PrayerPageDeliveryStatus.expired);
          continue;
        }
        if (port.secureContext &&
            port.notificationsSupported &&
            notificationPermission == 'granted') {
          try {
            final close = port.showSilentNotification(event);
            if (close != null) _notices[event.eventId] = close;
          } on Object {
            /* Unsupported constructors must not block page audio. */
          }
        }
        await _play(event);
      }
    } finally {
      _checking = false;
      _arm();
    }
  }

  Future<void> _play(ScheduledReminder event, {bool explicit = false}) async {
    if (_disposed ||
        !port.active ||
        event.generation != _generation ||
        clock().isAfter(event.expiresAtUtc)) {
      return;
    }
    final expectedEpoch = _epoch + 1;
    await stop();
    if (_epoch != expectedEpoch ||
        _disposed ||
        !port.active ||
        event.generation != _generation ||
        clock().isAfter(event.expiresAtUtc)) {
      return;
    }
    final epoch = _epoch;
    _current = event;
    try {
      if (explicit) {
        await playFromUser(event);
      } else {
        await audio.play(event);
      }
      if (epoch == _epoch && !_disposed) {
        _publish(event, PrayerPageDeliveryStatus.playing);
      }
    } on Object {
      if (epoch == _epoch && !_disposed) {
        _current = null;
        _needsPlay = event;
        _publish(event, PrayerPageDeliveryStatus.needsPlay);
      }
    }
  }

  /// Must be invoked directly by the visible Play action after autoplay rejection.
  Future<void> playExplicitly(String eventId) async {
    final event = _needsPlay;
    if (event == null || event.eventId != eventId) return;
    _needsPlay = null;
    await _play(event, explicit: true);
  }

  Future<void> stop() async {
    ++_epoch;
    final current = _current;
    _current = null;
    _needsPlay = null;
    if (current != null) {
      await audio.stop();
      _publish(current, PrayerPageDeliveryStatus.stopped);
    }
  }

  void _closeNotices() {
    for (final close in _notices.values) {
      try {
        close();
      } on Object {
        /* best effort */
      }
    }
    _notices.clear();
  }

  @override
  Future<void> cancelLocation(String locationId) async {
    _pending.removeWhere((_, event) => event.locationId == locationId);
    if (_current?.locationId == locationId ||
        _needsPlay?.locationId == locationId) {
      await stop();
    }
    _closeNotices();
    _arm();
  }

  @override
  Future<void> cancelAll() async {
    _pending.clear();
    _closeNotices();
    _arm();
    await stop();
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    await _activity?.cancel();
    await cancelAll();
  }
}
