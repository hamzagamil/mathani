import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:timezone/timezone.dart' as tz;

import 'prayer_calculator.dart';
import 'prayer_models.dart';
import 'prayer_services.dart';
import 'prayer_time_zones.dart';

enum PrayerReminderTarget { android, ios, web }

enum PrayerScheduleStatus { disabled, blocked, partial, scheduled }

class PrayerScheduleResult {
  PrayerScheduleResult(
    this.status, {
    this.failure,
    this.requiredAcknowledgement,
    this.effectiveMode,
    List<ScheduledReminder> events = const [],
    this.scheduledThroughUtc,
    this.appMustReopenByUtc,
  }) : events = List.unmodifiable(events);
  final PrayerScheduleStatus status;
  final PrayerFailure? failure;
  final String? requiredAcknowledgement;
  final AthanMode? effectiveMode;
  final List<ScheduledReminder> events;
  final DateTime? scheduledThroughUtc, appMustReopenByUtc;
}

/// Policy and serialized reconciliation of an already-persisted intent snapshot.
/// Concrete adapters must read back their real pending queue before reporting
/// scheduledThroughUtc. Construction does no plugin, permission or audio work.
class PrayerReminderScheduler {
  PrayerReminderScheduler({
    required this.adapter,
    required this.calculator,
    required this.target,
    this.clock = prayerNow,
    this.androidHeadlessVerified = false,
  });
  final PrayerNotificationAdapter adapter;
  final PrayerCalculator calculator;
  final PrayerReminderTarget target;
  final PrayerClock clock;
  // Remains false in production until G01 is established on the required devices.
  final bool androidHeadlessVerified;
  Future<void> _tail = Future.value();
  int _generation = -1;

