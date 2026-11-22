import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:intl/intl.dart' show DateFormat;
import 'package:timezone/timezone.dart' as tz;

import '../../app/l10n/app_localizations.dart';
import '../../shared/numerals.dart';
import '../prayer_times/prayer_calculator.dart';
import '../prayer_times/prayer_copy.dart';
import '../prayer_times/prayer_models.dart';
import '../prayer_times/prayer_time_zones.dart';

/// What every home screen, lock screen and watch widget shows (specs/017 data-model.md,
/// contracts/widget-snapshot.md). Text is already in the app's language and digits, so native
/// code only lays it out (research R1). Nothing typed by another person is ever in it (FR-003).
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.madeAtUtc,
    required this.lang,
    required this.labels,
    required this.prayer,
    required this.quran,
  });

  static const version = 1;

  /// Largest snapshot (and watch copy) the native sides accept.
  static const maxBytes = 16 * 1024;

  final DateTime madeAtUtc;

  /// `ar` or `en`.
  final String lang;
  final WidgetLabels labels;

  /// Null when no place is set: the "not set up" state.
  final PrayerBlock? prayer;
  final QuranBlock quran;

  bool get rtl => lang == 'ar';

  Map<String, Object?> toJson() => {
    'v': version,
    'madeAtUtc': madeAtUtc.millisecondsSinceEpoch,
    'lang': lang,
    'rtl': rtl,
    'labels': labels.toJson(),
    'prayer': prayer?.toJson(),
    'quran': quran.toJson(),
  };

  /// The part sent to the watches (data-model.md › WatchCopy): prayer times and khatma progress,
  /// never the reading place or the wird's ayat.
  Map<String, Object?> watchJson() {
    final progress = quran.progress;
    return {
      'v': version,
      'madeAtUtc': madeAtUtc.millisecondsSinceEpoch,
      'lang': lang,
      'rtl': rtl,
      'labels': labels.watchJson(),
      'prayer': prayer?.toJson(),
      'khatma': progress == null
          ? null
          : {
              'percent': progress.percent,
              'todayRead': progress.todayRead,
              'paused': progress.paused,
              'text': progress.text,
            },
    };
  }

  /// The JSON for the channel; asserts the size limit.
  String encode() => _encode(toJson());
  String encodeWatch() => _encode(watchJson());

  static String _encode(Map<String, Object?> json) {
    final text = jsonEncode(json);
    assert(utf8.encode(text).length <= maxBytes, 'Widget snapshot over $maxBytes bytes');
    return text;
  }
}

/// Fixed texts of the widgets, in the app's language (data-model.md › Labels).
class WidgetLabels {
  const WidgetLabels({
    required this.next,
    required this.inPrefix,
    required this.inSuffix,
    required this.todaysWird,
    required this.todayWirdDone,
    required this.continueReading,
    required this.startReading,
    required this.setPlace,
    required this.setPlaceWatch,
    required this.openToUpdate,
    required this.khatma,
    required this.noKhatma,
    required this.paused,
    required this.a11yNext,
  });

  factory WidgetLabels.of(AppLocalizations l) {
    // "in {left}" split around the countdown, which native code draws.
    const mark = '\u0000';
    final around = l.widgetIn(mark).split(mark);
    return WidgetLabels(
      next: l.prayerNext,
      inPrefix: around.first,
      inSuffix: around.length > 1 ? around.last : '',
      todaysWird: l.khatmaTodaysWird,
      todayWirdDone: l.khatmaTodayDone,
      continueReading: l.widgetContinueReading,
      startReading: l.widgetStartReading,
      setPlace: l.widgetSetPlace,
      setPlaceWatch: l.widgetSetPlaceWatch,
      openToUpdate: l.widgetOpenToUpdate,
      khatma: l.khatmaTitle,
      noKhatma: l.widgetNoKhatma,
      paused: l.widgetPaused,
      // Native code fills {name} and {time}.
      a11yNext: l.widgetA11yNext('{name}', '{time}'),
    );
  }

  final String next, inPrefix, inSuffix, todaysWird, todayWirdDone, continueReading;
  final String startReading, setPlace, setPlaceWatch, openToUpdate, khatma, noKhatma, paused;
  final String a11yNext;

  Map<String, Object?> toJson() => {
    'next': next,
    'inPrefix': inPrefix,
    'inSuffix': inSuffix,
    'todaysWird': todaysWird,
    'todayWirdDone': todayWirdDone,
    'continueReading': continueReading,
    'startReading': startReading,
    'setPlace': setPlace,
    'setPlaceWatch': setPlaceWatch,
    'openToUpdate': openToUpdate,
    'khatma': khatma,
    'noKhatma': noKhatma,
    'paused': paused,
    'a11yNext': a11yNext,
  };

