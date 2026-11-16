// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Mathani';

  @override
  String juzLabel(String number) {
    return 'Juz $number';
  }

  @override
  String pageLabel(String number) {
    return 'Page $number';
  }

  @override
  String pagesLabel(String first, String second) {
    return 'Pages $first–$second';
  }

  @override
  String pageSemantics(String page, String surah) {
    return 'Page $page, Surah $surah';
  }

  @override
  String get indexTitle => 'Index';

  @override
  String get tabSurahs => 'Surahs';

  @override
  String get tabAjza => 'Ajza\'';

  @override
  String get openIndex => 'Open index';

  @override
  String get goTo => 'Go to';

  @override
  String get goToPage => 'Page';

  @override
  String get goToSurahAyah => 'Surah and ayah';

  @override
  String get pageField => 'Page number';

  @override
  String get surahField => 'Surah';

  @override
  String get ayahField => 'Ayah number';

  @override
  String get goButton => 'Go';

  @override
  String pageRangeError(String max) {
    return 'Enter a page from 1 to $max.';
  }

  @override
  String ayahRangeError(String max) {
    return 'Enter an ayah from 1 to $max.';
  }

  @override
  String ayahCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown ayat',
      one: '$shown ayah',
    );
    return '$_temp0';
  }

  @override
  String get makki => 'Makki';

  @override
  String get madani => 'Madani';

  @override
  String juzTitle(String number) {
    return 'Juz $number';
  }

  @override
  String hizbStart(String number) {
    return 'Hizb $number';
  }

  @override
  String hizbQuarter(String number) {
    return '¼ Hizb $number';
  }

  @override
  String hizbHalf(String number) {
    return '½ Hizb $number';
  }

  @override
  String hizbThreeQuarters(String number) {
    return '¾ Hizb $number';
  }

  @override
  String surahRowSemantics(String name, String count, String page) {
    return '$name, $count ayat, page $page';
  }

  @override
  String get tabBookmarks => 'Bookmarks';

  @override
  String get addBookmark => 'Bookmark this page';

  @override
  String get removeBookmark => 'Remove bookmark';

  @override
  String get bookmarkAdded => 'Bookmark added.';

  @override
  String get bookmarkRemoved => 'Bookmark removed.';

  @override
  String get bookmarksEmpty =>
      'No bookmarks yet. Tap the bookmark icon on a page to save your place.';

  @override
  String bookmarkTitle(String surah, String ayah) {
    return 'Surah $surah, ayah $ayah';
  }

  @override
  String get deleteBookmark => 'Delete bookmark';

  @override
  String get bookmarkNoteAdd => 'Add note';

  @override
  String get bookmarkNoteEdit => 'Edit note';

  @override
  String get bookmarkNoteHint => 'Why you saved this place';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get openSettings => 'Open settings';

  @override
  String get layoutSetting => 'Reading layout';

  @override
  String get layoutMushaf => 'Mushaf pages';

  @override
  String get layoutFlowing => 'Flowing text';

  @override
  String get themeSetting => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeDay => 'Day';

  @override
  String get themeNight => 'Night';

  @override
  String get textSizeSetting => 'Quran text size';

  @override
  String get textSizeHint => 'Applies to the flowing layout.';

  @override
  String get keepScreenOnSetting => 'Keep screen on';

  @override
  String get keepScreenOnHint =>
      'The screen stays on while the Mushaf is open.';

  @override
  String get languageSetting => 'Language';

  @override
  String get languageSystem => 'Device';

  @override
  String get aboutTitle => 'About';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get sourcesTitle => 'Sources';

  @override
  String get tanzilCredit => 'Quran text verified against the Tanzil Project';

  @override
  String get qulCredit => 'Mushaf layout: Quranic Universal Library (QUL)';

  @override
  String get kfgqpcCredit =>
      'Madinah Mushaf: King Fahd Glorious Quran Printing Complex';

  @override
  String get licencesButton => 'Open-source licences';

  @override
  String get copyAyah => 'Copy';

  @override
  String get shareAyah => 'Share';

  @override
  String get bookmarkAyah => 'Bookmark';

  @override
  String get ayahCopied => 'Ayah copied.';

  @override
  String get searchTitle => 'Search';

  @override
  String get openSearch => 'Search the Quran';

  @override
  String get searchHint => 'Type a word or phrase';

  @override
  String get searchEmptyHint =>
      'Search the Quran text in Arabic, with or without diacritics.';

  @override
  String get searchNoResults => 'No results.';

  @override
  String searchAyatCount(int ayat, String ayatShown) {
    String _temp0 = intl.Intl.pluralLogic(
      ayat,
      locale: localeName,
      other: '$ayatShown ayat',
      one: '1 ayah',
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
      other: '$occurrencesShown occurrences',
      one: '1 occurrence',
    );
    String _temp1 = intl.Intl.pluralLogic(
      ayat,
      locale: localeName,
      other: '$ayatShown ayat',
      one: '1 ayah',
    );
    return '$_temp0 in $_temp1';
  }

  @override
  String get clearSearch => 'Clear';

  @override
  String get showControls => 'Show controls';

  @override
  String get printedLetteringSetting => 'Printed Mushaf lettering';

  @override
  String get printedLetteringHint =>
      'The Madinah Mushaf\'s lettering as printed by the King Fahd Complex. Turn off for the built-in font.';

  @override
  String get twoPagesSetting => 'Two pages when there is room';

  @override
  String get twoPagesHint =>
      'Shows two facing pages, like an open Mushaf, when the screen is wide enough.';

  @override
  String get listen => 'Listen';

  @override
  String get playFromAyah => 'Play from this ayah';

  @override
  String get recitationPlayer => 'Recitation player';

  @override
  String recitedAyah(String name, String ref) {
    return '$name · $ref';
  }

  @override
  String recitedBasmala(String name) {
    return '$name · Basmala';
  }

  @override
  String get basmala => 'Basmala';

  @override
  String get murattal => 'Murattal';

  @override
  String get reciter => 'Reciter';

  @override
  String get chooseReciter => 'Choose reciter';

  @override
  String get recitations => 'Recitations';

  @override
  String get playRecitation => 'Play';

  @override
  String get pauseRecitation => 'Pause';

  @override
  String get previousAyah => 'Previous ayah';

  @override
  String get nextAyah => 'Next ayah';

  @override
  String get closePlayer => 'Stop and close';

  @override
  String get repeatOff => 'Repeat off';

  @override
  String get repeatAyah => 'Repeating this ayah';

  @override
  String get repeatPage => 'Repeating this page';

  @override
  String get repeatSurah => 'Repeating this surah';

  @override
  String get repeatAyahShort => 'Ayah';

  @override
  String get repeatPageShort => 'Page';

  @override
  String get repeatSurahShort => 'Surah';

  @override
  String get recitationOffline =>
      'No connection. Download this surah to listen offline.';

  @override
  String get recitationFetchFailed => 'Couldn\'t load this ayah.';

  @override
  String get retry => 'Retry';

  @override
  String reciterNotDownloaded(String name) {
    return '$name isn\'t downloaded for this surah';
  }

  @override
  String get recitationEnded => 'Recitation finished';

  @override
  String get backToRecitation => 'Back to recitation';

  @override
  String get download => 'Download';

  @override
  String get downloads => 'Downloads';

  @override
  String downloadRecitation(String size) {
    return 'Download recitation ($size)';
  }

  @override
  String get stopDownload => 'Stop download';

  @override
  String get deleteDownload => 'Delete download';

  @override
  String get deleteAll => 'Delete all';

  @override
  String deleteAllConfirm(String name) {
    return 'Delete all $name downloads?';
  }

  @override
  String get waiting => 'Waiting';

  @override
  String get stoppedResume => 'Stopped — Resume';

  @override
  String get resume => 'Resume';

  @override
  String get stopReasonNoConnection => 'No connection';

  @override
  String get stopReasonNoStorage => 'Not enough storage';

  @override
  String get stopReasonFailed => 'Couldn\'t download';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get surahOptions => 'Surah options';

  @override
  String get downloadsEmpty =>
      'No surahs downloaded yet. Download one from the Surahs index.';

  @override
  String downloadOnMobileData(String size) {
    return 'You\'re on mobile data. Download $size?';
  }

  @override
  String notEnoughStorage(String size) {
    return 'Not enough storage: $size needed';
  }

  @override
  String get noInternet => 'No internet connection';

  @override
  String get clearRecent => 'Clear recent recitations';

  @override
  String clearRecentConfirm(String size) {
    return 'Delete recently played ayat ($size)? Downloads are kept.';
  }

  @override
  String spaceFreed(String size) {
    return '$size freed';
  }

  @override
  String sizeMb(String n) {
    return '$n MB';
  }

  @override
  String sizeKb(String n) {
    return '$n KB';
  }

  @override
  String get recitationChannel => 'Recitation';

  @override
  String get recitationAttribution =>
      'Recitations: the reciters in the reciter list, via EveryAyah.com and quranicaudio.com';

  @override
  String get onboardingWelcome => 'Welcome to Mathani';

  @override
  String get onboardingLanguageTitle => 'Choose the app language';

  @override
  String onboardingSystemLanguage(String language) {
    return 'Device ($language)';
  }

  @override
  String get onboardingThemeTitle => 'How should the Mushaf look?';

  @override
  String get onboardingReciterTitle => 'Whom would you like to listen to?';

  @override
  String get onboardingReciterHint =>
      'You can change the reciter any time from the player or Settings.';

  @override
  String get playSample => 'Play sample';

  @override
  String get stopSample => 'Stop sample';

  @override
  String get sampleOffline =>
      'Samples need an internet connection. You can still choose.';

  @override
  String onboardingStep(String index, String total) {
    return 'Step $index of $total';
  }

  @override
  String tourProgress(String index, String total) {
    return '$index of $total';
  }

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get tourDone => 'Done';

  @override
  String get tourTurnPagesTitle => 'Turn the pages';

  @override
  String get tourTurnPagesMushaf =>
      'Swipe to turn the page, as you would in a printed Mushaf.';

  @override
  String get tourTurnPagesFlowing =>
      'Scroll to read on. The text flows from one surah to the next.';

  @override
  String get tourControlsTitle => 'The controls';

  @override
  String get tourControlsMushaf => 'Tap the page to show or hide the controls.';

  @override
  String get tourControlsFlowing =>
      'The controls stay at the top and bottom. In the Mushaf pages layout, tap the page to show them.';

  @override
  String get tourAyahTitle => 'Ayah actions';

  @override
  String get tourAyahBody =>
      'Press and hold an ayah to play from it, bookmark, copy or share it.';

  @override
  String get tourSimilarTitle => 'Similar ayat';

  @override
  String get tourSimilarBody =>
      'Ayat in green have similar ayat elsewhere in the Quran, which are easy to mix up when memorizing. Press and hold one and choose “Show similar ayat” to see them together, with an explanation of the difference.';

  @override
  String get tourIndexTitle => 'Index';

  @override
  String get tourIndexBody =>
      'Surahs, ajza\' and your bookmarks. Go anywhere from here.';

  @override
  String get tourSearchTitle => 'Search';

  @override
  String get tourSearchBody =>
      'Search the Quran text, with or without diacritics.';

  @override
  String get tourPlayerTitle => 'Listen';

  @override
  String get tourPlayerBody =>
      'Listen ayah by ayah as each one is highlighted. Download surahs from the Surahs index or the player to listen offline.';

  @override
  String get tourSettingsTitle => 'Settings';

  @override
  String get tourSettingsBody =>
      'Change your choices any time, and find more: keep screen on, printed lettering, downloads, and this tour.';

  @override
  String get tourAgainSetting => 'See the tour again';

  @override
  String get tourAgainHint =>
      'How to turn pages and use the ayah actions, index, search and player.';

  @override
  String get mujawwad => 'Mujawwad';

  @override
  String get muallim => 'Teaching';

  @override
  String get searchReciters => 'Search reciters';

  @override
  String get noReciterFound => 'No reciter with this name';

  @override
  String get qulRecitationsCredit =>
      'Ayah timings and some recitations: Quranic Universal Library (QUL)';

  @override
  String get memorize => 'Memorize';

  @override
  String get memorizeFromAyah => 'Memorize from this ayah';

  @override
  String get memorizeTitle => 'Test your memorization';

  @override
  String get memorizeFrom => 'From ayah';

  @override
  String get memorizeTo => 'To ayah';

  @override
  String memorizeSummary(String ayat, String pages) {
    return '$ayat · $pages';
  }

  @override
  String memorizePage(String page) {
    return 'page $page';
  }

  @override
  String memorizePages(String from, String to) {
    return 'pages $from–$to';
  }

  @override
  String memorizeModelNeeded(String size) {
    return 'Memorization needs a one-time download of the recitation model ($size). After that it works offline.';
  }

  @override
  String memorizeModelDownloading(String percent) {
    return 'Downloading the model… $percent%';
  }

  @override
  String get memorizeModelFailed =>
      'The model couldn\'t be downloaded. Try again.';

  @override
  String get memorizeStart => 'Start';

  @override
  String get memorizeUnsupported =>
      'Memorization isn\'t available on this device';

  @override
  String get memorizeUnsupported64 => 'It needs a 64-bit processor.';

  @override
  String get memorizeUnsupportedMemory => 'It needs at least 3 GB of memory.';

  @override
  String get micExplainerTitle => 'The microphone is only for following you';

  @override
  String get micExplainerBody =>
      'Mathani listens to your recitation to reveal each ayah as you complete it. This happens on your device only; your voice is never recorded or sent.';

  @override
  String get micExplainerContinue => 'Continue';

  @override
  String get micDenied => 'Memorization can\'t start without the microphone.';

  @override
  String get memorizeListening => 'Listening';

  @override
  String get memorizeMicOn => 'Microphone on';

  @override
  String get memorizePreparing => 'Getting ready…';

  @override
  String get memorizePaused => 'Paused';

  @override
  String get memorizePausedSilence =>
      'Stopped listening after 30 seconds of silence';

  @override
  String get memorizePausedInterruption => 'Paused for a call or other audio';

  @override
  String get memorizePausedBackground => 'Paused when you left the app';

  @override
  String get memorizePausedRoute => 'The microphone was disconnected';

  @override
  String memorizeProgress(String n, String total) {
    return 'Ayah $n of $total';
  }

  @override
  String get memorizePause => 'Pause';

  @override
  String get memorizeResume => 'Resume';

  @override
  String get memorizeNextWord => 'Next word';

  @override
  String get memorizeShowAyah => 'Show this ayah';

  @override
  String get memorizeEnd => 'End';

  @override
  String get memorizeMistake => 'Mistake — carry on from the word';

  @override
  String get memorizeBackToAyah => 'Back to the ayah';

  @override
  String memorizeHiddenAyah(String n) {
    return 'Ayah $n, hidden';
  }

  @override
  String memorizeRevealed(String n) {
    return 'Ayah $n revealed';
  }

  @override
  String get resultTitle => 'Your result';

  @override
  String get resultOutOf => 'out of 100';

  @override
  String resultNoMistake(String n) {
    return 'No mistake $n';
  }

  @override
  String resultCorrected(String n) {
    return 'Corrected $n';
  }

  @override
  String resultHinted(String n) {
    return 'Hinted $n';
  }

  @override
  String resultRevealedCount(String n) {
    return 'Revealed $n';
  }

  @override
  String resultNotReachedCount(String n) {
    return 'Not reached $n';
  }

  @override
  String resultReached(String reached, String total) {
    return 'You reached $reached of $total';
  }

  @override
  String get resultRevealed => 'Revealed';

  @override
  String get resultNotReached => 'Not reached';

  @override
  String get resultNotFinished => 'Not finished';

  @override
  String get resultMissed => 'missed';

  @override
  String resultWrong(String heard) {
    return 'heard “$heard”';
  }

  @override
  String get resultAdded => 'added word';

  @override
  String get resultTryAgain => 'Try again';

  @override
  String get resultDone => 'Done';

  @override
  String get mistakeSignal => 'Mistake alert';

  @override
  String get mistakeSignalVibrate => 'Vibrate';

  @override
  String get mistakeSignalSound => 'Sound';

  @override
  String get mistakeSignalNone => 'None';

  @override
  String get memorizationModel => 'Memorization model';

  @override
  String get deleteMemorizationModel => 'Delete the memorization model';

  @override
  String get tourMemorize =>
      'Test your memorization: recite from memory and each ayah appears as you complete it';

  @override
  String get openSystemSettings => 'Open Settings';

  @override
  String get webDataKeptHere =>
      'Your bookmarks, settings and downloads are kept only in this browser.';

  @override
  String memorizationBrowserUnsupported(String browsers) {
    return 'Memorization isn\'t available in this browser. It works in $browsers.';
  }

  @override
  String get micDeniedBrowser =>
      'Allow the microphone for this site in your browser\'s site settings, then try again.';

  @override
  String get pageNeedsConnection =>
      'This page needs a connection the first time you open it.';

  @override
  String get prayerTimesTitle => 'Prayer times';

  @override
  String get prayerFirstTimeTitle => 'Set your place';

  @override
  String get prayerLocationWhy =>
      'Your approximate location is used only to work out prayer times for your city. You can search for a city instead.';

  @override
  String get prayerUseMyLocation => 'Use my location';

  @override
  String get prayerSearchCity => 'Search for a city';

  @override
  String prayerSuggested(String place) {
    return 'Suggested: $place';
  }

  @override
  String get prayerEstimateNote => 'Estimated from your internet connection';

  @override
  String get prayerNoResults => 'No matching cities. Try another name.';

  @override
  String get prayerGeoNamesAttribution => 'Place data: GeoNames';

  @override
  String get prayerCancel => 'Cancel';

  @override
  String get prayerRetry => 'Try again';

  @override
  String get prayerSave => 'Save';

  @override
  String get prayerDelete => 'Delete';

  @override
  String get prayerRename => 'Rename';

  @override
  String get prayerUnavailable => 'Unavailable';

  @override
  String get prayerFajr => 'Fajr';

  @override
  String get prayerSunrise => 'Sunrise';

  @override
  String get prayerDhuhr => 'Dhuhr';

  @override
  String get prayerAsr => 'Asr';

  @override
  String get prayerMaghrib => 'Maghrib';

  @override
  String get prayerIsha => 'Isha';

  @override
  String get prayerQiyam => 'Qiyam';

  @override
  String get prayerNotAPrayer => 'Not a prayer';

  @override
  String get prayerNext => 'Next prayer';

  @override
  String get prayerToday => 'Today';

  @override
  String get prayerPreviousDay => 'Previous day';

  @override
  String get prayerNextDay => 'Next day';

  @override
  String prayerZoneNote(String zone) {
    return 'Times in $zone';
  }

  @override
  String prayerAdjustedLatitude(String rule) {
    return 'Adjusted: $rule';
  }

  @override
  String prayerAdjustedMinutes(String minutes) {
    return 'Adjusted $minutes min';
  }

  @override
  String prayerMovedTo(String city) {
    return 'Moved to $city. Times and alerts are updated.';
  }

  @override
  String prayerViewingNote(String place) {
    return 'Viewing only. Alerts follow $place.';
  }

  @override
  String get prayerUseThisPlace => 'Use this place';

  @override
  String get prayerCalculationUnavailable =>
      'Times can\'t be calculated for this place and date.';

  @override
  String get prayerAutoplayBlocked => 'The browser blocked the athan sound.';

  @override
  String get prayerAthanPlay => 'Play athan';

  @override
  String get prayerPlaces => 'Places';

  @override
  String get prayerMyLocation => 'My location';

  @override
  String get prayerCurrentPlace => 'Alerts follow this place';

  @override
  String get prayerPlaceActions => 'Place options';

  @override
  String get prayerRefreshLocation => 'Update my location';

  @override
  String get prayerAddPlace => 'Add a place';

  @override
  String get prayerPlaceName => 'Place name';

  @override
  String get prayerLabelError =>
      'Enter 1–80 characters without line breaks or control characters.';

  @override
  String get prayerDeletePlace => 'Delete place';

  @override
  String prayerDeleteConfirm(String place) {
    return 'Delete $place and its settings?';
  }

  @override
  String get prayerDeleteLastConfirm =>
      'This is your only place. Delete it and turn off all prayer alerts?';

  @override
  String get prayerDeleteCurrentTitle => 'Alerts follow this place';

  @override
  String get prayerDeleteCurrentBody =>
      'Choose where alerts should follow, or turn them off.';

  @override
  String prayerAlertsFollow(String place) {
    return 'Alerts follow $place';
  }

  @override
  String get prayerDeleteAlertsOff => 'Delete and turn alerts off';

  @override
  String get prayerClearData => 'Delete all prayer data';

  @override
  String get prayerClearDataConfirm =>
      'Delete all saved places and prayer settings, and turn off prayer alerts? Your Quran bookmarks, reading position and downloads are kept.';

  @override
  String get prayerCalculationSettings => 'Calculation settings';

  @override
  String get prayerMethod => 'Calculation method';

  @override
  String get prayerMethodMwl => 'Muslim World League';

  @override
  String get prayerMethodEgypt => 'Egyptian General Authority of Survey';

  @override
  String get prayerMethodMakkah => 'Umm al-Qura, Makkah';

  @override
  String get prayerMethodKarachi => 'University of Islamic Sciences, Karachi';

  @override
  String get prayerMethodNorthAmerica => 'North America (ISNA)';

  @override
  String get prayerMethodDubai => 'Dubai';

  @override
  String get prayerMethodKuwait => 'Kuwait';

  @override
  String get prayerMethodQatar => 'Qatar';

  @override
  String get prayerMethodSingapore => 'Singapore';

  @override
  String get prayerMethodTurkey => 'Turkey (Diyanet)';

  @override
  String get prayerMethodMoonsighting => 'Moonsighting Committee';

  @override
  String get prayerSuggestedMethod => 'Suggested';

  @override
  String get prayerAsrSetting => 'Asr';

  @override
  String get prayerAsrStandard => 'Standard (Shafi\'i, Maliki, Hanbali)';

  @override
  String get prayerAsrHanafi => 'Hanafi';

  @override
  String get prayerAsrNote => 'This setting changes Asr only.';

  @override
  String get prayerHighLatitude => 'High-latitude rule';

  @override
  String get prayerMiddleNight => 'Middle of the night';

  @override
  String get prayerSeventhNight => 'One seventh of the night';

  @override
  String get prayerMiddleNightNote =>
      'Fajr no earlier, and Isha no later, than the middle of the night.';

  @override
  String get prayerSeventhNightNote =>
      'Fajr no earlier than the last seventh of the night, Isha no later than the first.';

  @override
  String get prayerOffsets => 'Adjust times';

  @override
  String get prayerOffsetsNote =>
      'Match your local mosque by moving a prayer up to 30 minutes.';

  @override
  String get prayerNoOffset => 'No change';

  @override
  String prayerOffsetMinutes(String minutes) {
    return '$minutes min';
  }

  @override
  String prayerEarlier(String prayer) {
    return '$prayer 1 minute earlier';
  }

  @override
  String prayerLater(String prayer) {
    return '$prayer 1 minute later';
  }

  @override
  String get prayerAlerts => 'Alerts';

  @override
  String get prayerSound => 'Sound';

  @override
  String get prayerSoundTone => 'Takbir';

  @override
  String get prayerSoundSilent => 'Silent';

  @override
  String prayerPreview(String sound) {
    return 'Preview $sound';
  }

  @override
  String get prayerAthanStop => 'Stop athan';

  @override
  String get prayerAthanLength => 'Athan length';

  @override
  String get prayerAthanOpening => 'Opening takbirat';

  @override
  String get prayerAthanFull => 'Full athan';

  @override
  String get prayerFullAndroid =>
      'Plays in full even when your phone is locked.';

  @override
  String get prayerFullIos =>
      'The alert plays the opening; tap it to hear the full athan.';

  @override
  String get prayerFullWeb => 'Plays only while this page is open.';

  @override
  String get prayerFullNotDownloaded =>
      'Until downloaded, alerts play the opening.';

  @override
  String get prayerDownload => 'Download';

  @override
  String get prayerAudioDownloading => 'Downloading and checking audio…';

  @override
  String get prayerAudioFailed =>
      'The recording couldn\'t be downloaded. Try again.';

  @override
  String get prayerAudioReady => 'Downloaded and ready offline';

  @override
  String get prayerNotificationsDenied =>
      'Alerts are blocked. Your choices are saved.';

  @override
  String get prayerOpenSettings => 'Open settings';

  @override
  String get prayerExactOff =>
      'Exact alarms are off, so alerts may be a few minutes late.';

  @override
  String get prayerAllow => 'Allow';

  @override
  String get prayerWebLimit => 'Alerts work only while this page is open.';

  @override
  String get prayerMobileApps => 'Get the mobile app';

  @override
  String prayerQiyamUpcoming(String time) {
    return 'Tonight at $time';
  }

  @override
  String get prayerQiyamExplanation =>
      'Starts the last third of the night, from Maghrib to Fajr.';

  @override
  String get prayerQiyamUnavailable =>
      'Unavailable tonight: Maghrib or the next Fajr can\'t be calculated here.';

  @override
  String get prayerQiyamNotification =>
      'The last third of the night has begun.';

  @override
  String prayerAlertTitle(String prayer) {
    return 'Time for $prayer prayer';
  }

  @override
  String get prayerAlertBody => 'Come to prayer, come to success.';

  @override
  String get prayerAlertBodyFajr => 'Prayer is better than sleep.';

  @override
  String prayerChannelSound(String sound) {
    return 'Prayer alerts: $sound';
  }

  @override
  String get prayerChannelQiyam => 'Qiyam reminder';

  @override
  String get prayerChannelAthan => 'Athan playback';

  @override
  String get prayerLocationDenied =>
      'Location wasn\'t allowed. Search for a city instead.';

  @override
  String get prayerLocationUnavailable =>
      'Your location couldn\'t be found. Try again or search for a city.';

  @override
  String get prayerTimezoneUnavailable =>
      'This place\'s time zone couldn\'t be found. Choose another city.';

  @override
  String get prayerServiceUnavailable =>
      'Couldn\'t reach the place service. Try again later.';

  @override
  String get prayerOffline =>
      'You need a connection for this. Saved places still work offline.';

  @override
  String get prayerRateLimited =>
      'Too many searches right now. Try again in a minute.';

  @override
  String get showSimilar => 'Show similar ayat';

  @override
  String get similarTitle => 'Similar ayat';

  @override
  String get similarThisAyah => 'This ayah';

  @override
  String get similarClose => 'Close';

  @override
  String similarGroup(String n) {
    return 'Group $n';
  }

  @override
  String similarOpenAyah(String ref) {
    return '$ref, open in the Mushaf';
  }

  @override
  String similarAyahSemantics(String n) {
    return 'Ayah $n, has similar ayat';
  }

  @override
  String similarOnPage(String list) {
    return 'Similar ayat on this page: $list';
  }

  @override
  String get khatmaTitle => 'Khatma';

  @override
  String get khatmaIntro =>
      'Plan a complete reading of the Quran. The app divides it into a daily wird, marks where each one ends, and keeps your place.';

  @override
  String get khatmaStart => 'Start a khatma';

  @override
  String get khatmaAlreadyInProgress =>
      'A khatma is already in progress. Finish or end it first.';

  @override
  String get khatmaTodaysWird => 'Today\'s wird';

  @override
  String khatmaWirdOf(String number, String total) {
    return 'Wird $number of $total';
  }

  @override
  String khatmaHizb(String number) {
    return 'Hizb $number';
  }

  @override
  String khatmaQuarter(String quarter, String hizb) {
    return 'Quarter $quarter of Hizb $hizb';
  }

  @override
  String khatmaWirdNumber(String number) {
    return 'Wird $number';
  }

  @override
  String khatmaAyahRef(String surah, String ayah) {
    return '$surah $ayah';
  }

  @override
  String khatmaRange(String from, String to) {
    return '$from to $to';
  }

  @override
  String khatmaPagesRange(String first, String last) {
    return 'Pages $first to $last';
  }

  @override
  String khatmaPageCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String get khatmaRead => 'Read';

  @override
  String get khatmaContinue => 'Continue';

  @override
  String get khatmaDone => 'Done';

  @override
  String get khatmaTodayDone => 'Today\'s wird is done';

  @override
  String get khatmaReadNow => 'Read now';

  @override
  String khatmaNext(String name) {
    return 'Next: $name';
  }

  @override
  String khatmaStartsOn(String date) {
    return 'Starts on $date';
  }

  @override
  String khatmaPausedSince(String date) {
    return 'Paused since $date';
  }

  @override
  String get khatmaUndo => 'Undo';

  @override
  String khatmaPagesLeft(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown pages left',
      one: '1 page left',
    );
    return '$_temp0';
  }

  @override
  String khatmaEndAt(String ayah) {
    return 'End of today\'s wird at ayah $ayah';
  }

  @override
  String get khatmaEndsHere => 'Today\'s wird ends on this page';

  @override
  String get khatmaSetPlace => 'Set khatma place here';

  @override
  String khatmaSetPlaceConfirm(String read, String unread) {
    return 'Wirds that become read: $read. Wirds that become not read: $unread. The khatma continues from this ayah.';
  }

  @override
  String get khatmaSetPlaceDone => 'The khatma continues from here.';

  @override
  String get khatmaConfirm => 'Confirm';

  @override
  String get khatmaCancel => 'Cancel';

  @override
  String get khatmaPlanTitle => 'Plan';

  @override
  String get khatmaDailyAmount => 'A daily amount';

  @override
  String get khatmaAmount1 => 'A quarter hizb a day';

  @override
  String get khatmaAmount2 => 'Half a hizb a day';

  @override
  String get khatmaAmount4 => 'A hizb a day';

  @override
  String get khatmaAmount8 => 'A juz a day';

  @override
  String get khatmaAmount16 => 'Two ajza\' a day';

  @override
  String get khatmaAmount24 => 'Three ajza\' a day';

  @override
  String get khatmaAmount80 => 'Ten ajza\' a day';

  @override
  String get khatmaSevenDays => 'Seven days, by whole surahs';

  @override
  String get khatmaCustom => 'Custom';

  @override
  String get khatmaCustomDays => 'Number of days';

  @override
  String get khatmaCustomPages => 'Pages a day';

  @override
  String get khatmaCustomDate => 'Finish date';

  @override
  String get khatmaChooseDate => 'Choose a date';

  @override
  String khatmaNumberRange(String min, String max) {
    return 'Enter a number from $min to $max.';
  }

  @override
  String khatmaDaysCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get khatmaStartFrom => 'Start from';

  @override
  String get khatmaFromBeginning => 'The beginning';

  @override
  String khatmaFromThisPage(String page) {
    return 'This page ($page)';
  }

  @override
  String get khatmaFromJuz => 'A juz';

  @override
  String get khatmaFromSurah => 'A surah';

  @override
  String get khatmaFromPage => 'A page';

  @override
  String get khatmaStartOn => 'Start on';

  @override
  String get khatmaToday => 'Today';

  @override
  String get khatmaLaterDate => 'A later date';

  @override
  String khatmaSummaryRange(String days, String from, String to, String date) {
    return '$days · $from to $to pages a day · ends $date';
  }

  @override
  String khatmaSummaryOne(String days, String pages, String date) {
    return '$days · $pages a day · ends $date';
  }

  @override
  String khatmaFromPlace(String page) {
    return 'From page $page';
  }

  @override
  String get khatmaDateBeforeStart =>
      'Choose a date on or after the start date.';

  @override
  String khatmaProgressWirds(String read, String total) {
    return 'Wirds read: $read of $total';
  }

  @override
  String khatmaProgressPages(String read, String left) {
    return 'Pages read: $read · left: $left';
  }

  @override
  String khatmaPercent(String percent) {
    return '$percent read';
  }

  @override
  String khatmaStarted(String date) {
    return 'Started $date';
  }

  @override
  String khatmaPlannedFinish(String date) {
    return 'Planned finish $date';
  }

  @override
  String khatmaExpectedFinish(String date) {
    return 'Expected finish $date';
  }

  @override
  String khatmaExpectedLate(String date, String days) {
    return 'Expected finish $date, $days after the planned date';
  }

  @override
  String khatmaExpectedEarly(String date, String days) {
    return 'Expected finish $date, $days before the planned date';
  }

  @override
  String get khatmaAllWirds => 'All wirds';

  @override
  String get khatmaChangePlan => 'Change plan';

  @override
  String get khatmaPause => 'Pause';

  @override
  String get khatmaResume => 'Resume';

  @override
  String get khatmaEnd => 'End khatma';

  @override
  String get khatmaEndConfirm =>
      'End this khatma? It won\'t be added to your finished khatmas. Your bookmarks and reading position are kept.';

  @override
  String get khatmaNotRead => 'Not read';

  @override
  String khatmaReadOn(String date) {
    return 'Read $date';
  }

  @override
  String get khatmaCurrent => 'Current';

  @override
  String get khatmaReminder => 'Daily reminder';

  @override
  String get khatmaReminderHint =>
      'One reminder a day, only when something is waiting to be read.';

  @override
  String get khatmaReminderTime => 'Time';

  @override
  String get khatmaReminderBlocked =>
      'Reminders are blocked. Your choice is saved; allow notifications for Mathani in your phone\'s settings.';

  @override
  String get khatmaReminderLate => 'Reminders may come a few minutes late.';

  @override
  String get khatmaReminderWeb => 'Reminders are available in the phone apps.';

  @override
  String khatmaReminderBody(String name, String pages) {
    return '$name · $pages';
  }

  @override
  String get khatmaRecordTitle => 'Finished khatmas';

  @override
  String khatmaRecordCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown khatmas finished',
      one: '1 khatma finished',
    );
    return '$_temp0';
  }

  @override
  String khatmaDateRange(String from, String to) {
    return '$from to $to';
  }

  @override
  String get khatmaDeleteRecord => 'Delete';

  @override
  String get khatmaDeleteRecordConfirm =>
      'Delete this finished khatma from the list?';

  @override
  String get khatmaStartNew => 'Start a new khatma';

  @override
  String get khatmaComplete => 'The khatma is complete';

  @override
  String get khatmaClose => 'Close';

  @override
  String get tourKhatma =>
      'Plan a khatma, read each day\'s wird, and keep your place.';

  @override
  String khatmaPartEndsHere(String title) {
    return 'Your part in «$title» ends on this page';
  }

  @override
  String khatmaPartEndAt(String ayah) {
    return 'End of your part at ayah $ayah';
  }

  @override
  String khatmaPartReminder(String title, String part) {
    return 'Your part in «$title»: $part';
  }

  @override
  String get khatmaReminderOn => 'Remind me each day';

  @override
  String get groupSection => 'Group khatmas';

  @override
  String get groupStart => 'Start a group khatma';

  @override
  String get groupOpenLink => 'Open a link or code';

  @override
  String get groupOpen => 'Open';

  @override
  String get groupCodeHint => 'Paste a link or a code';

  @override
  String get groupCodeInvalid => 'That is not a group khatma link or code.';

  @override
  String groupProgress(String read, String total) {
    return '$read of $total read';
  }

  @override
  String groupCounts(String free, String taken, String read) {
    return '$free free · $taken taken · $read read';
  }

  @override
  String groupFinishBy(String date) {
    return 'Finish by $date';
  }

  @override
  String groupFinishPassed(String date) {
    return 'The finish date, $date, has passed';
  }

  @override
  String groupCompleteOn(String date) {
    return 'Complete on $date';
  }

  @override
  String get groupMyParts => 'My parts';

  @override
  String get groupAllParts => 'All parts';

  @override
  String get groupFree => 'Free';

  @override
  String get groupTake => 'Take this part';

  @override
  String get groupGiveBack => 'Give back';

  @override
  String get groupDone => 'Done';

  @override
  String get groupUndoRead => 'Not read yet';

  @override
  String get groupYou => 'you';

  @override
  String get groupRead => 'read';

  @override
  String get groupWaiting => 'Waiting to be sent';

  @override
  String groupLastUpdated(String time) {
    return 'Last updated $time. It may be out of date.';
  }

  @override
  String get groupShare => 'Share';

  @override
  String get groupRefresh => 'Refresh';

  @override
  String get groupReport => 'Report';

  @override
  String get groupLeave => 'Leave the khatma';

  @override
  String get groupLeaveConfirm =>
      'Leave this khatma? Your name is removed, and the parts you have not read become free.';

  @override
  String groupShareText(String title, String link) {
    return '$title: a group khatma in Mathani. Take your part: $link';
  }

  @override
  String get groupLinkWarning =>
      'Anyone who has the link can see the names and take parts.';

  @override
  String get groupNameWarning =>
      'Your name will be seen by everyone who has the link.';

  @override
  String get groupYourName => 'Your name';

  @override
  String get groupTitleField => 'Title';

  @override
  String get groupDivision => 'Parts';

  @override
  String get groupThirty => '30 ajza\'';

  @override
  String get groupSixty => '60 ahzab';

  @override
  String get groupFinishDate => 'Finish date (optional)';

  @override
  String get groupNoDate => 'No finish date';

  @override
  String get groupCreate => 'Start';

  @override
  String get groupNeedsConnection => 'A connection is needed.';

  @override
  String get groupRetry => 'Retry';

  @override
  String get groupJustTaken => 'Someone took this part just now.';

  @override
  String get groupNoLongerYours => 'This part is no longer yours.';

  @override
  String get groupGone => 'This khatma no longer exists.';

  @override
  String get groupRemoveFromList => 'Remove from the list';

  @override
  String groupBlocked(String email) {
    return 'This device cannot start or join group khatmas. To ask why, write to $email.';
  }

  @override
  String get groupLimitOrganised =>
      'You already organise as many group khatmas as allowed.';

  @override
  String get groupLimitStarted =>
      'You have started as many group khatmas as allowed today.';

  @override
  String get groupLimitBusy =>
      'Too many group khatmas were started today. Try again tomorrow.';

  @override
  String get groupLimitReports =>
      'You have sent as many reports as allowed today.';

  @override
  String get groupProblemEmpty => 'Enter some text.';

  @override
  String get groupProblemLong => 'It is too long.';

  @override
  String get groupProblemCharacters =>
      'It has characters that are not allowed.';

  @override
  String get groupProblemLink => 'Links and addresses are not allowed.';

  @override
  String get groupProblemWord => 'It contains a word that is not allowed.';

  @override
  String get groupUpdateNeeded => 'An update is needed for this khatma.';

  @override
  String get groupError => 'Something went wrong. Try again.';

  @override
  String get groupTermsTitle => 'Before you take part';

  @override
  String get groupTerms1 =>
      'Everyone who has the link sees the khatma\'s title, your name and the parts you hold.';

  @override
  String get groupTerms2 =>
      'Offensive or abusive names and titles are not tolerated. They are removed, and the device that posted them can be blocked.';

  @override
  String get groupTerms3 =>
      'Report a name or a khatma with Report on its screen.';

  @override
  String groupTerms4(String email) {
    return 'To reach Mathani, write to $email.';
  }

  @override
  String get groupAgree => 'I agree';

  @override
  String get groupReportName => 'Report a name';

  @override
  String get groupReportKhatma => 'Report this khatma';

  @override
  String groupReportConfirm(String name) {
    return 'Report «$name» to Mathani? It is hidden on this device.';
  }

  @override
  String get groupReportKhatmaConfirm =>
      'Report this khatma to Mathani? It leaves your list.';

  @override
  String get groupReportSent => 'Report sent.';

  @override
  String get groupHidden => 'hidden';

  @override
  String get groupFreeIt => 'Free it';

  @override
  String get groupMarkRead => 'Mark as read';

  @override
  String get groupMarkUnread => 'Mark as not read';

  @override
  String get groupGiveTo => 'Give to a name';

  @override
  String get groupRemoveParticipant => 'Remove from this khatma';

  @override
  String groupRemoveConfirm(String name) {
    return 'Remove «$name»? Their unread parts become free, and they cannot join again.';
  }

  @override
  String get groupEdit => 'Edit the title or the finish date';

  @override
  String get groupDelete => 'Delete the khatma';

  @override
  String groupDeleteConfirm(String title) {
    return 'Delete «$title» for everyone?';
  }

  @override
  String get groupSave => 'Save';

  @override
  String groupTakenBy(String name) {
    return 'taken by $name';
  }

  @override
  String groupReadBy(String name) {
    return 'read by $name';
  }

  @override
  String groupPartSemantics(String part, String range, String state) {
    return '$part, $range, $state';
  }

  @override
  String get groupCopied => 'Link copied.';

  @override
  String get contactTitle => 'Contact';
}
