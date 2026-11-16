import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../app/l10n/app_localizations.dart';
import '../../data/quran_repository.dart';
import '../../shared/numerals.dart';
import 'khatma_division.dart';
import 'khatma_models.dart';

/// Texts of the khatma screens, in the interface language (FR-040).
class KhatmaFormat {
  KhatmaFormat(this.l10n, this.locale, this.quran);

  factory KhatmaFormat.of(BuildContext context, QuranRepository quran) =>
      KhatmaFormat(AppLocalizations.of(context), Localizations.localeOf(context), quran);

  final AppLocalizations l10n;
  final Locale locale;
  final QuranRepository quran;

  bool get arabic => locale.languageCode == 'ar';

  String number(int n) => formatNumber(n, locale);

  String date(CalendarDay d) => DateFormat.yMMMd(locale.toLanguageTag()).format(d.asDateTime);

  String pages(int count) => l10n.khatmaPageCount(count, number(count));

  String days(int count) => l10n.khatmaDaysCount(count, number(count));

  String name(WirdName n) => switch (n) {
        JuzName(:final juz) => l10n.juzLabel(number(juz)),
        HizbName(:final hizb) => l10n.khatmaHizb(number(hizb)),
        QuarterName(:final hizb, :final quarter) => l10n.khatmaQuarter(number(quarter), number(hizb)),
        NumberName(number: final n) => l10n.khatmaWirdNumber(number(n)),
      };

  /// "Al-Baqarah 253", or «البقرة ٢٥٣».
  String ayah(int ayahId) {
    final a = quran.ayahById(ayahId);
    final s = quran.surahList[a.surah - 1];
    return l10n.khatmaAyahRef(arabic ? s.nameAr : s.nameTranslit, number(a.ayah));
  }

  String range(int firstAyah, int lastAyah) => l10n.khatmaRange(ayah(firstAyah), ayah(lastAyah));

  String pageRange(int first, int last) =>
      first == last ? l10n.pageLabel(number(first)) : l10n.khatmaPagesRange(number(first), number(last));

  /// The plan, as the record shows it.
  String plan(KhatmaPlan p) => switch (p) {
        MarksPlan(:final quarters) => amount(quarters),
        SevenPlan() => l10n.khatmaSevenDays,
        DaysPlan(days: final d) => days(d),
      };

  String amount(int quarters) => switch (quarters) {
        1 => l10n.khatmaAmount1,
        2 => l10n.khatmaAmount2,
        4 => l10n.khatmaAmount4,
        8 => l10n.khatmaAmount8,
        16 => l10n.khatmaAmount16,
        24 => l10n.khatmaAmount24,
        _ => l10n.khatmaAmount80,
      };

  /// The plan sheet's summary line (FR-002).
  String summary(WirdPreview p) => p.fewestPages == p.mostPages
      ? l10n.khatmaSummaryOne(days(p.wirds), pages(p.fewestPages), date(p.finishDate))
      : l10n.khatmaSummaryRange(
          days(p.wirds), number(p.fewestPages), number(p.mostPages), date(p.finishDate));
}