  Map<String, Object?> watchJson() => {
    'next': next,
    'inPrefix': inPrefix,
    'inSuffix': inSuffix,
    'todayWirdDone': todayWirdDone,
    'setPlaceWatch': setPlaceWatch,
    'openToUpdate': openToUpdate,
    'khatma': khatma,
    'noKhatma': noKhatma,
    'paused': paused,
    'a11yNext': a11yNext,
  };
}

/// One prayer time on the widgets.
class PrayerEntry {
  const PrayerEntry({
    required this.kind,
    required this.atUtc,
    required this.name,
    required this.time,
  });
  final PrayerKind kind;
  final DateTime atUtc;

  /// Localized; Dhuhr is Jumu'ah on Fridays at the place (specs/015).
  final String name;

  /// Local time at the place, in the app's language, as Prayer Times shows it.
  final String time;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'atUtc': atUtc.millisecondsSinceEpoch,
    'name': name,
    'time': time,
  };
}

/// One day of [PrayerBlock.entries]: when it starts at the place, and its label.
class WidgetDay {
  const WidgetDay({required this.startUtc, required this.label});
  final DateTime startUtc;
  final String label;

  Map<String, Object?> toJson() => {
    'startUtc': startUtc.millisecondsSinceEpoch,
    'label': label,
  };
}

/// The prayer times of today and the next 7 days (FR-011, FR-018).
class PrayerBlock {
  const PrayerBlock({
    required this.place,
    required this.entries,
    required this.days,
    required this.validUntilUtc,
  });

  /// Days covered: today and 7 more.
  static const dayCount = 8;
  static const maxPlaceLength = 80;

  final String place;

  /// Ascending, each instant unique; sunrise and unavailable times are left out.
  final List<PrayerEntry> entries;
  final List<WidgetDay> days;

  /// The last entry plus a minute. After it, widgets show "Open Mathani to update" (FR-008).
  final DateTime validUntilUtc;

  /// The first entry after [now]: the one rule every platform implements.
  PrayerEntry? nextAfter(DateTime now) {
    for (final e in entries) {
      if (e.atUtc.isAfter(now)) return e;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'place': place,
    'validUntilUtc': validUntilUtc.millisecondsSinceEpoch,
    'days': [for (final d in days) d.toJson()],
    'entries': [for (final e in entries) e.toJson()],
  };
}

/// The five daily prayers, in the order of the day.
const widgetPrayers = [
  PrayerKind.fajr,
  PrayerKind.dhuhr,
  PrayerKind.asr,
  PrayerKind.maghrib,
  PrayerKind.isha,
];

/// The prayer block for [place], or null when there is no place or nothing could be calculated.
PrayerBlock? buildPrayerBlock({
  required Place? place,
  required PrayerCalculator calculator,
  required AppLocalizations l10n,
  required DateTime nowUtc,
}) {
  if (place == null) return null;
  final lang = l10n.localeName == 'ar' ? 'ar' : 'en';
  final zone = prayerTimeZone(place.timezoneId);
  final time = DateFormat.jm(lang);
  final weekday = DateFormat.EEEE(lang);
  final today = PrayerCalculator.localDay(place, nowUtc);
  final entries = <PrayerEntry>[];
  final days = <WidgetDay>[];
  for (var offset = 0; offset < PrayerBlock.dayCount; offset++) {
    final date = today.add(Duration(days: offset));
    final start = tz.TZDateTime(zone, date.year, date.month, date.day);
    days.add(WidgetDay(
      startUtc: start.toUtc(),
      label: offset == 0 ? l10n.prayerToday : weekday.format(start),
    ));
    final schedule = calculator.schedule(place, date);
    for (final kind in widgetPrayers) {
      final at = schedule.event(kind).atUtc;
      if (at == null) continue;
      if (entries.isNotEmpty && !at.isAfter(entries.last.atUtc)) continue;
      entries.add(PrayerEntry(
        kind: kind,
        atUtc: at.toUtc(),
        name: prayerName(l10n, kind, friday: schedule.isFriday),
        time: time.format(tz.TZDateTime.from(at, zone)),
      ));
    }
  }
  if (entries.isEmpty) return null;
  final name = place.name.length > PrayerBlock.maxPlaceLength
      ? place.name.substring(0, PrayerBlock.maxPlaceLength)
      : place.name;
  return PrayerBlock(
    place: name,
    entries: entries,
    days: days,
    validUntilUtc: entries.last.atUtc.add(const Duration(minutes: 1)),
  );
}

/// What the Quran widget shows (data-model.md › QuranBlock).
enum QuranMode {
  wird('wird'),
  wirdDone('wirdDone'),
  continueReading('continue'),
  start('start');

