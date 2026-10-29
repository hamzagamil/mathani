import 'dart:async';

import 'package:flutter/material.dart';

import '../../platform/prayer_notifications.dart';
import 'prayer_times_screen.dart';

/// Read-only launch detection after the first frame. No permissions, location or
/// audio are started here; only an explicit notification tap opens the route.
class PrayerNotificationOpenHost extends StatefulWidget {
  const PrayerNotificationOpenHost({
    super.key,
    required this.child,
    this.events,
    this.takeOpen,
    this.destination,
  });
  final Widget child;
  final Stream<void>? events;
  final Future<bool> Function()? takeOpen;
  final WidgetBuilder? destination;
  @override
  State<PrayerNotificationOpenHost> createState() =>
      _PrayerNotificationOpenHostState();
}

class _PrayerNotificationOpenHostState
    extends State<PrayerNotificationOpenHost> {
  StreamSubscription<void>? _subscription;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _subscription = (widget.events ?? prayerNotificationOpens).listen(
        (_) => unawaited(_open()),
      );
      unawaited(_open());
    });
  }

  Future<void> _open() async {
    try {
      final requested = await (widget.takeOpen ?? takePrayerNotificationOpen)();
      if (!requested || !mounted || _opening || PrayerTimesScreen.hasOpenRoute) {
        return;
      }
      _opening = true;
      try {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'prayer-times-notification'),
            builder: widget.destination ?? (_) => const PrayerTimesScreen(),
          ),
        );
      } finally {
        _opening = false;
      }
    } on Object {
      /* A missing host/plugin must not block the reader. */
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
