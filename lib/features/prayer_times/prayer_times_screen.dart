import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:timezone/timezone.dart' as tz;

import '../../app/l10n/app_localizations.dart';
import '../../shared/numerals.dart';
import 'calculation_sheet.dart';
import 'location_setup_sheet.dart';
import 'locations_sheet.dart';
import 'prayer_alerts.dart';
import 'prayer_controller.dart';
import 'prayer_copy.dart';
import 'prayer_models.dart';
import 'prayer_time_zones.dart';
import 'reminder_settings.dart';

/// Prayer Times (contracts/prayer-ui-and-reminders.md › Screens). Its controller lives only while
/// the route is open; the saved state and alerts belong to the app's [PrayerAlerts].
class PrayerTimesScreen extends StatefulWidget {
  static int _openRoutes = 0;
  static bool get hasOpenRoute => _openRoutes > 0;
  const PrayerTimesScreen({super.key, this.controller});
  final PrayerController? controller;
  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  PrayerController? _controller;
  Timer? _ticker;
  String? _moved;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    PrayerTimesScreen._openRoutes++;
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  Future<void> _load() async {
    try {
      final c =
          widget.controller ??
          PrayerController(hub: PrayerScope.maybeOf(context)!);
      if (!c.initialized) await c.initialize();
      if (!mounted) {
        if (widget.controller == null) c.dispose();
        return;
      }
      // "Moved to {city}" shows once, then is cleared (Story 3).
      _moved = c.state.movedNotice;
      if (_moved != null) unawaited(c.clearMovedNotice());
      setState(() {
        _controller = c;
        _loadFailed = false;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } on Object {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  void dispose() {
    PrayerTimesScreen._openRoutes--;
    _ticker?.cancel();
    if (widget.controller == null) _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), c = _controller;
    final ready = c != null && c.state.isSetUp;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.prayerTimesTitle),
        actions: [
          if (ready) ...[
            IconButton(
              tooltip: l.prayerPlaces,
              icon: const Icon(Icons.location_city_outlined),
              onPressed: () => showPrayerPlaces(context, c),
            ),
            IconButton(
              tooltip: l.prayerCalculationSettings,
              icon: const Icon(Icons.tune),
              onPressed: () => showPrayerCalculation(context, c),
            ),
            IconButton(
              tooltip: l.prayerAlerts,
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => showPrayerAlerts(context, c),
            ),
          ],
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
                listenable: Listenable.merge([c, c.hub]),
                builder: (context, _) => c.state.isSetUp
                    ? _schedule(context, c, l)
                    : PrayerFirstTime(controller: c),
              ),
      ),
    );
  }

  Widget _schedule(
    BuildContext context,
    PrayerController c,
    AppLocalizations l,
  ) {
    final place = c.viewedPlace!, schedule = c.schedule!, date = c.viewedDate!;
    final theme = Theme.of(context), locale = Localizations.localeOf(context);
    final zone = prayerTimeZone(place.timezoneId);
    final next = c.nextPrayer;
    String time(DateTime t) =>
        DateFormat.jm(locale.languageCode).format(tz.TZDateTime.from(t, zone));
    final now = c.clock();
    final otherZone =
        tz.TZDateTime.from(now, zone).timeZoneOffset !=
        now.toLocal().timeZoneOffset;
    final blocked = c.hub.needsPlay;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (c.busy) const LinearProgressIndicator(),
        if (_moved != null)
          _Notice(text: l.prayerMovedTo(_moved!), icon: Icons.near_me_outlined),
        if (blocked != null)
          _Notice(
            text: l.prayerAutoplayBlocked,
            icon: Icons.volume_up_outlined,
            action: TextButton(
              onPressed: c.hub.playBlocked,
              child: Text(l.prayerAthanPlay),
            ),
          ),
        if (c.failure != null)
          Semantics(
            liveRegion: true,
            child: Text(prayerFailureMessage(l, c.failure!)),
          ),
        Text(place.name, style: theme.textTheme.headlineSmall),
        if (!c.viewingCurrent) ...[
          Text(l.prayerViewingNote(c.state.currentPlace?.name ?? '')),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton(
              onPressed: c.busy ? null : () => c.usePlace(place.id),
              child: Text(l.prayerUseThisPlace),
            ),
          ),
        ],
        Row(
          children: [
            IconButton(
              tooltip: l.prayerPreviousDay,
              icon: const Icon(Icons.chevron_left),
              onPressed: () => c.changeDay(-1),
            ),
            Expanded(
              child: Text(
                DateFormat.yMMMMEEEEd(locale.languageCode).format(date),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: l.prayerNextDay,
              icon: const Icon(Icons.chevron_right),
              onPressed: () => c.changeDay(1),
            ),
          ],
        ),
        if (c.dayOffset != 0)
          Center(
            child: TextButton(
              onPressed: () => c.changeDay(0),
              child: Text(l.prayerToday),
            ),
          ),
        Text(
          '${prayerMethodName(l, place.calculation.method)} · '
          '${l.prayerAsrSetting}: ${prayerAsrName(l, place.calculation.asr)}',
          style: theme.textTheme.bodySmall,
        ),
        if (otherZone)
          Text(
            l.prayerZoneNote(place.timezoneId),
            style: theme.textTheme.bodySmall,
          ),
        if (next != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: false,
            child: Text(
              '${l.prayerNext}: ${prayerName(l, next.kind)} · ${time(next.atUtc!)}',
              style: theme.textTheme.titleMedium,
            ),
          ),
          Text(
            _countdown(next.atUtc!.difference(now), locale),
            textDirection: TextDirection.ltr,
            style: theme.textTheme.headlineMedium,
          ),
        ],
        const Divider(height: 32),
        for (final e in schedule.events)
          ListTile(
            contentPadding: EdgeInsets.zero,
            selected: next?.kind == e.kind,
            title: Text(prayerName(l, e.kind)),
            subtitle: _marks(l, place, e),
            trailing: Text(
              e.atUtc == null ? l.prayerUnavailable : time(e.atUtc!),
              style: theme.textTheme.titleMedium,
            ),
          ),
        if (schedule.events.every((e) => e.atUtc == null))
          Text(l.prayerCalculationUnavailable),
      ],
    );
  }

  static Widget? _marks(AppLocalizations l, Place place, PrayerEvent e) {
    final marks = [
      if (e.kind == PrayerKind.sunrise) l.prayerNotAPrayer,
      if (e.adjustedBy.contains(Adjustment.highLatitude))
        l.prayerAdjustedLatitude(
          prayerRuleName(l, place.calculation.highLatitudeRule),
        ),
      if (e.adjustedBy.contains(Adjustment.offset))
        l.prayerAdjustedMinutes(
          signedMinutes(place.calculation.offset(e.kind)),
        ),
    ];
    return marks.isEmpty ? null : Text(marks.join(' · '));
  }

  static String _countdown(Duration d, Locale locale) {
    String n(int v) => formatNumber(
      v,
      locale,
    ).padLeft(2, locale.languageCode == 'ar' ? '٠' : '0');
    if (d.isNegative) d = Duration.zero;
    return [
      n(d.inHours),
      n(d.inMinutes.remainder(60)),
      n(d.inSeconds.remainder(60)),
    ].join(':');
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.icon, this.action});
  final String text;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Semantics(
      liveRegion: true,
      child: ListTile(
        leading: Icon(icon),
        title: Text(text),
        subtitle: action == null
            ? null
            : Align(alignment: AlignmentDirectional.centerStart, child: action),
      ),
    ),
  );
}
