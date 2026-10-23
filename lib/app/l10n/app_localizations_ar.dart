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

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get openSettings => 'افتح الإعدادات';

  @override
  String get layoutSetting => 'طريقة العرض';

  @override
  String get layoutMushaf => 'صفحات المصحف';

  @override
  String get layoutFlowing => 'نص متصل';

  @override
  String get switchToFlowing => 'اعرض النص المتصل';

  @override
  String get switchToMushaf => 'اعرض صفحات المصحف';

  @override
  String get themeSetting => 'المظهر';

  @override
  String get themeSystem => 'حسب الجهاز';

  @override
  String get themeDay => 'نهاري';

  @override
  String get themeNight => 'ليلي';

  @override
  String get textSizeSetting => 'حجم خط المصحف';

  @override
  String get textSizeHint => 'يُطبَّق على النص المتصل.';

  @override
  String get keepScreenOnSetting => 'إبقاء الشاشة مضاءة';

  @override
  String get keepScreenOnHint => 'تبقى الشاشة مضاءة ما دام المصحف مفتوحاً.';

  @override
  String get languageSetting => 'اللغة';

  @override
  String get languageSystem => 'حسب الجهاز';

  @override
  String get aboutTitle => 'عن التطبيق';

  @override
  String versionLabel(String version) {
    return 'الإصدار $version';
  }

  @override
  String get sourcesTitle => 'المصادر';

  @override
  String get tanzilCredit => 'نص القرآن الكريم مُتحقَّق منه مقابل مشروع تنزيل';

  @override
  String get qulCredit => 'توزيع صفحات المصحف: المكتبة القرآنية الشاملة (QUL)';

  @override
  String get kfgqpcCredit =>
      'مصحف المدينة: مجمع الملك فهد لطباعة المصحف الشريف';

  @override
  String get licencesButton => 'تراخيص البرمجيات المفتوحة';

  @override
  String get copyAyah => 'انسخ';

  @override
  String get shareAyah => 'شارك';

  @override
  String get bookmarkAyah => 'احفظ';

  @override
  String get ayahCopied => 'نُسخت الآية.';

  @override
  String get searchTitle => 'البحث';

  @override
  String get openSearch => 'ابحث في القرآن الكريم';

  @override
  String get searchHint => 'اكتب كلمة أو عبارة';

  @override
  String get searchEmptyHint => 'ابحث في نص القرآن الكريم بالتشكيل أو بدونه.';

  @override
  String get searchNoResults => 'لا توجد نتائج.';

  @override
  String searchAyatCount(int ayat, String ayatShown) {
    String _temp0 = intl.Intl.pluralLogic(
      ayat,
      locale: localeName,
      other: '$ayatShown آية',
      many: '$ayatShown آية',
      few: '$ayatShown آيات',
      two: 'آيتان',
      one: 'آية واحدة',
    );
    return '$_temp0';
  }

  @override
  String searchSummary(
    int occurrences,
    String occurrencesShown,
    int ayat,
    String ayatShown,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      occurrences,
      locale: localeName,
      other: '$occurrencesShown موضع',
      many: '$occurrencesShown موضعًا',
      few: '$occurrencesShown مواضع',
      two: 'موضعان',
      one: 'موضع واحد',
    );
    String _temp1 = intl.Intl.pluralLogic(
      ayat,
      locale: localeName,
      other: '$ayatShown آية',
      many: '$ayatShown آية',
      few: '$ayatShown آيات',
      two: 'آيتين',
      one: 'آية واحدة',
    );
    return '$_temp0 في $_temp1';
  }

  @override
  String get clearSearch => 'امسح';

  @override
  String get controlsHint => 'اضغط على الصفحة لإظهار الأدوات';

  @override
  String get showControls => 'إظهار الأدوات';

  @override
  String get printedLetteringSetting => 'خط المصحف المطبوع';

  @override
  String get printedLetteringHint =>
      'حروف مصحف المدينة كما طبعها مجمع الملك فهد. أطفئه لاستخدام الخط المدمج.';

  @override
  String get listen => 'استمع';

  @override
  String get playFromAyah => 'تشغيل من هذه الآية';

  @override
  String get recitationPlayer => 'مشغّل التلاوة';

  @override
  String recitedAyah(String name, String ref) {
    return 'سورة $name · $ref';
  }

  @override
  String recitedBasmala(String name) {
    return 'سورة $name · البسملة';
  }

  @override
  String get basmala => 'البسملة';

  @override
  String get murattal => 'مرتّل';

  @override
  String get reciter => 'القارئ';

  @override
  String get chooseReciter => 'اختر القارئ';

  @override
  String get recitations => 'التلاوات';

  @override
  String get playRecitation => 'تشغيل';

  @override
  String get pauseRecitation => 'إيقاف مؤقت';

  @override
  String get previousAyah => 'الآية السابقة';

  @override
  String get nextAyah => 'الآية التالية';

  @override
  String get closePlayer => 'إيقاف وإغلاق';

  @override
  String get recitationOffline =>
      'لا يوجد اتصال. نزّل السورة للاستماع دون إنترنت.';

  @override
  String get recitationFetchFailed => 'تعذّر تحميل الآية.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String reciterNotDownloaded(String name) {
    return '$name غير منزّل لهذه السورة';
  }

  @override
  String get recitationEnded => 'انتهت التلاوة';

  @override
  String get backToRecitation => 'العودة إلى التلاوة';

  @override
  String get download => 'تنزيل';

  @override
  String get downloads => 'التنزيلات';

  @override
  String downloadRecitation(String size) {
    return 'تنزيل التلاوة ($size)';
  }

  @override
  String get stopDownload => 'إيقاف التنزيل';

  @override
  String get deleteDownload => 'حذف التنزيل';

  @override
  String get deleteAll => 'حذف الكل';

  @override
  String deleteAllConfirm(String name) {
    return 'حذف كل تنزيلات $name؟';
  }

  @override
  String get waiting => 'في الانتظار';

  @override
  String get stoppedResume => 'متوقف — استئناف';

  @override
  String get resume => 'استئناف';

  @override
  String get stopReasonNoConnection => 'لا يوجد اتصال';

  @override
  String get stopReasonNoStorage => 'المساحة غير كافية';

  @override
  String get stopReasonFailed => 'تعذّر التنزيل';

  @override
  String get downloaded => 'منزّلة';

  @override
  String get surahOptions => 'خيارات السورة';

  @override
  String get downloadsEmpty => 'لم تنزّل أي سورة بعد. نزّل سورة من فهرس السور.';

  @override
  String downloadOnMobileData(String size) {
    return 'أنت على بيانات الجوال. تنزيل $size؟';
  }

  @override
  String notEnoughStorage(String size) {
    return 'المساحة غير كافية: تحتاج $size';
  }

  @override
  String get noInternet => 'لا يوجد اتصال بالإنترنت';

  @override
  String get clearRecent => 'مسح التلاوات المؤقتة';

  @override
  String clearRecentConfirm(String size) {
    return 'حذف الآيات التي استمعت إليها مؤخرًا ($size)؟ تبقى التنزيلات.';
  }

  @override
  String spaceFreed(String size) {
    return 'تم تحرير $size';
  }

  @override
  String sizeMb(String n) {
    return '$n م.ب';
  }

  @override
  String sizeKb(String n) {
    return '$n ك.ب';
  }

  @override
  String get recitationChannel => 'التلاوة';

  @override
  String get recitationAttribution =>
      'التلاوات: الشيخ محمود خليل الحصري والشيخ محمد صديق المنشاوي (مرتّل)، عن EveryAyah.com';
}