  Future<PrayerScheduleResult> reconcile(
    PrayerState state, {
    AthanRecording? recording,
    bool openingReady = false,
    bool fullReady = false,
  }) {
    final result = _tail.then((_) async {
      final result = await _reconcile(
        state,
        recording,
        openingReady,
        fullReady,
      );
      if (state.generation == _generation &&
          (result.status == PrayerScheduleStatus.disabled ||
              result.status == PrayerScheduleStatus.blocked)) {
        try {
          await adapter.cancelAll();
        } on Object {
          return PrayerScheduleResult(
            PrayerScheduleStatus.partial,
            failure: PrayerFailure.schedulePartial,
          );
        }
      }
      return result;
    });
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<PrayerScheduleResult> _reconcile(
    PrayerState state,
    AthanRecording? recording,
    bool openingReady,
    bool fullReady,
  ) async {
    if (state.generation < _generation) {
      return PrayerScheduleResult(
        PrayerScheduleStatus.blocked,
        failure: PrayerFailure.needsAttention,
      );
    }
    _generation = state.generation;
    try {
      // replace() cancels obsolete generations while preserving delivery claims
      // for the same generation; never clear consumed tokens during a refill.
      if (!state.reminders.anyEnabled) {
        return PrayerScheduleResult(PrayerScheduleStatus.disabled);
      }
      final place = state.activeLocation;
      if (place == null) {
        return PrayerScheduleResult(
          PrayerScheduleStatus.blocked,
          failure: PrayerFailure.needsAttention,
        );
      }
      final capability = await adapter.capabilities();
      if (capability.permissionStatus == 'unsupported') {
        return PrayerScheduleResult(
          PrayerScheduleStatus.blocked,
          failure: PrayerFailure.modeUnsupported,
        );
      }
      if (!['granted', 'authorized'].contains(capability.permissionStatus) &&
          !(target == PrayerReminderTarget.web &&
              capability.permissionStatus == 'notRequired')) {
        return PrayerScheduleResult(
          PrayerScheduleStatus.blocked,
          failure: PrayerFailure.notificationsDenied,
        );
      }
      if (capability.channelRestricted == true) {
        return PrayerScheduleResult(
          PrayerScheduleStatus.blocked,
          failure: PrayerFailure.notificationsDenied,
        );
      }
      var mode = state.reminders.requestedMode;
      final hasDaily = state.reminders.enabledPrayers.isNotEmpty;
      var deliverDaily = hasDaily;
      String? pendingAcknowledgement;
      final reviewed =
          recording != null &&
          recording.id == state.reminders.selectedAthanId &&
          recording.completeRecordingReviewed &&
          recording.fourTakbirsReviewed;
      final nativeDefault =
          hasDaily &&
          target != PrayerReminderTarget.web &&
          (!reviewed ||
              (!openingReady &&
                  !(state.reminders.requestedMode == AthanMode.full &&
                      fullReady &&
                      target == PrayerReminderTarget.android &&
                      androidHeadlessVerified &&
                      capability.exactAlarmAccess)));
      if (nativeDefault &&
          state.reminders.acknowledgedFallbacks['system_notification'] != 1) {
        if (state.reminders.qiyamEnabled) {
          deliverDaily = false;
          pendingAcknowledgement = 'system_notification';
        } else {
          return PrayerScheduleResult(
            PrayerScheduleStatus.blocked,
            failure: PrayerFailure.audioUnavailable,
            requiredAcknowledgement: 'system_notification',
          );
        }
      }
      if (!hasDaily || nativeDefault) mode = AthanMode.opening;
      var mechanism = target == PrayerReminderTarget.web ? 'inPage' : 'system';
      final supported = target == PrayerReminderTarget.web
          ? capability.foregroundModes
          : capability.backgroundModes;
      bool acknowledged(String key) =>
          state.reminders.acknowledgedFallbacks[key] == 1;
      PrayerScheduleResult disclosure(String key, PrayerFailure reason) =>
          PrayerScheduleResult(
            PrayerScheduleStatus.blocked,
            failure: reason,
            requiredAcknowledgement: key,
          );
      final fullSupported = target == PrayerReminderTarget.web
          ? supported.contains(AthanMode.full)
          : target == PrayerReminderTarget.android &&
                androidHeadlessVerified &&
                capability.exactAlarmAccess &&
                supported.contains(AthanMode.full);
      if (mode == AthanMode.full && !fullSupported) {
        final key = switch (target) {
          PrayerReminderTarget.ios => 'ios_background_full',
          PrayerReminderTarget.android => 'android_background_full',
          PrayerReminderTarget.web => 'web_audio_unavailable',
        };
        if (!acknowledged(key)) {
          return disclosure(key, PrayerFailure.modeUnsupported);
        }
        mode = AthanMode.opening;
      }
      if (!supported.contains(mode)) {
        return PrayerScheduleResult(
          PrayerScheduleStatus.blocked,
          failure: PrayerFailure.modeUnsupported,
        );
      }
      if (target == PrayerReminderTarget.android &&
          !capability.exactAlarmAccess) {
        if (!acknowledged('android_exact_alarm')) {
          return disclosure(
            'android_exact_alarm',
            PrayerFailure.exactAlarmDenied,
          );
        }
        mode = AthanMode.opening;
        mechanism = 'inexactSystem';
      }
      if (hasDaily &&
          !nativeDefault &&
          (recording == null ||
              recording.id != state.reminders.selectedAthanId ||
              !recording.completeRecordingReviewed)) {
        return PrayerScheduleResult(
          PrayerScheduleStatus.blocked,
          failure: PrayerFailure.audioUnavailable,
        );
      }
      if (hasDaily && !nativeDefault && mode == AthanMode.full && !fullReady) {
        if (!acknowledged('full_audio_unavailable')) {
          return disclosure(
            'full_audio_unavailable',
            PrayerFailure.audioUnavailable,
          );
        }
        mode = AthanMode.opening;
      }
      if (hasDaily &&
          !nativeDefault &&
          mode == AthanMode.opening &&
          (!openingReady ||
              recording?.fourTakbirsReviewed != true ||
              recording!.openingDurationMs <= 0 ||
              (target == PrayerReminderTarget.ios &&
                  !recording.iosShortEligible))) {
        return PrayerScheduleResult(
          PrayerScheduleStatus.blocked,
          failure: PrayerFailure.audioUnavailable,
        );
      }
      if (nativeDefault) {
        mechanism = mechanism == 'inexactSystem'
            ? 'inexactSystemDefault'
            : 'systemDefault';
      }
      if (mode == AthanMode.full && target == PrayerReminderTarget.android) {
        mechanism = 'appAudio';
      }
      final now = clock().toUtc(),
          end = clock().toUtc().add(const Duration(days: 30));
      final local = tz.TZDateTime.from(now, prayerTimeZone(place.timezoneId));
      final events = <ScheduledReminder>[];
      var unavailable = 0;
      // After midnight, the next Qiyam can belong to yesterday's Maghrib.
      for (var offset = -1; offset <= 31; offset++) {
        final schedule = calculator.schedule(
          place,
          DateTime.utc(local.year, local.month, local.day + offset),
        );
        for (final event in schedule.events) {
          if (!deliverDaily ||
              !state.reminders.enabledPrayers.contains(event.kind)) {
            continue;
          }
          if (capability.restrictedPrayers.contains(event.kind)) {
            unavailable++;
            continue;
          }
          final due = event.dueAtUtc;
          if (due == null) {
            unavailable++;
            continue;
          }
          if (!due.isAfter(now) || due.isAfter(end)) continue;
          final token = sha256
              .convert(
                utf8.encode(
                  '${place.id}|${schedule.localDate.toIso8601String()}|${event.kind.name}|${state.generation}',
                ),
              )
              .toString();
          events.add(
            ScheduledReminder(
              eventId: token,
              locationId: place.id,
              generation: state.generation,
              kind: event.kind,
              dueAtUtc: due.toUtc(),
              expiresAtUtc: due.toUtc().add(const Duration(seconds: 60)),
              audioId: nativeDefault ? 'system_default' : recording!.id,
              mode: mode,
              deliveryMechanism: mechanism,
            ),
          );
        }
        if (state.reminders.qiyamEnabled) {
          final due = capability.restrictedPrayers.contains(PrayerKind.qiyam)
              ? null
              : schedule.qiyamUtc;
          if (due == null) {
            unavailable++;
          } else if (due.isAfter(now) && !due.isAfter(end)) {
            events.add(
              ScheduledReminder(
                eventId: sha256
                    .convert(
                      utf8.encode(
                        '${place.id}|${schedule.localDate.toIso8601String()}|qiyam|${state.generation}',
                      ),
                    )
                    .toString(),
                locationId: place.id,
                generation: state.generation,
                kind: PrayerKind.qiyam,
                dueAtUtc: due,
                expiresAtUtc: due.add(const Duration(seconds: 60)),
                audioId: 'qiyam_tone',
                mode: AthanMode.opening,
                deliveryMechanism: target == PrayerReminderTarget.web
                    ? 'inPage'
                    : target == PrayerReminderTarget.android &&
                          !capability.exactAlarmAccess
                    ? 'inexactSystem'
                    : 'system',
              ),
            );
          }
        }
      }
      events.sort((a, b) => a.dueAtUtc.compareTo(b.dueAtUtc));
      final bounded = target == PrayerReminderTarget.ios
          ? events.take(60).toList()
          : events;
      if (bounded.isEmpty) {
        return PrayerScheduleResult(
          PrayerScheduleStatus.blocked,
          failure: capability.restrictedPrayers.isNotEmpty
              ? PrayerFailure.notificationsDenied
              : PrayerFailure.calculationUnavailable,
        );
      }
      final installed = await adapter.replace(state, bounded);
      final through = installed.scheduledThroughUtc;
      final matches =
          through == bounded.last.dueAtUtc &&
          [
            'granted',
            'authorized',
            'notRequired',
          ].contains(installed.permissionStatus);
      final partial =
          !matches || unavailable > 0 || pendingAcknowledgement != null;
      return PrayerScheduleResult(
        partial ? PrayerScheduleStatus.partial : PrayerScheduleStatus.scheduled,
        failure: pendingAcknowledgement != null
            ? PrayerFailure.audioUnavailable
            : partial
            ? PrayerFailure.schedulePartial
            : null,
        requiredAcknowledgement: pendingAcknowledgement,
        effectiveMode: mode,
        events: bounded,
        scheduledThroughUtc: through,
        appMustReopenByUtc: through?.subtract(const Duration(hours: 12)),
      );
    } on PrayerException catch (error) {
      return PrayerScheduleResult(
        PrayerScheduleStatus.partial,
        failure: error.reason,
      );
    } on Object {
      return PrayerScheduleResult(
        PrayerScheduleStatus.partial,
        failure: PrayerFailure.schedulePartial,
      );
    }
  }

  /// Final native atomic claims remain in PrayerAlarmStore. This additional check
  /// protects app-owned delivery before handing an event to an audio coordinator.
  static bool isDeliverable(
    ScheduledReminder event,
    PrayerState state,
    DateTime now,
  ) =>
      event.generation == state.generation &&
      event.locationId == state.activeLocationId &&
      state.reminders.enabledPrayers.contains(event.kind) &&
      dailyPrayers.contains(event.kind) &&
      !event.consumed &&
      (event.state == ReminderState.pending ||
          event.state == ReminderState.claimed) &&
      !now.isBefore(event.dueAtUtc) &&
      !now.isAfter(event.expiresAtUtc) &&
      now.difference(event.dueAtUtc) <= const Duration(seconds: 60);
}