  const QuranMode(this.wire);
  final String wire;
}

/// Taps open these links (contracts/widget-surfaces.md › Links).
abstract final class WidgetLinks {
  static const scheme = 'mathani-widget';
  static const prayer = '$scheme://prayer';
  static const khatma = '$scheme://khatma';
  static const khatmaRead = '$scheme://khatma/read';
  static String mushaf(int page) => '$scheme://mushaf/$page';
}

class KhatmaProgress {
  const KhatmaProgress({
    required this.percent,
    required this.pagesRead,
    required this.pagesTotal,
    required this.text,
    required this.todayRead,
    required this.paused,
  });
  final int percent, pagesRead, pagesTotal;
  final String text;
  final bool todayRead, paused;

  Map<String, Object?> toJson() => {
    'percent': percent,
    'pagesRead': pagesRead,
    'pagesTotal': pagesTotal,
    'text': text,
    'todayRead': todayRead,
    'paused': paused,
  };
}

class QuranBlock {
  const QuranBlock({
    required this.mode,
    required this.title,
    required this.line1,
    required this.line2,
    required this.progress,
    required this.link,
  });
  final QuranMode mode;
  final String title, line1, line2;
  final KhatmaProgress? progress;
  final String link;

  Map<String, Object?> toJson() => {
    'mode': mode.wire,
    'title': title,
    'line1': line1,
    'line2': line2,
    'progress': progress?.toJson(),
    'link': link,
  };
}

/// The reader's khatma and place, already turned into text, for [buildQuranBlock]. Group khatmas
/// are not part of it (FR-003).
class QuranInput {
  const QuranInput({
    required this.page,
    this.surahName = '',
    this.juz = 1,
    this.khatma,
  });

  /// The page the reader was last on; 1 with nothing read yet.
  final int page;
  final String surahName;
  final int juz;
  final KhatmaInput? khatma;
}

/// The personal khatma, active or paused.
class KhatmaInput {
  const KhatmaInput({
    required this.paused,
    required this.todayRead,
    required this.pagesRead,
    required this.pagesTotal,
    this.wirdFrom,
    this.wirdTo,
  });
  final bool paused, todayRead;
  final int pagesRead, pagesTotal;

  /// The current wird's first and last ayah, as "Al-Baqarah 142"; null when none is waiting.
  final String? wirdFrom, wirdTo;
}

QuranBlock buildQuranBlock(QuranInput input, AppLocalizations l10n) {
  final locale = Locale(l10n.localeName == 'ar' ? 'ar' : 'en');
  String n(int value) => formatNumber(value, locale);
  final k = input.khatma;
  KhatmaProgress? progress;
  if (k != null) {
    final total = k.pagesTotal < 1 ? 1 : k.pagesTotal;
    final read = k.pagesRead.clamp(0, total);
    final percent = (read * 100 / total).floor().clamp(0, 100);
    final text = l10n.widgetProgress(n(percent), n(read), n(total));
    progress = KhatmaProgress(
      percent: percent,
      pagesRead: read,
      pagesTotal: total,
      text: k.paused ? '$text · ${l10n.widgetPaused}' : text,
      todayRead: k.todayRead,
      paused: k.paused,
    );
  }
  final place =
      '${l10n.pageLabel(n(input.page))} · ${l10n.juzLabel(n(input.juz))}';
  if (k != null && !k.paused) {
    if (k.todayRead || k.wirdFrom == null) {
      return QuranBlock(
        mode: QuranMode.wirdDone,
        title: l10n.khatmaTodayDone,
        line1: '',
        line2: '',
        progress: progress,
        link: WidgetLinks.khatma,
      );
    }
    return QuranBlock(
      mode: QuranMode.wird,
      title: l10n.khatmaTodaysWird,
      line1: l10n.widgetWirdFrom(k.wirdFrom!),
      line2: l10n.widgetWirdTo(k.wirdTo ?? k.wirdFrom!),
      progress: progress,
      link: WidgetLinks.khatmaRead,
    );
  }
  if (input.page <= 1 && k == null) {
    return QuranBlock(
      mode: QuranMode.start,
      title: l10n.widgetStartReading,
      line1: '',
      line2: '',
      progress: null,
      link: WidgetLinks.mushaf(1),
    );
  }
  return QuranBlock(
    mode: QuranMode.continueReading,
    title: l10n.widgetContinueReading,
    line1: input.surahName,
    line2: place,
    progress: progress,
    link: WidgetLinks.mushaf(input.page),
  );
}

/// The whole snapshot from already-gathered parts.
WidgetSnapshot buildWidgetSnapshot({
  required AppLocalizations l10n,
  required DateTime nowUtc,
  required PrayerBlock? prayer,
  required QuranInput quran,
}) => WidgetSnapshot(
  madeAtUtc: nowUtc,
  lang: l10n.localeName == 'ar' ? 'ar' : 'en',
  labels: WidgetLabels.of(l10n),
  prayer: prayer,
  quran: buildQuranBlock(quran, l10n),
);
