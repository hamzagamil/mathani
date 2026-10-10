// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'مثاني';

  @override
  String juzLabel(String number) {
    return 'الجزء $number';
  }

  @override
  String pageLabel(String number) {
    return 'صفحة $number';
  }

  @override
  String pageSemantics(String page, String surah) {
    return 'الصفحة $page، سورة $surah';
  }

  @override
  String get indexTitle => 'الفهرس';

  @override
  String get tabSurahs => 'السور';

  @override
  String get tabAjza => 'الأجزاء';

  @override
  String get openIndex => 'افتح الفهرس';

  @override
  String get goTo => 'انتقل إلى';

  @override
  String get goToPage => 'صفحة';

  @override
  String get goToSurahAyah => 'سورة وآية';

  @override
  String get pageField => 'رقم الصفحة';

  @override
  String get surahField => 'السورة';

  @override
  String get ayahField => 'رقم الآية';

  @override
  String get goButton => 'انتقل';

  @override
  String pageRangeError(String max) {
    return 'اكتب رقم صفحة من ١ إلى $max.';
  }

  @override
  String ayahRangeError(String max) {
    return 'اكتب رقم آية من ١ إلى $max.';
  }

  @override
  String ayahCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown آية',
      few: '$shown آيات',
      two: 'آيتان',
      one: 'آية واحدة',
    );
    return '$_temp0';
  }

  @override
  String get makki => 'مكية';

  @override
  String get madani => 'مدنية';

  @override
  String juzTitle(String number) {
    return 'الجزء $number';
  }

  @override
  String hizbStart(String number) {
    return 'الحزب $number';
  }

  @override
  String hizbQuarter(String number) {
    return 'ربع الحزب $number';
  }

  @override
  String hizbHalf(String number) {
    return 'نصف الحزب $number';
  }

  @override
  String hizbThreeQuarters(String number) {
    return 'ثلاثة أرباع الحزب $number';
  }

  @override
  String surahRowSemantics(String name, String count, String page) {
    return '$name، $count آية، صفحة $page';
  }

  @override
  String get tabBookmarks => 'المحفوظات';

  @override
  String get addBookmark => 'احفظ هذه الصفحة';

  @override
  String get removeBookmark => 'احذف العلامة';

  @override
  String get bookmarkAdded => 'حُفظت العلامة.';

  @override
  String get bookmarkRemoved => 'حُذفت العلامة.';

  @override
  String get bookmarksEmpty =>
      'لا توجد محفوظات بعد. اضغط رمز العلامة في أي صفحة لحفظ موضعك.';

  @override
  String bookmarkTitle(String surah, String ayah) {
    return 'سورة $surah، الآية $ayah';
  }

  @override
  String get deleteBookmark => 'احذف العلامة';
}
