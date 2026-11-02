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
  String get prayerSoundTone => 'Simple tone';

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
  String prayerAlertBody(String time, String place) {
    return '$time · $place';
  }

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
}
