import 'dart:async';

import 'package:flutter/material.dart';

import '../memorization/memorization_controller.dart';
import 'khatma_controller.dart';
import 'khatma_models.dart';
import 'khatma_reminders.dart';
import 'khatma_screen.dart';

/// Opens what a reminder names when it is tapped (specs/014 FR-023): one wird or part opens its
/// place in the Mushaf; more open the Khatma screen. During a memorization session the app just
/// opens, without moving the page or ending the session. Nothing runs before the first frame.
class ReminderOpenHost extends StatefulWidget {
  const ReminderOpenHost({super.key, required this.child});
  final Widget child;

  @override
  State<ReminderOpenHost> createState() => _ReminderOpenHostState();
}

class _ReminderOpenHostState extends State<ReminderOpenHost> {
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final reminders = mounted ? KhatmaRemindersScope.maybeOf(context) : null;
      if (reminders == null) return;
      _subscription = reminders.opened.listen((_) => unawaited(_open()));
      if (await reminders.takeLaunchOpen()) await _open();
    });
  }

  Future<void> _open() async {
    if (!mounted) return;
    if (MemorizationScope.maybeOf(context)?.active ?? false) return;
    final khatma = KhatmaScope.read(context);
    if (khatma == null) return;
    if (!khatma.loaded) await khatma.load();
    if (!mounted) return;
    final waiting = [
      for (final r in khatma.readings)
        if (r.kind != ReadingKind.wird || !khatma.todayRead) r,
    ];
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    if (waiting.length == 1) {
      khatma.openReading(waiting.single);
    } else {
      unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const KhatmaScreen())));
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
