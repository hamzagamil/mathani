import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../app/l10n/app_localizations.dart';
import 'khatma_controller.dart';
import 'khatma_format.dart';
import 'khatma_models.dart';
import 'khatma_reminder_platform.dart';

/// A group part the reader holds and has not read, as the reminder names it (release B).
class HeldPartReminder {
  const HeldPartReminder({required this.title, required this.partName});
  final String title;
  final String partName;
}

/// The daily reminder (specs/014 research R8): one-time notifications for today and the next
/// nine days at the chosen time, rebuilt whenever something they depend on changes.
///
/// A day is due when the personal khatma is active, has started and that day has no read wird,
/// or when the reader holds an unread group part. Today's is left out when today is read, when
/// its time has passed, or while a page of the current wird is on screen.
class KhatmaReminders extends ChangeNotifier {
  KhatmaReminders({
    required this.khatma,
    required this.platform,
    required this.l10n,
    Clock? clock,
    this.heldParts,
  }) : _clock = clock ?? DateTime.now;

  static const days = 10;

  final KhatmaController khatma;
  final KhatmaReminderPlatform platform;
  final AppLocalizations Function() l10n;
  final Clock _clock;

  /// The unread group parts the reader holds, from the last state the device saw (FR-024).
  List<HeldPartReminder> Function()? heldParts;

  ReminderStatus? _status;
  ReminderStatus? get status => _status;

  bool get supported => _status?.permission != ReminderPermission.unsupported;

  List<KhatmaReminder>? _scheduled;
  Future<void>? _running;
  bool _again = false;
  bool _started = false;
  final _opened = StreamController<void>.broadcast();

  /// A reminder was tapped (FR-023).
  Stream<void> get opened => _opened.stream;

  /// A reminder's id: one per calendar day, so a rebuild never doubles one.
  static int idFor(CalendarDay day) => 2100000000 + day.daysSince(const CalendarDay(2020, 1, 1));

  /// Starts following the khatma and the reader, after the first frame.
  void start() {
    if (_started) return;
    _started = true;
    khatma.addListener(sync);
    khatma.reader.addListener(_onReader);
    platform.opened.listen((_) => _opened.add(null));
    unawaited(sync());
  }

  bool? _onScreen;

  /// Today's reminder waits while the current wird is on screen (N5): a rebuild only when that
  /// changes, not on every page turn.
  void _onReader() {
    final on = khatma.currentWirdOnScreen;
    if (on == _onScreen) return;
    _onScreen = on;
    unawaited(sync());
  }

  /// Rebuilds the reminders. Calls made while one runs are merged into one more.
  Future<void> sync() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    return _running = _sync().whenComplete(() {
      _running = null;
      if (_again) {
        _again = false;
        unawaited(sync());
      }
    });
  }

  Future<void> _sync() async {
    if (!khatma.loaded) return;
    try {
      final status = await platform.status();
      if (_status?.permission != status.permission || _status?.exactAlarms != status.exactAlarms) {
        _status = status;
        notifyListeners();
      }
      final wanted = status.permission == ReminderPermission.granted ? build() : const <KhatmaReminder>[];
      if (!_sameAs(wanted)) {
        await platform.replace(wanted);
        _scheduled = wanted;
      }
      // Read today: a reminder still in the notification list goes (research R8).
      if (khatma.todayRead && (heldParts?.call() ?? const []).isEmpty) {
        await platform.clearDelivered([idFor(khatma.today)]);
      }
    } catch (_) {
      // A platform error leaves the previous reminders; the next change tries again.
    }
  }

  bool _sameAs(List<KhatmaReminder> wanted) {
    final s = _scheduled;
    if (s == null || s.length != wanted.length) return false;
    for (var i = 0; i < s.length; i++) {
      if (s[i] != wanted[i]) return false;
    }
    return true;
  }

  /// The reminders for the next [days] days (contracts › The reminder, N1 to N11).
  List<KhatmaReminder> build() {
    final setting = khatma.reminder;
    if (!setting.on) return const [];
    final now = _clock();
    final today = CalendarDay.of(now);
    final strings = l10n();
    final f = KhatmaFormat(strings, Locale(strings.localeName), khatma.quran);
    final parts = heldParts?.call() ?? const <HeldPartReminder>[];
    final k = khatma.khatma;
    final wirds = khatma.wirds;
    final current = wirds.indexWhere((w) => !w.isRead);
    final todayRead = khatma.todayRead;
    final result = <KhatmaReminder>[];
    for (var d = 0; d < days; d++) {
      final day = today.addDays(d);
      final at = DateTime(day.year, day.month, day.day, setting.hour, setting.minute);
      if (!at.isAfter(now)) continue;
      final lines = <String>[];
      if (k != null && k.state == KhatmaState.active && current >= 0 && !day.isBefore(k.startDate)) {
        // One wird a day from the current one; when today is read, the current wird is tomorrow's.
        final ahead = k.startDate.isAfter(today) ? day.daysSince(k.startDate) : (todayRead ? d - 1 : d);
        final i = current + ahead;
        final skipToday = d == 0 && (todayRead || khatma.currentWirdOnScreen);
        if (!skipToday && ahead >= 0 && i < wirds.length) {
          final w = wirds[i];
          lines.add(strings.khatmaReminderBody(
              f.name(khatma.nameOf(w)), f.pageRange(khatma.firstPageOf(w), khatma.lastPageOf(w))));
        }
      }
      for (final p in parts) {
        lines.add(strings.khatmaPartReminder(p.title, p.partName));
      }
      if (lines.isEmpty) continue;
      result.add(KhatmaReminder(
        id: idFor(day),
        atUtc: at.toUtc(),
        title: strings.khatmaTodaysWird,
        body: lines.join('\n'),
      ));
    }
    return result;
  }

  /// Turns the reminder on at [hour]:[minute], asking for permission now if it was never asked
  /// (FR-020). The choice is kept even when notifications are refused.
  Future<void> turnOn({int? hour, int? minute}) async {
    var status = await platform.status();
    if (status.permission == ReminderPermission.notDetermined ||
        status.permission == ReminderPermission.denied) {
      status = await platform.requestPermission();
    }
    _status = status;
    await khatma.setReminder(khatma.reminder.copyWith(on: true, hour: hour, minute: minute));
    notifyListeners();
    await sync();
  }

  Future<void> turnOff() async {
    await khatma.setReminder(khatma.reminder.copyWith(on: false));
    await sync();
  }

  Future<void> setTime(int hour, int minute) async {
    await khatma.setReminder(khatma.reminder.copyWith(hour: hour, minute: minute));
    await sync();
  }

  Future<void> openSettings() => platform.openSettings();

  /// Whether a reminder launched the app.
  Future<bool> takeLaunchOpen() => platform.takeLaunchOpen();

  @override
  void dispose() {
    if (_started) {
      khatma.removeListener(sync);
      khatma.reader.removeListener(_onReader);
    }
    _opened.close();
    super.dispose();
  }
}

/// Provides the [KhatmaReminders] to the widget tree.
class KhatmaRemindersScope extends InheritedNotifier<KhatmaReminders> {
  const KhatmaRemindersScope({super.key, required KhatmaReminders reminders, required super.child})
      : super(notifier: reminders);

  static KhatmaReminders? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KhatmaRemindersScope>()?.notifier;
}
