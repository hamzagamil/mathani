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
  String get switchToFlowing => 'Switch to flowing text';

  @override
  String get switchToMushaf => 'Switch to Mushaf pages';

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
  String get controlsHint => 'Tap the page to show controls';

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
      'Recitations: Sheikh Mahmoud Khalil Al-Husary and Sheikh Mohamed Siddiq El-Minshawi (Murattal), via EveryAyah.com';
}
