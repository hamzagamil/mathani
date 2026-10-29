import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import 'prayer_calculator.dart';
import 'prayer_models.dart';
import 'prayer_repository.dart';
import 'prayer_services.dart';
import 'prayer_time_zones.dart';

class PrayerController extends ChangeNotifier {
  PrayerController({
    required this.repository,
    required this.locationClient,
    required this.calculator,
    this.clock = prayerNow,
    this.notifications = const NoPrayerNotifications(),
  });
  final PrayerRepository repository;
  final PrayerLocationClient locationClient;
  final PrayerCalculator calculator;
  final PrayerClock clock;
  final PrayerNotificationAdapter notifications;
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
  });
  void refresh() {
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
    refresh();
    if (cancelQueue) await notifications.cancelAll();
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
