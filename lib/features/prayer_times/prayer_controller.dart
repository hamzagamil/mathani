import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import 'prayer_calculator.dart';
import 'prayer_models.dart';
import 'prayer_repository.dart';
import 'prayer_reminder_scheduler.dart';
import 'prayer_services.dart';
import 'prayer_time_zones.dart';

typedef PrayerAudioReadiness = ({bool openingReady, bool fullReady});

class PrayerController extends ChangeNotifier {
  PrayerController({
    required this.repository,
    required this.locationClient,
    required this.calculator,
    this.clock = prayerNow,
    this.notifications = const NoPrayerNotifications(),
    PrayerReminderTarget? reminderTarget,
    List<AthanRecording> recordings = const [],
    this.audioReadiness,
    this.reminderAudio,
  }) : reminderTarget =
           reminderTarget ??
           (kIsWeb
               ? PrayerReminderTarget.web
               : defaultTargetPlatform == TargetPlatform.iOS
               ? PrayerReminderTarget.ios
               : PrayerReminderTarget.android),
       recordings = List.unmodifiable(recordings);
  final PrayerRepository repository;
  final PrayerLocationClient locationClient;
  final PrayerCalculator calculator;
  final PrayerClock clock;
  final PrayerNotificationAdapter notifications;
  final PrayerReminderTarget reminderTarget;
  final List<AthanRecording> recordings;
  final Future<PrayerAudioReadiness> Function(AthanRecording recording)?
  audioReadiness;
  final PrayerAudio? reminderAudio;
  late final _reminderScheduler = PrayerReminderScheduler(
    adapter: notifications,
    calculator: calculator,
    target: reminderTarget,
    clock: clock,
  );
  ReminderCapability reminderCapability = const ReminderCapability(
    permissionStatus: 'unsupported',
  );
  PrayerScheduleResult reminderStatus = PrayerScheduleResult(
    PrayerScheduleStatus.disabled,
  );
  PrayerAudioReadiness reminderAudioReadiness = (
    openingReady: false,
    fullReady: false,
  );
  AthanRecording? get selectedAthan => recordings
      .where((r) => r.id == state.reminders.selectedAthanId)
      .firstOrNull;
  bool previewingAthan = false;
  DateTime? _cachedQiyam, _qiyamCheckedAt;
  String? viewedLocationId;
  SavedLocation? get viewedLocation {
    for (final location in state.locations) {
      if (location.id == viewedLocationId) return location;
    }
    return state.activeLocation ?? state.locations.firstOrNull;
  }

