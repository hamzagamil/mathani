import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:timezone/timezone.dart' as tz;

import '../../app/l10n/app_localizations.dart';
import '../../platform/prayer_location.dart';
import '../../platform/prayer_notifications.dart';
import '../../platform/prayer_notifications_page.dart';
import 'athan_catalogue.dart';
import 'athan_player.dart';
import 'prayer_calculator.dart';
import 'prayer_copy.dart';
import 'prayer_models.dart';
import 'prayer_repository.dart';
import 'prayer_services.dart';
import 'prayer_time_zones.dart';

/// What the prayer screens and the alerts share, created on first use (research R11).
class PrayerServices {
  PrayerServices({
    required this.calculator,
    required this.catalogue,
    required this.downloads,
    required this.player,
    required this.platform,
    required this.location,
  });
  final PrayerCalculator calculator;
  final AthanCatalogue catalogue;
  final AthanDownloads downloads;
  final AthanPlayer player;
  final PrayerAlertPlatform platform;
  final PrayerLocationClient location;
}

/// The alert ids are stable across refills: FNV-1a of place, local date and kind, 31 bits.
int alertId(String placeId, DateTime localDate, PrayerKind kind) {
  var hash = 0x811c9dc5;
  final key =
      '$placeId|${localDate.toIso8601String().substring(0, 10)}|${kind.name}';
  for (final unit in key.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// Kilometres between two points (haversine).
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLon = rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 6371 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// The next [max] alerts for the current place, starting after [now] (data model → Alert).
/// Sunrise never has an alert; unavailable times are skipped (FR-014).
List<Alert> buildAlerts({
  required PrayerState state,
  required DateTime now,
  required PrayerCalculator calculator,
  required AthanCatalogue catalogue,
  required AppLocalizations l10n,
  bool fullReady = false,
  String? fullPath,
  int max = 60,
}) {
  final place = state.currentPlace;
  final settings = state.alerts;
  if (place == null || !settings.any) return const [];
  final sound =
      settings.sound == toneSound ||
          settings.sound == silentSound ||
          catalogue.byId(settings.sound) != null
      ? settings.sound
      : toneSound;
  final full =
      settings.athan == AthanLength.full &&
      fullReady &&
      catalogue.byId(sound) != null;
  final zone = prayerTimeZone(place.timezoneId);
  String time(DateTime at) {
    final local = tz.TZDateTime.from(at, zone);
    try {
      return DateFormat.jm(l10n.localeName).format(local);
    } on Object {
      // Date data not loaded yet (before the first localized frame): 24-hour digits.
      String two(int v) => v.toString().padLeft(2, '0');
      return '${two(local.hour)}:${two(local.minute)}';
    }
  }

  String body(DateTime at) => l10n.prayerAlertBody(time(at), place.name);
  final alerts = <Alert>[];
  // Yesterday too: its Qiyam may still be ahead, after midnight.
  final first = PrayerCalculator.localDay(
    place,
    now,
  ).subtract(const Duration(days: 1));
  for (var day = 0; day < 16 && alerts.length < max + 6; day++) {
    final date = first.add(Duration(days: day));
    final schedule = calculator.schedule(place, date);
    for (final e in schedule.events) {
      if (!settings.prayers.contains(e.kind) ||
          e.atUtc == null ||
          !e.atUtc!.isAfter(now)) {
        continue;
      }
      alerts.add(
        Alert(
          id: alertId(place.id, date, e.kind),
          kind: e.kind,
          atUtc: e.atUtc!,
          title: prayerName(l10n, e.kind),
          body: body(e.atUtc!),
          sound: sound,
          full: full,
          fullPath: full ? fullPath : null,
          generation: state.generation,
        ),
      );
    }
    final qiyam = schedule.qiyamUtc;
    if (settings.qiyam && qiyam != null && qiyam.isAfter(now)) {
      alerts.add(
        Alert(
          id: alertId(place.id, date, PrayerKind.qiyam),
          kind: PrayerKind.qiyam,
          atUtc: qiyam,
          title: l10n.prayerQiyam,
          body: l10n.prayerQiyamNotification,
          sound: toneSound,
          generation: state.generation,
        ),
      );
    }
  }
  alerts.sort((a, b) => a.atUtc.compareTo(b.atUtc));
  return alerts.take(max).toList();
}

/// App-scoped, created at launch but idle until after the first frame (FR-031). It owns the
/// prayer state, keeps alerts filled on start and resume, refreshes "My location" (R4) and
/// plays the full athan in the app on iPhone and web (R9).
class PrayerAlerts extends ChangeNotifier {
  PrayerAlerts({
    required PrayerStateStore store,
    required this.l10n,
    required this.pauseQuran,
    required this.pauseMemorization,
    Future<PrayerServices> Function()? services,
    this.clock = prayerNow,
    TargetPlatform? platform,
  }) : repository = PrayerRepository(store),
       _makeServices = services,
       target = kIsWeb ? null : platform ?? defaultTargetPlatform;
  final PrayerRepository repository;
  final AppLocalizations Function() l10n;
  final void Function() pauseQuran, pauseMemorization;
  final PrayerClock clock;

  /// Null on the web.
  final TargetPlatform? target;
  final Future<PrayerServices> Function()? _makeServices;
  Future<PrayerServices>? _services;
  Future<PrayerState>? _loading;
  PrayerState? _state;

  /// What the phone allows, as of the last refill.
  AlertStatus? status;

  /// Alerts actually pending after the last refill.
  int pending = 0;

  /// A web alert whose sound the browser blocked: the reader presses Play (contract › states).
  Alert? needsPlay;
  final _opened = StreamController<AlertOpened>.broadcast();
  StreamSubscription<PrayerPlatformEvent>? _events;
  Timer? _fullTimer;
  DateTime? _lastRefresh;
  bool _active = true, _refilling = false, _again = false, _cleared = false;

  /// Alert taps, for the route host (contract › Native contract).
  Stream<AlertOpened> get opened => _opened.stream;

  PrayerState? get current => _state;

  Future<PrayerServices> services() => _services ??= _create();

  Future<PrayerServices> _create() async {
    if (_makeServices != null) return _makeServices();
    final catalogue = await AthanCatalogue.load();
    final downloads = AthanDownloads();
    final names = l10n;
    final services = PrayerServices(
      calculator: await PrayerCalculator.load(),
      catalogue: catalogue,
      downloads: downloads,
      player: AthanPlayer(
        catalogue: catalogue,
        downloads: downloads,
        pauseQuran: pauseQuran,
        pauseMemorization: pauseMemorization,
      ),
      platform: prayerAlertPlatform(
        channels: () => prayerChannelNames(names(), catalogue),
      ),
      location: PrayerLocationService(),
    );
    final platform = services.platform;
    if (platform is PageAlerts) {
      platform.onDue = (alert) => unawaited(_playWebAlert(services, alert));
    }
    return services;
  }

  Future<PrayerState> state() async =>
      _state ?? await (_loading ??= repository.load().then((s) => _state = s));

  /// Saves [next], then rebuilds alerts when its generation changed.
  Future<void> save(PrayerState next) async {
    final previous = await state();
    await repository.save(next);
    _state = next;
    notifyListeners();
    if (next.generation != previous.generation) await refill();
  }

  /// Deletes all prayer data and cancels every alert.
  Future<void> deleteAll() async {
    final s = await services();
    await s.platform.cancelAll();
    await repository.delete();
    _state = PrayerState(generation: (_state?.generation ?? 0) + 1);
    pending = 0;
    notifyListeners();
  }

  /// After the first frame on start, and on every resume.
  Future<void> onAppActive() async {
    _active = true;
    try {
      if (kIsWeb && !_cleared) {
        _cleared = true;
        await clearLegacyPrayerStorage();
      }
      final s = await state();
      if (!s.isSetUp) return;
      final services = await this.services();
      _events ??= services.platform.events.listen(_onEvent);
      await _refreshMyLocation(services);
      await refill();
    } on Object {
      /* prayer times must never block the reader */
    }
  }

  void onAppInactive() {
    _active = false;
    _fullTimer?.cancel();
  }

  /// The alert that launched the app, asked once by the route host.
  Future<AlertOpened?> takeLaunchOpen() async {
    try {
      final services = await this.services();
      _events ??= services.platform.events.listen(_onEvent);
      final opened = await services.platform.takeLaunchOpen();
      if (opened != null) unawaited(_playFullAfterOpen(services));
      return opened;
    } on Object {
      return null;
    }
  }

  void _onEvent(PrayerPlatformEvent event) {
    switch (event) {
      case AlertOpened():
        _opened.add(event);
        unawaited(services().then(_playFullAfterOpen));
      case AthanStarted():
        pauseMemorization();
    }
  }

  AthanRecording? _fullRecording(PrayerServices services, PrayerState s) =>
      s.alerts.athan == AthanLength.full
      ? services.catalogue.byId(s.alerts.sound)
      : null;

  /// iPhone and web: tapping an alert plays the full athan (FR-024). Android plays it natively.
  Future<void> _playFullAfterOpen(PrayerServices services) async {
    if (target == TargetPlatform.android) return;
    final r = _fullRecording(services, await state());
    if (r != null && services.downloads.status(r) == DownloadStatus.ready) {
      await services.player.playFull(r);
    }
  }

  Future<void> _playWebAlert(PrayerServices services, Alert alert) async {
    try {
      needsPlay = null;
      await services.player.playAlert(alert);
    } on Object {
      needsPlay = alert;
      notifyListeners();
    }
  }

  /// The reader's Play after the browser blocked the sound.
  Future<void> playBlocked() async {
    final alert = needsPlay;
    if (alert == null) return;
    await _playWebAlert(await services(), alert);
    notifyListeners();
  }

  Future<void> _refreshMyLocation(PrayerServices services) async {
    final s = await state();
    final old = s.myLocation;
    if (s.current != myLocationKey || old == null) return;
    final now = clock();
    if (_lastRefresh != null &&
        now.difference(_lastRefresh!) < const Duration(minutes: 30)) {
      return;
    }
    _lastRefresh = now;
    final position = await services.location.passivePosition();
    if (position == null ||
        distanceKm(
              old.latitude,
              old.longitude,
              position.latitude,
              position.longitude,
            ) <=
            10) {
      return;
    }
    try {
      final raw = await services.location.resolve(
        position.latitude,
        position.longitude,
        l10n().localeName,
        source: 'device',
      );
      final country = raw['countryCode'] as String? ?? '';
      final calculation = old.calculation.methodChosen
          ? old.calculation
          : old.calculation.copyWith(
              method: CalculationSettings.suggestion(country),
            );
      final place = Place.fromResult(raw, id: old.id, calculation: calculation);
      final latest = await state();
      if (latest.current != myLocationKey) return;
      await save(
        latest
            .copyWith(
              myLocation: place,
              movedNotice: place.city.isNotEmpty && place.city != old.city
                  ? place.city
                  : latest.movedNotice,
            )
            .bumped(),
      );
    } on Object {
      /* keep the previous place; retry on a later resume */
    }
  }

  /// Rebuilds the pending alerts from the saved state. Calls made while one runs are merged.
  Future<void> refill() async {
    if (_refilling) {
      _again = true;
      return;
    }
    _refilling = true;
    try {
      do {
        _again = false;
        await _refill();
      } while (_again);
    } on Object {
      /* status stays as it was; the next resume retries */
    } finally {
      _refilling = false;
      notifyListeners();
    }
  }

  Future<void> _refill() async {
    final services = await this.services();
    final s = await state();
    status = await services.platform.status();
    if (!s.isSetUp || !s.alerts.any) {
      await services.platform.cancelAll();
      pending = 0;
      _fullTimer?.cancel();
      return;
    }
    final recording = _fullRecording(services, s);
    if (recording != null &&
        services.downloads.status(recording) == DownloadStatus.absent) {
      await services.downloads.verify(recording);
    }
    final ready =
        recording != null &&
        services.downloads.status(recording) == DownloadStatus.ready;
    final alerts = buildAlerts(
      state: s,
      now: clock(),
      calculator: services.calculator,
      catalogue: services.catalogue,
      l10n: l10n(),
      fullReady: ready,
      fullPath: ready && target == TargetPlatform.android
          ? await services.downloads.localPath(recording)
          : null,
    );
    pending = await services.platform.replace(alerts, s.generation);
    _armFullTimer(services, alerts);
  }

  /// iPhone: while the app is open, play the full athan at the next full alert (R9).
  void _armFullTimer(PrayerServices services, List<Alert> alerts) {
    _fullTimer?.cancel();
    if (target != TargetPlatform.iOS || !_active) return;
    final next = alerts.where((a) => a.full).firstOrNull;
    if (next == null) return;
    _fullTimer = Timer(next.atUtc.difference(clock()), () async {
      final r = _fullRecording(services, await state());
      if (_active && r != null) await services.player.playFull(r);
    });
  }

  @override
  void dispose() {
    _fullTimer?.cancel();
    unawaited(_events?.cancel());
    unawaited(_opened.close());
    super.dispose();
  }
}

/// Gives the prayer screens the app's [PrayerAlerts].
class PrayerScope extends InheritedWidget {
  const PrayerScope({super.key, required this.alerts, required super.child});
  final PrayerAlerts alerts;

  static PrayerAlerts? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PrayerScope>()?.alerts;

  @override
  bool updateShouldNotify(PrayerScope oldWidget) => alerts != oldWidget.alerts;
}
