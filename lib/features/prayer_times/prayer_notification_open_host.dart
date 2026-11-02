import 'dart:async';

import 'package:flutter/material.dart';

import 'prayer_alerts.dart';
import 'prayer_services.dart';
import 'prayer_times_screen.dart';

/// Opens Prayer Times when the reader taps an alert. Nothing runs before the first frame; normal
/// launches stay on the reader (FR-020, FR-031).
class PrayerNotificationOpenHost extends StatefulWidget {
  const PrayerNotificationOpenHost({
    super.key,
    required this.child,
    this.destination,
  });
  final Widget child;
  final WidgetBuilder? destination;
  @override
  State<PrayerNotificationOpenHost> createState() =>
      _PrayerNotificationOpenHostState();
}

class _PrayerNotificationOpenHostState
    extends State<PrayerNotificationOpenHost> {
  StreamSubscription<AlertOpened>? _subscription;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final hub = mounted ? PrayerScope.maybeOf(context) : null;
      if (hub == null) return;
      _subscription = hub.opened.listen((_) => unawaited(_open()));
      if (await hub.takeLaunchOpen() != null) await _open();
    });
  }

  Future<void> _open() async {
    if (!mounted || _opening || PrayerTimesScreen.hasOpenRoute) return;
    _opening = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: 'prayer-times-notification'),
          builder: widget.destination ?? (_) => const PrayerTimesScreen(),
        ),
      );
    } on Object {
      /* a missing navigator must not block the reader */
    } finally {
      _opening = false;
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
