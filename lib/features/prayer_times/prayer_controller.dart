import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'prayer_alerts.dart';
import 'prayer_calculator.dart';
import 'prayer_models.dart';
import 'prayer_services.dart';

/// Prayer Times while its route is open. The saved state belongs to [PrayerAlerts]; this
/// holds what the screen shows: the viewed place and day, search and errors.
class PrayerController extends ChangeNotifier {
  PrayerController({required this.hub, this.clock = prayerNow});
  final PrayerAlerts hub;
  final PrayerClock clock;
  late PrayerServices services;
  PrayerState state = PrayerState();
  bool initialized = false, busy = false, searching = false;
  bool _disposed = false;
  PrayerFailure? failure;

  /// The place on screen; alerts follow [PrayerState.current] (FR-010).
  String? viewedPlaceId;

  /// Days from today in the viewed place (FR-005).
  int dayOffset = 0;
  List<Map<String, dynamic>> results = const [];

  /// The internet-based estimate shown as the first search row (R5).
  Map<String, dynamic>? suggestion;

  /// Set after "Use my location" fails, so the app never asks twice in a session.
  PrayerFailure? locationFailure;
  int _search = 0;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    services = await hub.services();
    state = await hub.state();
    viewedPlaceId = state.currentPlace?.id;
    hub.addListener(_hubChanged);
    initialized = true;
    _notify();
  }

  void _hubChanged() {
    final latest = hub.current;
    if (latest == null) return;
    state = latest;
    if (state.placeById(viewedPlaceId) == null) {
      viewedPlaceId = state.currentPlace?.id;
    }
    _notify();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    failure = null;
    _notify();
    try {
      await action();
    } on PrayerException catch (e) {
      failure = e.reason;
    } on Object {
      failure = PrayerFailure.providerUnavailable;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _save(PrayerState next) async {
    await hub.save(next);
    state = next;
  }

  // --- Schedule -------------------------------------------------------------------------------

  Place? get viewedPlace =>
      state.placeById(viewedPlaceId) ?? state.currentPlace;
  bool get viewingCurrent => viewedPlace?.id == state.currentPlace?.id;

  DateTime? get viewedDate {
    final place = viewedPlace;
    if (place == null) return null;
    return PrayerCalculator.localDay(
      place,
      clock(),
    ).add(Duration(days: dayOffset));
  }

  DaySchedule? get schedule {
    final place = viewedPlace, date = viewedDate;
    if (place == null || date == null) return null;
    return services.calculator.schedule(place, date);
  }

  /// Highlighted with a countdown on today only.
  PrayerEvent? get nextPrayer {
    final place = viewedPlace;
    if (place == null || dayOffset != 0) return null;
    final next = services.calculator.nextPrayer(place, clock());
    final date = viewedDate!;
    final local = next?.atUtc == null
        ? null
        : PrayerCalculator.localDay(place, next!.atUtc!);
    return local == date ? next : null;
  }

  void changeDay(int delta) {
    dayOffset = delta == 0 ? 0 : dayOffset + delta;
    _notify();
  }

  /// Tonight's Qiyam for the current place, or null when unavailable.
  DateTime? get nextQiyam {
    final place = state.currentPlace;
    if (place == null) return null;
    final now = clock();
    final today = PrayerCalculator.localDay(place, now);
    for (var d = -1; d <= 1; d++) {
      final q = services.calculator
          .schedule(place, today.add(Duration(days: d)))
          .qiyamUtc;
      if (q != null && q.isAfter(now)) return q;
    }
    return null;
  }

  Future<void> clearMovedNotice() async {
    if (state.movedNotice == null) return;
    await _save(state.copyWith(movedNotice: null));
  }

  // --- Setting a place ------------------------------------------------------------------------

  static String _newId() =>
      [for (var i = 0; i < 12; i++) Random.secure().nextInt(256)]
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

  /// Detects the phone's position and makes "My location" current (Story 1, Story 3).
  Future<void> useMyLocation(String language) => _run(() async {
    if (locationFailure == PrayerFailure.locationDenied) {
      throw const PrayerException(PrayerFailure.locationDenied);
    }
    final Map<String, dynamic> raw;
    try {
      raw = await services.location.detect(language);
    } on PrayerException catch (e) {
      if (e.reason == PrayerFailure.locationDenied ||
          e.reason == PrayerFailure.locationUnavailable) {
        locationFailure = e.reason;
      }
      rethrow;
    }
    locationFailure = null;
    final old = state.myLocation;
    final country = raw['countryCode'] as String? ?? '';
    final place = Place.fromResult(
      raw,
      id: old?.id ?? _newId(),
      calculation: old == null
          ? null
          : old.calculation.methodChosen
          ? old.calculation
          : old.calculation.copyWith(
              method: CalculationSettings.suggestion(country),
            ),
    );
    await _save(
      state.copyWith(myLocation: place, current: myLocationKey).bumped(),
    );
    viewedPlaceId = place.id;
    dayOffset = 0;
  });

  /// Makes the saved "My location" current again without detecting.
  Future<void> useSavedMyLocation() => _run(() async {
    if (state.myLocation == null || state.current == myLocationKey) return;
    await _save(state.copyWith(current: myLocationKey).bumped());
    viewedPlaceId = state.myLocation!.id;
  });

  /// Picks a search result or the estimate. The first place becomes current; later ones are
  /// saved and shown, and alerts keep following the current place (FR-010).
  Future<void> choosePlace(Map<String, dynamic> result, String language) =>
      _run(() async {
        cancelSearch();
        var raw = result;
        if (raw['timezoneId'] == null) {
          raw = await services.location.resolve(
            (raw['latitude'] as num).toDouble(),
            (raw['longitude'] as num).toDouble(),
            language,
          );
          raw = {...raw, 'source': result['source']};
        }
        final place = Place.fromResult(raw, id: _newId());
        final first = !state.isSetUp;
        final next = state.copyWith(
          places: [...state.places, place],
          current: first ? place.id : state.current,
        );
        await _save(first ? next.bumped() : next);
        viewedPlaceId = place.id;
        dayOffset = 0;
        results = const [];
        suggestion = null;
      });

  /// Loads the "Suggested" row when location cannot be used (FR-008).
  Future<void> loadSuggestion(String language) async {
    if (suggestion != null) return;
    try {
      if (locationFailure == null && await services.location.canLocate()) {
        return;
      }
      final estimate = await services.location.approximate(language);
      if (!_disposed) {
        suggestion = estimate;
        _notify();
      }
    } on Object {
      /* offline or unavailable: search alone is enough */
    }
  }

  Future<void> search(String query, String language) async {
    final token = ++_search;
    failure = null;
    results = const [];
    searching = query.trim().length >= 2;
    _notify();
    try {
      final found = await services.location.search(query, language);
      if (token == _search && !_disposed) results = found;
    } on PrayerException catch (e) {
      if (token == _search) failure = e.reason;
    } on Object {
      if (token == _search) failure = PrayerFailure.providerUnavailable;
    } finally {
      if (token == _search && !_disposed) {
        searching = false;
        _notify();
      }
    }
  }

  void cancelSearch() {
    _search++;
    searching = false;
    services.location.cancelSearch();
  }

  // --- Places ---------------------------------------------------------------------------------

  void viewPlace(String id) {
    if (state.placeById(id) == null) return;
    viewedPlaceId = id;
    dayOffset = 0;
    _notify();
  }

  /// Alerts follow [id] from now on.
  Future<void> usePlace(String id) => _run(() async {
    if (state.placeById(id) == null || state.current == id) return;
    if (id == state.myLocation?.id) {
      await _save(state.copyWith(current: myLocationKey).bumped());
    } else {
      await _save(state.copyWith(current: id).bumped());
    }
    viewedPlaceId = id;
  });

  Future<void> renamePlace(String id, String name) => _run(() async {
    final place = state.placeById(id);
    if (place == null || !validPlaceName(name)) return;
    final renamed = place.copyWith(name: name);
    var next = id == state.myLocation?.id
        ? state.copyWith(myLocation: renamed)
        : state.copyWith(
            places: [for (final p in state.places) p.id == id ? renamed : p],
          );
    // Alert text names the current place.
    if (state.currentPlace?.id == id) next = next.bumped();
    await _save(next);
  });

  /// Deleting the current place needs a [replacementId] or [alertsOff] (FR-010, Story 3).
  Future<void> deletePlace(
    String id, {
    String? replacementId,
    bool alertsOff = false,
  }) => _run(() async {
    final isMy = id == state.myLocation?.id;
    final isCurrent = state.currentPlace?.id == id;
    if (state.placeById(id) == null) return;
    final places = [
      for (final p in state.places)
        if (p.id != id) p,
    ];
    final my = isMy ? null : state.myLocation;
    final remainingSetUp = places.isNotEmpty || my != null;
    String? current = state.current;
    var alerts = state.alerts;
    if (isCurrent) {
      if (!remainingSetUp) {
        current = null;
        alerts = alerts.copyWith(prayers: const {}, qiyam: false);
      } else if (replacementId != null &&
          (replacementId == my?.id ||
              places.any((p) => p.id == replacementId))) {
        current = replacementId == my?.id ? myLocationKey : replacementId;
      } else if (alertsOff) {
        current = my != null ? myLocationKey : places.first.id;
        alerts = alerts.copyWith(prayers: const {}, qiyam: false);
      } else {
        return;
      }
    }
    await _save(
      PrayerState(
        places: places,
        myLocation: my,
        current: current,
        alerts: alerts,
        generation: state.generation + 1,
      ),
    );
    if (viewedPlaceId == id) viewedPlaceId = state.currentPlace?.id;
  });

  Future<void> deleteAllPrayerData() => _run(() async {
    await hub.deleteAll();
    state = await hub.state();
    viewedPlaceId = null;
    dayOffset = 0;
  });

  // --- Calculation ----------------------------------------------------------------------------

  Future<void> updateCalculation(
    String placeId,
    CalculationSettings settings,
  ) => _run(() async {
    final place = state.placeById(placeId);
    if (place == null) return;
    final old = place.calculation;
    final next = settings.copyWith(
      methodChosen: old.methodChosen || settings.method != old.method,
      offsets: {
        for (final e in settings.offsets.entries) e.key: e.value.clamp(-30, 30),
      },
    );
    if (next == old) return;
    final updated = place.copyWith(calculation: next);
    var s = placeId == state.myLocation?.id
        ? state.copyWith(myLocation: updated)
        : state.copyWith(
            places: [
              for (final p in state.places) p.id == placeId ? updated : p,
            ],
          );
    if (state.currentPlace?.id == placeId) s = s.bumped();
    await _save(s);
  });

  // --- Alerts ---------------------------------------------------------------------------------

  /// The first alert turned on asks for notification permission, in context (FR-018).
  Future<void> setPrayerAlert(PrayerKind kind, bool enabled) => _run(() async {
    if (!dailyPrayers.contains(kind)) return;
    if (enabled) await _askPermission();
    final prayers = {...state.alerts.prayers};
    enabled ? prayers.add(kind) : prayers.remove(kind);
    await _save(
      state.copyWith(alerts: state.alerts.copyWith(prayers: prayers)).bumped(),
    );
  });

  Future<void> setQiyam(bool enabled) => _run(() async {
    if (enabled) await _askPermission();
    await _save(
      state.copyWith(alerts: state.alerts.copyWith(qiyam: enabled)).bumped(),
    );
  });

  Future<void> setSound(String sound) => _run(() async {
    if (!services.catalogue.soundChoices.contains(sound)) return;
    await _save(
      state.copyWith(alerts: state.alerts.copyWith(sound: sound)).bumped(),
    );
  });

  Future<void> setAthanLength(AthanLength length) => _run(() async {
    await _save(
      state.copyWith(alerts: state.alerts.copyWith(athan: length)).bumped(),
    );
  });

  /// iOS cannot tell "never asked" from "refused" without asking, and the OS shows its prompt
  /// only once, so turning an alert on asks whenever alerts are not allowed yet.
  Future<void> _askPermission() async {
    final status = await services.platform.status();
    if (status.notifications == NotificationPermission.notDetermined ||
        status.notifications == NotificationPermission.denied) {
      await services.platform.requestPermission();
    }
  }

  Future<void> openSettings({bool exactAlarms = false}) =>
      services.platform.openSettings(exactAlarms: exactAlarms);

  /// Downloads the chosen recording for full athan (FR-023).
  Future<void> downloadFull() => _run(() async {
    final r = services.catalogue.byId(state.alerts.sound);
    if (r == null) return;
    await services.downloads.download(r);
    await hub.refill();
  });

  Future<void> preview(String sound) async {
    try {
      await services.player.preview(sound);
    } on Object {
      failure = PrayerFailure.audioUnavailable;
      _notify();
    }
  }

  Future<void> stopSound() => services.player.stop();

  @override
  void dispose() {
    _disposed = true;
    _search++;
    hub.removeListener(_hubChanged);
    super.dispose();
  }
}