  DailyPrayerSchedule? activeSchedule;
  PrayerState state = PrayerState();
  Map<String, dynamic>? candidate;
  List<Map<String, dynamic>> results = [];
  PrayerFailure? failure;
  bool busy = false, initialized = false, _disposed = false;
  bool searching = false;
  int _searchVersion = 0;
  DailyPrayerSchedule? schedule;
  PrayerEvent? _next;
  bool get sessionOnly => repository.sessionOnly;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    searching = false;
    failure = null;
    _notify();
    try {
      await action();
    } on PrayerException catch (e) {
      failure = e.reason;
    } on FormatException {
      failure = PrayerFailure.needsAttention;
    } on Object {
      failure = PrayerFailure.providerUnavailable;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> initialize() => _run(() async {
    state = await repository.load();
    viewedLocationId =
        state.activeLocationId ?? state.locations.firstOrNull?.id;
    initialized = true;
    refresh();
    await _refreshReminders();
  });
  void refresh() {
    _cachedQiyam = null;
    _qiyamCheckedAt = null;
    final location = viewedLocation;
    if (location == null) {
      schedule = null;
      _next = null;
      activeSchedule = null;
      _notify();
      return;
    }
    final local = tz.TZDateTime.from(
      clock(),
      prayerTimeZone(location.timezoneId),
    );
    schedule = calculator.schedule(
      location,
      DateTime.utc(local.year, local.month, local.day),
    );
    _next = calculator.nextPrayer(location, clock());
    final active = state.activeLocation;
    if (active == null) {
      activeSchedule = null;
    } else if (active.id == location.id) {
      activeSchedule = schedule;
    } else {
      final activeLocal = tz.TZDateTime.from(
        clock(),
        prayerTimeZone(active.timezoneId),
      );
      activeSchedule = calculator.schedule(
        active,
        DateTime.utc(activeLocal.year, activeLocal.month, activeLocal.day),
      );
    }
    _notify();
  }

  PrayerEvent? get nextPrayer {
    if (viewedLocation == null) return null;
    if (_next?.dueAtUtc?.isAfter(clock()) != true) {
      _next = calculator.nextPrayer(viewedLocation!, clock());
    }
    return _next;
  }

  Future<void> approximate(String language) => _run(() async {
    locationClient.cancelSearch();
    _searchVersion++;
    results = [];
    candidate = await locationClient.approximate(language);
    candidate = {
      ...candidate!,
      'source': 'ip',
      'approximate': true,
      'requiresConfirmation': true,
    };
  });
  Future<void> detect(String language) => _run(() async {
    locationClient.cancelSearch();
    _searchVersion++;
    results = [];
    candidate = await locationClient.detect(language);
  });
  Future<void> search(String q, String language) async {
    final token = ++_searchVersion;
    candidate = null;
    failure = null;
    results = [];
    searching = q.trim().length >= 2;
    _notify();
    try {
      final found = await locationClient.search(q, language);
      if (token == _searchVersion && !_disposed) {
        results = found;
        searching = false;
        _notify();
      }
    } on PrayerException catch (e) {
      if (token == _searchVersion && !_disposed) {
        failure = e.reason;
        searching = false;
        _notify();
      }
    } on Object {
      if (token == _searchVersion && !_disposed) {
        failure = PrayerFailure.providerUnavailable;
        searching = false;
        _notify();
      }
    }
  }

  Future<void> choose(Map<String, dynamic> place, {String language = 'en'}) =>
      _run(() async {
        locationClient.cancelSearch();
        _searchVersion++;
        candidate = place['timezoneId'] == null
            ? await locationClient.resolve(place, language)
            : Map.of(place);
        results = [];
      });
  void discardCandidate() {
    candidate = null;
    failure = null;
    _notify();
  }

  Future<void> confirmCandidate({String? label}) => _run(() async {
    final c = candidate;
    if (c == null || !initialized) {
      throw const PrayerException(PrayerFailure.needsAttention);
    }
    final city = c['city'] as String? ?? '';
    final country = c['countryCode'] as String? ?? '';
    final source = LocationSource.values.firstWhere(
      (v) => v.name == c['source'],
    );
    final id = base64UrlEncode(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final location = SavedLocation(
      id: id,
      label:
          label ??
          (city.isNotEmpty
              ? city
              : [
                  (c['latitude'] as num).toStringAsFixed(3),
                  (c['longitude'] as num).toStringAsFixed(3),
                ].join(', ')),
      city: city,
      region: c['region'] as String? ?? '',
      countryCode: country,
      latitude: (c['latitude'] as num).toDouble(),
      longitude: (c['longitude'] as num).toDouble(),
      timezoneId: c['timezoneId'] as String,
      source: source,
      approximate: c['approximate'] as bool? ?? false,
      accuracyMeters: (c['accuracyMeters'] as num?)?.toDouble(),
      geonamesId: c['placeId'] as String?,
      confirmedAtUtc: clock(),
      calculation: CalculationPreferences(
        method: CalculationPreferences.suggestion(country),
      ),
    );
    final updated = PrayerState(
      revision: state.revision + 1,
      generation: state.generation + (state.locations.isEmpty ? 1 : 0),
      locations: [...state.locations, location],
      activeLocationId: state.locations.isEmpty ? id : state.activeLocationId,
      reminders: state.reminders,
    );
    await repository.save(updated);
    if (_disposed) return;
    state = updated;
    viewedLocationId = id;
    candidate = null;
    refresh();
  });
  SavedLocation _location(String id) => state.locations.firstWhere(
    (p) => p.id == id,
    orElse: () => throw const FormatException('Unknown saved location'),
  );
  PrayerState _updated({
    List<SavedLocation>? locations,
    String? activeId,
    bool clearActive = false,
    ReminderPreferences? reminders,
    bool invalidate = false,
  }) => PrayerState(
    revision: state.revision + 1,
    generation: state.generation + (invalidate ? 1 : 0),
    calculationVersion: state.calculationVersion,
    locations: locations ?? state.locations,
    activeLocationId: clearActive ? null : activeId ?? state.activeLocationId,
    reminders: reminders ?? state.reminders,
  );
  Future<void> _commit(PrayerState updated, {bool cancelQueue = false}) async {
    if (!initialized) throw const PrayerException(PrayerFailure.needsAttention);
    await repository.save(updated);
    state = updated;
    reminderStatus = PrayerScheduleResult(
      updated.reminders.anyEnabled
          ? PrayerScheduleStatus.blocked
          : PrayerScheduleStatus.disabled,
    );
    refresh();
    if (cancelQueue) await notifications.cancelAll();
    await _refreshReminders();
  }

  Future<void> _refreshReminders() async {
    if (_disposed || !initialized) return;
    reminderStatus = PrayerScheduleResult(
      state.reminders.anyEnabled
          ? PrayerScheduleStatus.blocked
          : PrayerScheduleStatus.disabled,
    );
    _notify();
    final revision = state.revision;
    try {
      final capability = await notifications.capabilities();
      final recording = selectedAthan;
      final ready = recording == null || audioReadiness == null
          ? (openingReady: false, fullReady: false)
          : await audioReadiness!(recording);
      if (_disposed || state.revision != revision) return;
      reminderCapability = capability;
      reminderAudioReadiness = ready;
      reminderStatus = await _reminderScheduler.reconcile(
        state,
        recording: recording,
        openingReady: ready.openingReady,
        fullReady: ready.fullReady,
      );
    } on Object {
      reminderStatus = PrayerScheduleResult(
        PrayerScheduleStatus.blocked,
        failure: PrayerFailure.schedulePartial,
      );
      // No ready horizon survives a failed capability/readiness check.
      try {
        await notifications.cancelAll();
      } on Object {
        /* report blocked */
      }
    }
    _notify();
  }

  Future<void> refreshReminders() => _run(_refreshReminders);

  ReminderPreferences _reminderChoices({
    Set<PrayerKind>? prayers,
    String? recordingId,
    AthanMode? mode,
    Map<String, int>? acknowledgements,
  }) {
    final old = state.reminders;
    return ReminderPreferences(
      enabledPrayers: prayers ?? old.enabledPrayers,
      selectedAthanId: recordingId ?? old.selectedAthanId,
      requestedMode: mode ?? old.requestedMode,
      qiyamEnabled: old.qiyamEnabled,
      acknowledgedFallbacks: acknowledgements ?? old.acknowledgedFallbacks,
    );
  }

  Future<void> setDailyReminder(PrayerKind kind, bool enabled) =>
      _run(() async {
        if (!dailyPrayers.contains(kind) || state.activeLocation == null) {
          throw const PrayerException(PrayerFailure.needsAttention);
        }
        final prayers = {...state.reminders.enabledPrayers};
        if (enabled) {
          prayers.add(kind);
        } else {
          prayers.remove(kind);
        }
        if (setEquals(prayers, state.reminders.enabledPrayers)) return;
        await _commit(
          _updated(
            reminders: _reminderChoices(prayers: prayers),
            invalidate: true,
          ),
        );
      });
  Future<void> setAthanMode(AthanMode mode) => _run(() async {
    if (mode == state.reminders.requestedMode) return;
    await _commit(
      _updated(reminders: _reminderChoices(mode: mode), invalidate: true),
    );
  });
  Future<void> selectAthan(String id) => _run(() async {
    final recording = recordings.where((r) => r.id == id).firstOrNull;
    if (recording == null ||
        !recording.completeRecordingReviewed ||
        !recording.fourTakbirsReviewed) {
      throw const PrayerException(PrayerFailure.audioUnavailable);
    }
    if (id == state.reminders.selectedAthanId) return;
    await _commit(
      _updated(reminders: _reminderChoices(recordingId: id), invalidate: true),
    );
  });
  Future<void> requestReminderAuthorization() => _run(() async {
    await notifications.requestAuthorization();
    await _refreshReminders();
  });
  bool get canOpenNotificationSettings =>
      notifications is PrayerNotificationSettings;
  Future<void> openNotificationSettings({bool exactAlarm = false}) =>
      _run(() async {
        final adapter = notifications;
        if (adapter is PrayerNotificationSettings) {
          await (adapter as PrayerNotificationSettings)
              .openNotificationSettings(exactAlarm: exactAlarm);
        }
      });
  DateTime? get nextQiyam {
    final place = state.activeLocation;
    if (place == null) return null;
    final now = clock();
    if (_cachedQiyam?.isAfter(now) == true) return _cachedQiyam;
    if (_cachedQiyam != null) {
      _cachedQiyam = null;
      _qiyamCheckedAt = null;
    }
    if (_cachedQiyam == null &&
        _qiyamCheckedAt != null &&
        !now.isBefore(_qiyamCheckedAt!) &&
        now.difference(_qiyamCheckedAt!) < const Duration(minutes: 1)) {
      return null;
    }
    _qiyamCheckedAt = now;
    final day = tz.TZDateTime.from(now, prayerTimeZone(place.timezoneId));
    for (var offset = -1; offset <= 2; offset++) {
      final instant = calculator
          .schedule(place, DateTime.utc(day.year, day.month, day.day + offset))
          .qiyamUtc;
      if (instant != null && instant.isAfter(now)) {
        return _cachedQiyam = instant;
      }
    }
    return null;
  }

  Future<void> setQiyamReminder(bool enabled) => _run(() async {
    if (state.activeLocation == null || (enabled && nextQiyam == null)) {
      throw const PrayerException(PrayerFailure.calculationUnavailable);
    }
    final old = state.reminders;
    if (old.qiyamEnabled == enabled) return;
    await _commit(
      _updated(
        reminders: ReminderPreferences(
          enabledPrayers: old.enabledPrayers,
          selectedAthanId: old.selectedAthanId,
          requestedMode: old.requestedMode,
          qiyamEnabled: enabled,
          acknowledgedFallbacks: old.acknowledgedFallbacks,
        ),
        invalidate: true,
      ),
    );
  });
  Future<void> acknowledgeReminderFallback(String key) => _run(() async {
    if (key != reminderStatus.requiredAcknowledgement) {
      throw const PrayerException(PrayerFailure.needsAttention);
    }
    await _commit(
      _updated(
        reminders: _reminderChoices(
          acknowledgements: {...state.reminders.acknowledgedFallbacks, key: 1},
        ),
        invalidate: true,
      ),
    );
  });
  Future<void> previewAthan(AthanRecording recording) => _run(() async {
    if (reminderAudio == null || !recordings.contains(recording)) {
      throw const PrayerException(PrayerFailure.audioUnavailable);
    }
    previewingAthan = true;
    _notify();
    try {
      await reminderAudio!.preview(recording);
    } on Object {
      previewingAthan = false;
      rethrow;
    }
  });
  Future<void> stopAthan() async {
    // Stop bypasses the busy guard so it can interrupt a pending preview load.
    previewingAthan = false;
    try {
      await reminderAudio?.stop();
    } on Object {
      failure = PrayerFailure.audioUnavailable;
    }
    _notify();
  }

  void viewLocation(String id) {
    if (busy || _disposed) return;
    try {
      _location(id);
      viewedLocationId = id;
      failure = null;
      refresh();
    } on FormatException {
      failure = PrayerFailure.needsAttention;
      _notify();
    }
  }

  Future<void> renameLocation(String id, String label) => _run(() async {
    final renamed = _location(id).copyWith(label: label);
    await _commit(
      _updated(
        locations: [for (final p in state.locations) p.id == id ? renamed : p],
      ),
    );
  });
  Future<void> activateLocation(String id, {bool confirmed = false}) =>
      _run(() async {
        _location(id);
        if (id == state.activeLocationId) return;
        if (state.reminders.anyEnabled && !confirmed) {
          throw const PrayerException(PrayerFailure.needsAttention);
        }
        await _commit(
          _updated(activeId: id, invalidate: true),
          cancelQueue: true,
        );
      });
  Future<void> updateCalculation(
    String id,
    CalculationPreferences preferences,
  ) => _run(() async {
    // Round-trip validates supported convention versions before writing.
    final checked = CalculationPreferences.fromJson(preferences.toJson());
    final place = _location(id).copyWith(calculation: checked);
    if (jsonEncode(place.calculation.toJson()) ==
        jsonEncode(_location(id).calculation.toJson())) {
      return;
    }
    await _commit(
      _updated(
        locations: [for (final p in state.locations) p.id == id ? place : p],
        invalidate: true,
      ),
      cancelQueue: true,
    );
  });
  Future<void> deleteLocation(
    String id, {
    String? replacementId,
    bool disableReminders = false,
  }) => _run(() async {
    _location(id);
    final isActive = id == state.activeLocationId;
    if (replacementId != null) {
      _location(replacementId);
      if (replacementId == id) {
        throw const FormatException('Invalid replacement');
      }
    }
    if (isActive && replacementId == null && !disableReminders) {
      throw const PrayerException(PrayerFailure.needsAttention);
    }
    final updated = _updated(
      locations: state.locations.where((p) => p.id != id).toList(),
      activeId: isActive ? replacementId : null,
      clearActive: isActive && replacementId == null,
      reminders: isActive && replacementId == null
          ? ReminderPreferences(
              selectedAthanId: state.reminders.selectedAthanId,
              requestedMode: state.reminders.requestedMode,
              acknowledgedFallbacks: state.reminders.acknowledgedFallbacks,
            )
          : state.reminders,
      invalidate: true,
    );
    // Do not erase a place while an obsolete alert may still contain it.
    // A failed save after cancellation retains the source snapshot for retry.
    await notifications.cancelAll();
    await _commit(updated);
    if (viewedLocationId == id) {
      viewedLocationId =
          updated.activeLocationId ?? updated.locations.firstOrNull?.id;
    }
    refresh();
  });
  Future<void> clearPrayerData({bool confirmed = false}) => _run(() async {
    if (!confirmed || !initialized) {
      throw const PrayerException(PrayerFailure.needsAttention);
    }
    // Never erase the source snapshot while obsolete alerts may remain queued.
    await notifications.cancelAll();
    await repository.delete();
    state = PrayerState(generation: state.generation + 1);
    reminderStatus = PrayerScheduleResult(PrayerScheduleStatus.disabled);
    reminderAudioReadiness = (openingReady: false, fullReady: false);
    viewedLocationId = null;
    candidate = null;
    results = [];
    locationClient.cancelSearch();
    _searchVersion++;
    refresh();
  });
  Future<void> useSessionOnly() => _run(() async {
    repository.useSessionOnly();
    state = await repository.load();
    viewedLocationId =
        state.activeLocationId ?? state.locations.firstOrNull?.id;
    initialized = true;
    refresh();
  });
  @override
  void dispose() {
    _disposed = true;
    _searchVersion++;
    locationClient.dispose();
    super.dispose();
  }
}
