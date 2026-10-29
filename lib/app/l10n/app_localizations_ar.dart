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
      'التلاوات: القرّاء المذكورون في قائمة القرّاء، عن EveryAyah.com وquranicaudio.com';

  @override
  String get onboardingWelcome => 'أهلاً بك في مثاني';

  @override
  String get onboardingLanguageTitle => 'اختر لغة التطبيق';

  @override
  String onboardingSystemLanguage(String language) {
    return 'حسب الجهاز ($language)';
  }

  @override
  String get onboardingThemeTitle => 'كيف تحب أن يبدو المصحف؟';

  @override
  String get onboardingLayoutTitle => 'كيف تحب أن تقرأ؟';

  @override
  String get onboardingLayoutMushafHint => 'الصفحات كما طُبعت في مصحف المدينة';

  @override
  String get onboardingLayoutFlowingHint => 'نص متصل يمكنك تكبير خطه';

  @override
  String get onboardingTextSizeTitle => 'اختر حجم الخط';

  @override
  String get onboardingReciterTitle => 'لمن تحب أن تستمع؟';

  @override
  String get onboardingReciterHint =>
      'يمكنك تغيير القارئ في أي وقت من المشغّل أو الإعدادات.';

  @override
  String get playSample => 'استمع إلى مقطع';

  @override
  String get stopSample => 'أوقف المقطع';

  @override
  String get sampleOffline =>
      'تحتاج المقاطع إلى اتصال بالإنترنت، ويمكنك الاختيار دونها.';

  @override
  String onboardingStep(String index, String total) {
    return 'الخطوة $index من $total';
  }

  @override
  String tourProgress(String index, String total) {
    return '$index من $total';
  }

  @override
  String get onboardingNext => 'التالي';

  @override
  String get onboardingBack => 'السابق';

  @override
  String get onboardingSkip => 'تخطَّ';

  @override
  String get tourDone => 'تم';

  @override
  String get tourTurnPagesTitle => 'قلّب الصفحات';

  @override
  String get tourTurnPagesMushaf =>
      'اسحب الصفحة لتقلبها كما تقلّب صفحات المصحف المطبوع.';

  @override
  String get tourTurnPagesFlowing =>
      'مرّر الشاشة لتتابع القراءة؛ النص متصل من سورة إلى أخرى.';

  @override
  String get tourControlsTitle => 'أدوات التحكم';

  @override
  String get tourControlsMushaf =>
      'انقر على الصفحة لإظهار أدوات التحكم أو إخفائها.';

  @override
  String get tourControlsFlowing =>
      'تبقى أدوات التحكم في أعلى الشاشة وأسفلها. وفي عرض صفحات المصحف انقر على الصفحة لإظهارها.';

  @override
  String get tourAyahTitle => 'خيارات الآية';

  @override
  String get tourAyahBody =>
      'اضغط مطولاً على آية لتستمع منها أو تحفظها أو تنسخها أو تشاركها.';

  @override
  String get tourIndexTitle => 'الفهرس';

  @override
  String get tourIndexBody =>
      'السور والأجزاء ومحفوظاتك، ومنها تنتقل إلى أي موضع.';

  @override
  String get tourSearchTitle => 'البحث';

  @override
  String get tourSearchBody => 'ابحث في نص القرآن الكريم بالتشكيل أو دونه.';

  @override
  String get tourPlayerTitle => 'الاستماع';

  @override
  String get tourPlayerBody =>
      'استمع آية آية مع تظليل الآية المتلوّة. ونزّل السور من فهرس السور أو من المشغّل لتستمع دون اتصال.';

  @override
  String get tourSettingsTitle => 'الإعدادات';

  @override
  String get tourSettingsBody =>
      'غيّر اختياراتك متى شئت، وستجد المزيد: إبقاء الشاشة مضاءة، وخط المصحف المطبوع، والتنزيلات، وهذه الجولة.';

  @override
  String get tourAgainSetting => 'شاهد الجولة التعريفية مرة أخرى';

  @override
  String get tourAgainHint =>
      'كيف تقلّب الصفحات وتستخدم خيارات الآية والفهرس والبحث والمشغّل.';

  @override
  String get mujawwad => 'مجوّد';

  @override
  String get muallim => 'معلّم';

  @override
  String get searchReciters => 'ابحث عن قارئ';

  @override
  String get noReciterFound => 'لا يوجد قارئ بهذا الاسم';

  @override
  String get qulRecitationsCredit =>
      'توقيت الآيات وبعض التلاوات: مكتبة القرآن الشاملة (QUL)';

  @override
  String get memorize => 'الحفظ';

  @override
  String get memorizeFromAyah => 'احفظ من هذه الآية';

  @override
  String get memorizeTitle => 'اختبر حفظك';

  @override
  String get memorizeFrom => 'من الآية';

  @override
  String get memorizeTo => 'إلى الآية';

  @override
  String memorizeSummary(String ayat, String pages) {
    return '$ayat · $pages';
  }

  @override
  String memorizePage(String page) {
    return 'الصفحة $page';
  }

  @override
  String memorizePages(String from, String to) {
    return 'الصفحات $from–$to';
  }

  @override
  String memorizeModelNeeded(String size) {
    return 'يحتاج الحفظ إلى تنزيل نموذج التعرّف على التلاوة مرة واحدة ($size). بعدها يعمل دون اتصال.';
  }

  @override
  String memorizeModelDownloading(String percent) {
    return 'يُنزَّل النموذج… $percent٪';
  }

  @override
  String get memorizeModelFailed => 'تعذّر تنزيل النموذج. حاول مرة أخرى.';

  @override
  String get memorizeStart => 'ابدأ';

  @override
  String get memorizeUnsupported => 'الحفظ غير متاح على هذا الجهاز';

  @override
  String get memorizeUnsupported64 => 'يحتاج معالجًا بنظام ٦٤ بت.';

  @override
  String get memorizeUnsupportedMemory => 'يحتاج ذاكرة ٣ غيغابايت على الأقل.';

  @override
  String get micExplainerTitle => 'الميكروفون للمتابعة فقط';

  @override
  String get micExplainerBody =>
      'يستمع مثاني إلى تلاوتك ليُظهر كل آية حين تتمها. يجري ذلك على جهازك فقط، ولا يُسجَّل صوتك ولا يُرسل.';

  @override
  String get micExplainerContinue => 'متابعة';

  @override
  String get micDenied => 'لا يمكن بدء الحفظ دون الميكروفون.';

  @override
  String get memorizeListening => 'يستمع';

  @override
  String get memorizeMicOn => 'الميكروفون يعمل';

  @override
  String get memorizePreparing => 'يجهّز…';

  @override
  String get memorizePaused => 'متوقف';

  @override
  String get memorizePausedSilence => 'توقّف الاستماع بعد ٣٠ ثانية من الصمت';

  @override
  String get memorizePausedInterruption => 'توقّف بسبب مكالمة أو صوت آخر';

  @override
  String get memorizePausedBackground => 'توقّف حين غادرت التطبيق';

  @override
  String get memorizePausedRoute => 'انقطع الميكروفون';

  @override
  String memorizeProgress(String n, String total) {
    return 'الآية $n من $total';
  }

  @override
  String get memorizePause => 'إيقاف مؤقت';

  @override
  String get memorizeResume => 'استئناف';

  @override
  String get memorizeNextWord => 'الكلمة التالية';

  @override
  String get memorizeShowAyah => 'أظهر الآية';

  @override
  String get memorizeEnd => 'إنهاء';

  @override
  String get memorizeMistake => 'خطأ — تابع من الكلمة';

  @override
  String get memorizeBackToAyah => 'عُد إلى الآية';

  @override
  String memorizeHiddenAyah(String n) {
    return 'الآية $n، مخفية';
  }

  @override
  String memorizeRevealed(String n) {
    return 'ظهرت الآية $n';
  }

  @override
  String get resultTitle => 'نتيجة الحفظ';

  @override
  String get resultOutOf => 'من ١٠٠';

  @override
  String resultNoMistake(String n) {
    return 'دون خطأ $n';
  }

  @override
  String resultCorrected(String n) {
    return 'صُحّحت $n';
  }

  @override
  String resultHinted(String n) {
    return 'بتلميح $n';
  }

  @override
  String resultRevealedCount(String n) {
    return 'أُظهرت $n';
  }

  @override
  String resultNotReachedCount(String n) {
    return 'لم تُبلغ $n';
  }

  @override
  String resultReached(String reached, String total) {
    return 'بلغت $reached من $total';
  }

  @override
  String get resultRevealed => 'أُظهرت';

  @override
  String get resultNotReached => 'لم تُبلغ';

  @override
  String get resultNotFinished => 'لم تكتمل';

  @override
  String get resultMissed => 'فاتتك';

  @override
  String resultWrong(String heard) {
    return 'سُمعت «$heard»';
  }

  @override
  String get resultAdded => 'زيادة';

  @override
  String get resultTryAgain => 'أعد المحاولة';

  @override
  String get resultDone => 'تم';

  @override
  String get mistakeSignal => 'التنبيه عند الخطأ';

  @override
  String get mistakeSignalVibrate => 'اهتزاز';

  @override
  String get mistakeSignalSound => 'صوت';

  @override
  String get mistakeSignalNone => 'بدون';

  @override
  String get memorizationModel => 'نموذج الحفظ';

  @override
  String get deleteMemorizationModel => 'حذف نموذج الحفظ';

  @override
  String get tourMemorize =>
      'اختبر حفظك: تلُ من ذاكرتك وتظهر الآيات كلما أتممتها';

  @override
  String get openSystemSettings => 'فتح الإعدادات';

  @override
  String get webDataKeptHere =>
      'تُحفظ علاماتك وإعداداتك وتنزيلاتك في هذا المتصفح فقط.';

  @override
  String memorizationBrowserUnsupported(String browsers) {
    return 'الحفظ غير متاح في هذا المتصفح. يعمل في $browsers.';
  }

  @override
  String get micDeniedBrowser =>
      'اسمح باستخدام الميكروفون لهذا الموقع من إعدادات الموقع في متصفحك، ثم حاول مرة أخرى.';

  @override
  String get pageNeedsConnection =>
      'تحتاج هذه الصفحة إلى اتصال عند فتحها أول مرة.';

  @override
  String get prayerTimesTitle => 'مواقيت الصلاة';

  @override
  String get prayerAddLocation => 'اختيار الموقع';

  @override
  String get prayerDetectLocation => 'تحديد موقعي';

  @override
  String get prayerSearchCity => 'ابحث عن مدينة';

  @override
  String get prayerApproximateLocation => 'جرّب الموقع التقريبي';

  @override
  String get prayerLocationDisclosure =>
      'يُستخدم موقع الجهاز لتحديد مواقيت الصلاة فقط. لتحديد المكان والمنطقة الزمنية تُرسل الإحداثيات إلى مثاني/Cloudflare وGeoNames. يمكنك اختيار مدينة بدلًا من ذلك.';

  @override
  String get prayerIpDisclosure =>
      'يستخدم البحث التقريبي عنوان اتصالك لدى Cloudflare. قد تكون النتيجة غير دقيقة مع VPN. أكّد النتيجة أو غيّرها قبل الاستخدام.';

  @override
  String get prayerApproximate => 'موقع تقريبي';

  @override
  String get prayerConfirmLocation => 'استخدم هذا الموقع';

  @override
  String get prayerChangeLocation => 'تغيير الموقع';

  @override
  String get prayerCancel => 'إلغاء';

  @override
  String get prayerNoLocation => 'اختر موقعًا لعرض مواقيت الصلاة.';

  @override
  String get prayerNoResults => 'لا توجد مدن مطابقة. جرّب اسمًا آخر.';

  @override
  String get prayerUnavailable => 'غير متاح';

  @override
  String get prayerAdjusted => 'معدّل لخطوط العرض العليا';

  @override
  String get prayerNext => 'الصلاة القادمة';

  @override
  String get prayerFajr => 'الفجر';

  @override
  String get prayerSunrise => 'الشروق (للمعلومة فقط)';

  @override
  String get prayerDhuhr => 'الظهر';

  @override
  String get prayerAsr => 'العصر';

  @override
  String get prayerMaghrib => 'المغرب';

  @override
  String get prayerIsha => 'العشاء';

  @override
  String get prayerQiyam => 'قيام الليل';

  @override
  String get prayerMethod => 'طريقة الحساب';

  @override
  String get prayerMadhhab => 'مذهب حساب العصر';

  @override
  String get prayerMethodMwl => 'رابطة العالم الإسلامي';

  @override
  String get prayerMethodEgypt => 'الهيئة المصرية العامة للمساحة';

  @override
  String get prayerMethodKarachi => 'جامعة العلوم الإسلامية بكراتشي';

  @override
  String get prayerMethodMakkah => 'أم القرى، مكة';

  @override
  String get prayerMethodNorthAmerica => 'أمريكا الشمالية (ISNA)';

  @override
  String get prayerHanafi => 'حنفي';

  @override
  String get prayerShafii => 'شافعي';

  @override
  String get prayerMaliki => 'مالكي';

  @override
  String get prayerHanbali => 'حنبلي';

  @override
  String get prayerMiddleNight => 'منتصف الليل';

  @override
  String get prayerSeventhNight => 'سُبع الليل';

  @override
  String get prayerHighLatitude => 'قاعدة خطوط العرض العليا';

  @override
  String get prayerLocationDenied =>
      'لم يُسمح بالوصول إلى الموقع. يمكنك اختيار مدينة يدويًا.';

  @override
  String get prayerLocationUnavailable =>
      'موقع الجهاز غير متاح. اختر مدينة أو جرّب الموقع التقريبي.';

  @override
  String get prayerTimezoneUnavailable =>
      'تعذّر تحديد المنطقة الزمنية. اختر مدينة بدلًا من ذلك.';

  @override
  String get prayerOffline =>
      'يلزم اتصال لهذا البحث. تظل المواقع المحفوظة متاحة دون اتصال.';

  @override
  String get prayerStorageUnavailable =>
      'تعذّرت قراءة المواقع المحفوظة بأمان. أعد المحاولة أو تابع لهذه الجلسة دون تغيير البيانات المحفوظة.';

  @override
  String get prayerSessionOnly => 'استخدم لهذه الجلسة';

  @override
  String get prayerSessionNotice => 'تُحفظ التغييرات حتى إغلاق هذه الجلسة فقط.';

  @override
  String get prayerServiceUnavailable =>
      'البحث عن الموقع غير متاح. أعد المحاولة لاحقًا أو استخدم موقعًا محفوظًا.';

  @override
  String get prayerCalculationUnavailable =>
      'لا يمكن حساب المواقيت لهذا التاريخ وطريقة الحساب. لن يُجدول تنبيه للأوقات غير المتاحة.';

  @override
  String get prayerNeedsAttention =>
      'تحتاج إعدادات الصلاة المحفوظة إلى مراجعة. لم تتغير بياناتك المحفوظة.';

  @override
  String get prayerRetry => 'أعد المحاولة';

  @override
  String get prayerGeoNamesAttribution => 'بيانات الأماكن: GeoNames';

  @override
  String get prayerSavedLocations => 'المواقع المحفوظة';

  @override
  String get prayerNewLocation => 'إضافة موقع';

  @override
  String get prayerLocationLabel => 'اسم الموقع';

  @override
  String get prayerLabelError =>
      'أدخل من حرف واحد إلى ٨٠ حرفًا دون أسطر جديدة أو محارف تحكم.';

  @override
  String get prayerRename => 'إعادة التسمية';

  @override
  String get prayerViewLocation => 'عرض المواقيت';

  @override
  String get prayerUseForReminders => 'استخدام للتذكيرات';

  @override
  String get prayerActiveLocation => 'الموقع النشط للتذكيرات';

  @override
  String get prayerViewedLocation => 'تعرض موقعًا آخر';

  @override
  String get prayerDeleteLocation => 'حذف الموقع';

  @override
  String get prayerDeleteInactiveConfirm =>
      'هل تريد حذف هذا الموقع المحفوظ وإعدادات حسابه؟';

  @override
  String get prayerDeleteActiveConfirm =>
      'اختر موقعًا بديلًا للتذكيرات، أو احذف الموقع وأوقف جميع تذكيرات الصلاة.';

  @override
  String get prayerDeleteAndDisable => 'حذف وإيقاف التذكيرات';

  @override
  String get prayerReplaceAndDelete => 'استبدال وحذف';

  @override
  String get prayerReplacementLocation => 'الموقع البديل';

  @override
  String get prayerClearData => 'مسح بيانات الصلاة';

  @override
  String get prayerClearDataConfirm =>
      'هل تريد حذف جميع مواقع الصلاة وإعداداتها وإلغاء تذكيرات الصلاة؟ ستبقى علامات القرآن وموضع القراءة محفوظة.';

  @override
  String get prayerActivateConfirm =>
      'هل تريد استخدام هذا الموقع للتذكيرات؟ ستستخدم تذكيرات الصلاة القادمة إعدادات حسابه.';

  @override
  String get prayerCalculationSettings => 'إعدادات الحساب';

  @override
  String get prayerSave => 'حفظ';

  @override
  String get prayerSuggestedMethod => 'المقترح لهذا البلد';

  @override
  String get prayerAsrExplanation =>
      'تؤثر هذه المذاهب في وقت العصر فقط. يستخدم الحنفي معامل ظل ٢، ويستخدم الشافعي والمالكي والحنبلي معامل ١. يُحفظ اسم المذهب الذي تختاره.';

  @override
  String get prayerCalculationExplanation =>
      'اختر طريقة الحساب التي تتبعها. تُوضّح تعديلات خطوط العرض العليا، ولا تُستبدل المواقيت غير المتاحة بمواقيت تقديرية.';

  @override
  String get prayerNoActiveLocation => 'لا يوجد موقع نشط للتذكيرات';

  @override
  String get prayerReminderLocationHint =>
      'عرض مواقيت هذا الموقع لا يغيّر موقع التذكيرات.';

  @override
  String get prayerDelete => 'حذف';
}
