import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../app/l10n/app_localizations.dart';
import '../../shared/reader_state.dart';
import '../khatma/khatma_controller.dart';
import '../khatma/khatma_format.dart';
import '../prayer_times/prayer_alerts.dart';
import 'widget_snapshot.dart';

/// Sends a snapshot to the native widgets.
typedef WidgetSend = Future<void> Function(String snapshot, String watch);

/// Keeps the widgets in step with the app (specs/017 research R9): after any change to the
/// listened objects it waits [debounce], rebuilds the snapshot, and sends it only when what the
/// widgets show changed, so iOS reloads stay within their budget. Started after the first frame
/// (Principle III); it never runs before [start].
class WidgetSync with WidgetsBindingObserver {
  WidgetSync({
    required this.listenables,
    required this.l10n,
    required this.prayerBlock,
    required this.quranInput,
    required this.send,
    this.debounce = const Duration(seconds: 2),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final List<Listenable> listenables;
  final AppLocalizations Function() l10n;
  final Future<PrayerBlock?> Function(AppLocalizations l10n, DateTime nowUtc) prayerBlock;
  final QuranInput Function(AppLocalizations l10n) quranInput;
  final WidgetSend send;
  final Duration debounce;
  final DateTime Function() clock;

  Timer? _timer;
  String? _lastShown;
  bool _started = false, _running = false, _again = false;

  /// Begins listening and sends the first snapshot.
  void start() {
    if (_started) return;
    _started = true;
    for (final l in listenables) {
      l.addListener(_changed);
    }
    WidgetsBinding.instance.addObserver(this);
    unawaited(flush());
  }

  void _changed() {
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || state == AppLifecycleState.paused) {
      unawaited(flush());
    }
  }

  /// Rebuilds now and sends if anything shown changed. Calls made while one runs are merged.
  Future<void> flush() async {
    _timer?.cancel();
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _build();
      } while (_again);
    } on Object catch (e) {
      // Widgets must never disturb the reader; the next change tries again.
      if (kDebugMode) debugPrint('WidgetSync: $e');
    } finally {
      _running = false;
    }
  }

  Future<void> _build() async {
    final strings = l10n();
    final lang = strings.localeName == 'ar' ? 'ar' : 'en';
    await initializeDateFormatting(lang);
    final now = clock().toUtc();
    final snapshot = buildWidgetSnapshot(
      l10n: strings,
      nowUtc: now,
      prayer: await prayerBlock(strings, now),
      quran: quranInput(strings),
    );
    // What the widgets show, without the time it was made.
    final json = snapshot.toJson()..remove('madeAtUtc');
    final shown = jsonEncode(json);
    if (shown == _lastShown) return;
    await send(snapshot.encode(), snapshot.encodeWatch());
    _lastShown = shown;
  }

  void dispose() {
    _timer?.cancel();
    if (!_started) return;
    for (final l in listenables) {
      l.removeListener(_changed);
    }
    WidgetsBinding.instance.removeObserver(this);
  }
}

/// Reports which widgets are on the phone at most once per calendar day (specs/017 SC-007,
/// contracts/widget-surfaces.md › Usage). [readDay] and [writeDay] keep the last reported day.
Future<void> reportWidgetsOncePerDay({
  required Future<List<String>> Function() placed,
  required void Function(List<String> kinds) report,
  required Future<String?> Function() readDay,
  required Future<void> Function(String day) writeDay,
  DateTime Function()? clock,
}) async {
  try {
    final now = (clock ?? DateTime.now)();
    final day = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (await readDay() == day) return;
    report(await placed());
    await writeDay(day);
  } on Object {
    /* statistics never disturb the reader */
  }
}

/// The prayer block for the place in use, from the app's prayer state (specs/009).
Future<PrayerBlock?> prayerBlockOf(
  PrayerAlerts prayer,
  AppLocalizations l10n,
  DateTime nowUtc,
) async {
  final state = await prayer.state();
  final place = state.currentPlace;
  if (place == null) return null;
  final services = await prayer.services();
  return buildPrayerBlock(
    place: place,
    calculator: services.calculator,
    l10n: l10n,
    nowUtc: nowUtc,
  );
}

/// The reader's place and personal khatma, as text (data-model.md › QuranBlock).
QuranInput quranInputOf(
  ReaderController reader,
  KhatmaController? khatma,
  AppLocalizations l10n,
) {
  final quran = reader.quran;
  final head = reader.pageHead;
  final surah = quran.surahList[head.surah - 1];
  final arabic = l10n.localeName == 'ar';
  KhatmaInput? k;
  if (khatma != null && khatma.loaded && (khatma.isActive || khatma.isPaused)) {
    final format = KhatmaFormat(l10n, Locale(arabic ? 'ar' : 'en'), quran);
    final wird = khatma.currentWird;
    k = KhatmaInput(
      paused: khatma.isPaused,
      todayRead: khatma.todayRead,
      pagesRead: khatma.pagesRead,
      pagesTotal: khatma.pagesTotal,
      wirdFrom: wird == null ? null : format.ayah(wird.firstAyah),
      wirdTo: wird == null ? null : format.ayah(wird.lastAyah),
    );
  }
  return QuranInput(
    page: reader.page,
    surahName: arabic ? surah.nameAr : surah.nameTranslit,
    juz: head.juz,
    khatma: k,
  );
}
