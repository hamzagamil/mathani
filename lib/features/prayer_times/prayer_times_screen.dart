import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:timezone/timezone.dart' as tz;

import '../../app/l10n/app_localizations.dart';
import '../../platform/prayer_location.dart';
import '../../shared/numerals.dart';
import 'location_setup_sheet.dart';
import 'locations_sheet.dart';
import 'calculation_sheet.dart';
import 'prayer_calculator.dart';
import 'prayer_controller.dart';
import 'prayer_copy.dart';
import 'prayer_models.dart';
import 'prayer_repository.dart';
import 'prayer_time_zones.dart';

/// Owns its lazy services only while the route is open; no reader-startup IO.
class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key, this.controller});
  final PrayerController? controller;
  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen>
    with WidgetsBindingObserver {
  PrayerController? _controller;
  Timer? _ticker;
  String? _day;
  DateTime? _lastTick;
  bool _loadFailed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  Future<void> _load() async {
    try {
      final c =
          widget.controller ??
          PrayerController(
            repository: PrayerRepository(SecurePrayerSnapshotStore()),
            locationClient: PrayerLocationService(),
            calculator: await PrayerCalculator.load(),
          );
      if (!mounted) {
        if (widget.controller == null) c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _loadFailed = false;
      });
      await c.initialize();
      if (!mounted) return;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final place = c.viewedLocation;
        final now = c.clock();
        final clockChanged =
            _lastTick != null &&
            (now.difference(_lastTick!).isNegative ||
                now.difference(_lastTick!).inSeconds > 5);
        _lastTick = now;
        if (place != null) {
          final local = tz.TZDateTime.from(
            now,
            prayerTimeZone(place.timezoneId),
          );
          final active = c.state.activeLocation;
          final activeDay = active == null
              ? null
              : tz.TZDateTime.from(now, prayerTimeZone(active.timezoneId));
          final day = [
            place.id,
            local.year,
            local.month,
            local.day,
            activeDay?.year,
            activeDay?.month,
            activeDay?.day,
          ].join('-');
          if (_day != day || clockChanged) {
            _day = day;
            c.refresh();
          }
        }
        setState(() {});
      });
    } on Object {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller?.refresh();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), c = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.prayerTimesTitle),
        actions: [
          if (c != null && c.initialized)
            IconButton(
              tooltip: l.prayerSavedLocations,
              icon: const Icon(Icons.location_city_outlined),
              onPressed: c.busy ? null : () => showPrayerLocations(context, c),
            ),
          if (c != null && c.initialized)
            IconButton(
              tooltip: l.prayerAddLocation,
              icon: const Icon(Icons.location_on_outlined),
              onPressed: c.busy
                  ? null
                  : () => showPrayerLocationSetup(context, c),
            ),
        ],
      ),
      body: SafeArea(
        child: c == null
            ? Center(
                child: _loadFailed
                    ? TextButton(onPressed: _load, child: Text(l.prayerRetry))
                    : const CircularProgressIndicator(),
              )
            : ListenableBuilder(
                listenable: c,
                builder: (context, _) => _content(context, c, l),
              ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    PrayerController c,
    AppLocalizations l,
  ) {
    final place = c.viewedLocation, schedule = c.schedule;
    final locale = Localizations.localeOf(context);
    final next = c.nextPrayer;
    String time(DateTime value) => DateFormat.jm(locale.languageCode)
        .format(tz.TZDateTime.from(value, prayerTimeZone(place!.timezoneId)));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (c.busy) const LinearProgressIndicator(),
        if (c.sessionOnly) Text(l.prayerSessionNotice),
        if (c.failure != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(prayerFailureMessage(l, c.failure!)),
          ),
          TextButton(
            onPressed: c.busy ? null : c.initialize,
            child: Text(l.prayerRetry),
          ),
          if (!c.initialized)
            TextButton(
              onPressed: c.busy ? null : c.useSessionOnly,
              child: Text(l.prayerSessionOnly),
            ),
        ],
        if (place == null) ...[
          Text(l.prayerNoLocation),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: c.initialized && !c.busy
                ? () => showPrayerLocationSetup(context, c)
                : null,
            child: Text(l.prayerAddLocation),
          ),
        ],
        if (place != null && schedule != null) ...[
          Text(place.label, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            c.state.activeLocationId == place.id
                ? l.prayerActiveLocation
                : l.prayerViewedLocation,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          if (c.state.activeLocationId != place.id) ...[
            Text(
              c.state.activeLocation == null
                  ? l.prayerNoActiveLocation
                  : '${l.prayerActiveLocation}: ${c.state.activeLocation!.label}',
            ),
            Text(l.prayerReminderLocationHint),
            OutlinedButton(
              onPressed: c.busy
                  ? null
                  : () async {
                      if (await confirmPrayerAction(
                        context,
                        l.prayerUseForReminders,
                        l.prayerActivateConfirm,
                        l.prayerUseForReminders,
                      )) {
                        await c.activateLocation(place.id, confirmed: true);
                      }
                    },
              child: Text(l.prayerUseForReminders),
            ),
          ],
          if (place.approximate) Text(l.prayerApproximate),
          Text(
            DateFormat.yMMMMEEEEd(locale.languageCode)
                .format(schedule.localDate),
          ),
          Text(place.timezoneId),
          const SizedBox(height: 12),
          Text(
            '${l.prayerMethod}: ${prayerMethodName(l, place.calculation.method)}',
          ),
          Text(
            '${l.prayerMadhhab}: ${prayerMadhhabName(l, place.calculation.madhhab)}',
          ),
          Text(
            '${l.prayerHighLatitude}: ${place.calculation.highLatitudeRule == HighLatitudeRule.middleOfNight ? l.prayerMiddleNight : l.prayerSeventhNight}',
          ),
          TextButton.icon(
            onPressed: c.busy ? null : () => showPrayerCalculation(context, c),
            icon: const Icon(Icons.tune),
            label: Text(l.prayerCalculationSettings),
          ),
          const SizedBox(height: 16),
          if (next != null) ...[
            Text(
              '${l.prayerNext}: ${prayerName(l, next.kind)} · ${time(next.dueAtUtc!)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Builder(
              builder: (_) {
                final remaining = next.dueAtUtc!.difference(c.clock());
                String n(int v) => formatNumber(
                  v,
                  locale,
                ).padLeft(2, locale.languageCode == 'ar' ? '٠' : '0');
                return Text(
                  [
                    n(remaining.inHours),
                    n(remaining.inMinutes.remainder(60)),
                    n(remaining.inSeconds.remainder(60)),
                  ].join(':'),
                  textDirection: TextDirection.ltr,
                );
              },
            ),
          ],
          const Divider(height: 32),
          for (final event in schedule.events)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(prayerName(l, event.kind)),
              subtitle: event.availability == PrayerAvailability.adjusted
                  ? Text(l.prayerAdjusted)
                  : null,
              trailing: Text(
                event.dueAtUtc == null
                    ? l.prayerUnavailable
                    : time(event.dueAtUtc!),
              ),
            ),
          if (schedule.events.every((e) => e.dueAtUtc == null))
            Text(l.prayerCalculationUnavailable),
          TextButton(
            onPressed: c.busy
                ? null
                : () => showPrayerLocationSetup(context, c),
            child: Text(l.prayerChangeLocation),
          ),
        ],
      ],
    );
  }
}
