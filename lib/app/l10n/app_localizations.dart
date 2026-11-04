import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// App name shown in the interface.
  ///
  /// In en, this message translates to:
  /// **'Mathani'**
  String get appName;

  /// Reader header: current juz. Number is pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'Juz {number}'**
  String juzLabel(String number);

  /// Reader header: current Mushaf page. Number is pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'Page {number}'**
  String pageLabel(String number);

  /// Reader header: the two facing Mushaf pages on a wide screen (specs/012). Numbers are pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'Pages {first}–{second}'**
  String pagesLabel(String first, String second);

  /// Screen-reader label for a Mushaf page.
  ///
  /// In en, this message translates to:
  /// **'Page {page}, Surah {surah}'**
  String pageSemantics(String page, String surah);

  /// No description provided for @indexTitle.
  ///
  /// In en, this message translates to:
  /// **'Index'**
  String get indexTitle;

  /// No description provided for @tabSurahs.
  ///
  /// In en, this message translates to:
  /// **'Surahs'**
  String get tabSurahs;

  /// No description provided for @tabAjza.
  ///
  /// In en, this message translates to:
  /// **'Ajza\''**
  String get tabAjza;

  /// No description provided for @openIndex.
  ///
  /// In en, this message translates to:
  /// **'Open index'**
  String get openIndex;

  /// No description provided for @goTo.
  ///
  /// In en, this message translates to:
  /// **'Go to'**
  String get goTo;

  /// No description provided for @goToPage.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get goToPage;

  /// No description provided for @goToSurahAyah.
  ///
  /// In en, this message translates to:
  /// **'Surah and ayah'**
  String get goToSurahAyah;

  /// No description provided for @pageField.
  ///
  /// In en, this message translates to:
  /// **'Page number'**
  String get pageField;

  /// No description provided for @surahField.
  ///
  /// In en, this message translates to:
  /// **'Surah'**
  String get surahField;

  /// No description provided for @ayahField.
  ///
  /// In en, this message translates to:
  /// **'Ayah number'**
  String get ayahField;

  /// No description provided for @goButton.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get goButton;

  /// No description provided for @pageRangeError.
  ///
  /// In en, this message translates to:
  /// **'Enter a page from 1 to {max}.'**
  String pageRangeError(String max);

  /// No description provided for @ayahRangeError.
  ///
  /// In en, this message translates to:
  /// **'Enter an ayah from 1 to {max}.'**
  String ayahRangeError(String max);

  /// count selects the plural form; shown is the same number formatted for the locale.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{shown} ayah} other{{shown} ayat}}'**
  String ayahCount(int count, String shown);

  /// No description provided for @makki.
  ///
  /// In en, this message translates to:
  /// **'Makki'**
  String get makki;

  /// No description provided for @madani.
  ///
  /// In en, this message translates to:
  /// **'Madani'**
  String get madani;

  /// No description provided for @juzTitle.
  ///
  /// In en, this message translates to:
  /// **'Juz {number}'**
  String juzTitle(String number);

  /// No description provided for @hizbStart.
  ///
  /// In en, this message translates to:
  /// **'Hizb {number}'**
  String hizbStart(String number);

  /// No description provided for @hizbQuarter.
  ///
  /// In en, this message translates to:
  /// **'¼ Hizb {number}'**
  String hizbQuarter(String number);

  /// No description provided for @hizbHalf.
  ///
  /// In en, this message translates to:
  /// **'½ Hizb {number}'**
  String hizbHalf(String number);

  /// No description provided for @hizbThreeQuarters.
  ///
  /// In en, this message translates to:
  /// **'¾ Hizb {number}'**
  String hizbThreeQuarters(String number);

  /// No description provided for @surahRowSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name}, {count} ayat, page {page}'**
  String surahRowSemantics(String name, String count, String page);

  /// No description provided for @tabBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get tabBookmarks;

  /// No description provided for @addBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark this page'**
  String get addBookmark;

  /// No description provided for @removeBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get removeBookmark;

  /// No description provided for @bookmarkAdded.
  ///
  /// In en, this message translates to:
  /// **'Bookmark added.'**
  String get bookmarkAdded;

  /// No description provided for @bookmarkRemoved.
  ///
  /// In en, this message translates to:
  /// **'Bookmark removed.'**
  String get bookmarkRemoved;

  /// No description provided for @bookmarksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet. Tap the bookmark icon on a page to save your place.'**
  String get bookmarksEmpty;

  /// No description provided for @bookmarkTitle.
  ///
  /// In en, this message translates to:
  /// **'Surah {surah}, ayah {ayah}'**
  String bookmarkTitle(String surah, String ayah);

  /// No description provided for @deleteBookmark.
  ///
  /// In en, this message translates to:
  /// **'Delete bookmark'**
  String get deleteBookmark;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @layoutSetting.
  ///
  /// In en, this message translates to:
  /// **'Reading layout'**
  String get layoutSetting;

  /// No description provided for @layoutMushaf.
  ///
  /// In en, this message translates to:
  /// **'Mushaf pages'**
  String get layoutMushaf;

  /// No description provided for @layoutFlowing.
  ///
  /// In en, this message translates to:
  /// **'Flowing text'**
  String get layoutFlowing;

  /// No description provided for @themeSetting.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeSetting;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get themeDay;

  /// No description provided for @themeNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get themeNight;

  /// No description provided for @textSizeSetting.
  ///
  /// In en, this message translates to:
  /// **'Quran text size'**
  String get textSizeSetting;

  /// No description provided for @textSizeHint.
  ///
  /// In en, this message translates to:
  /// **'Applies to the flowing layout.'**
  String get textSizeHint;

  /// No description provided for @keepScreenOnSetting.
  ///
  /// In en, this message translates to:
  /// **'Keep screen on'**
  String get keepScreenOnSetting;

  /// No description provided for @keepScreenOnHint.
  ///
  /// In en, this message translates to:
  /// **'The screen stays on while the Mushaf is open.'**
  String get keepScreenOnHint;

  /// No description provided for @languageSetting.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSetting;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get languageSystem;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @sourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sourcesTitle;

  /// No description provided for @tanzilCredit.
  ///
  /// In en, this message translates to:
  /// **'Quran text verified against the Tanzil Project'**
  String get tanzilCredit;

  /// No description provided for @qulCredit.
  ///
  /// In en, this message translates to:
  /// **'Mushaf layout: Quranic Universal Library (QUL)'**
  String get qulCredit;

  /// No description provided for @kfgqpcCredit.
  ///
  /// In en, this message translates to:
  /// **'Madinah Mushaf: King Fahd Glorious Quran Printing Complex'**
  String get kfgqpcCredit;

  /// No description provided for @licencesButton.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get licencesButton;

  /// No description provided for @copyAyah.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyAyah;

  /// No description provided for @shareAyah.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareAyah;

  /// No description provided for @bookmarkAyah.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get bookmarkAyah;

  /// No description provided for @ayahCopied.
  ///
  /// In en, this message translates to:
  /// **'Ayah copied.'**
  String get ayahCopied;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @openSearch.
  ///
  /// In en, this message translates to:
  /// **'Search the Quran'**
  String get openSearch;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Type a word or phrase'**
  String get searchHint;

  /// No description provided for @searchEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Search the Quran text in Arabic, with or without diacritics.'**
  String get searchEmptyHint;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results.'**
  String get searchNoResults;

  /// Search summary when every matching ayah matches once.
  ///
  /// In en, this message translates to:
  /// **'{ayat, plural, =1{1 ayah} other{{ayatShown} ayat}}'**
  String searchAyatCount(int ayat, String ayatShown);

  /// Search summary: matches and the number of ayat they are in.
  ///
  /// In en, this message translates to:
  /// **'{occurrences, plural, =1{1 occurrence} other{{occurrencesShown} occurrences}} in {ayat, plural, =1{1 ayah} other{{ayatShown} ayat}}'**
  String searchSummary(
    int occurrences,
    String occurrencesShown,
    int ayat,
    String ayatShown,
  );

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearSearch;

  /// Accessibility action on a Mushaf page that shows the reader controls.
  ///
  /// In en, this message translates to:
  /// **'Show controls'**
  String get showControls;

  /// No description provided for @printedLetteringSetting.
  ///
  /// In en, this message translates to:
  /// **'Printed Mushaf lettering'**
  String get printedLetteringSetting;

  /// No description provided for @printedLetteringHint.
  ///
  /// In en, this message translates to:
  /// **'The Madinah Mushaf\'s lettering as printed by the King Fahd Complex. Turn off for the built-in font.'**
  String get printedLetteringHint;

  /// Settings switch, shown only on screens wide enough for two Mushaf pages (specs/012 FR-017).
  ///
  /// In en, this message translates to:
  /// **'Two pages when there is room'**
  String get twoPagesSetting;

  /// No description provided for @twoPagesHint.
  ///
  /// In en, this message translates to:
  /// **'Shows two facing pages, like an open Mushaf, when the screen is wide enough.'**
  String get twoPagesHint;

  /// Reader toolbar: start the recitation from this page (specs/004).
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// No description provided for @playFromAyah.
  ///
  /// In en, this message translates to:
  /// **'Play from this ayah'**
  String get playFromAyah;

  /// Screen-reader label of the docked recitation bar.
  ///
  /// In en, this message translates to:
  /// **'Recitation player'**
  String get recitationPlayer;

  /// Recitation bar and lock screen: the ayah being recited. In English, name is the transliterated surah name and ref is surah:ayah (67:12).
  ///
  /// In en, this message translates to:
  /// **'{name} · {ref}'**
  String recitedAyah(String name, String ref);

  /// Recitation bar and lock screen: the basmala before ayah 1 is being recited.
  ///
  /// In en, this message translates to:
  /// **'{name} · Basmala'**
  String recitedBasmala(String name);

  /// No description provided for @basmala.
  ///
  /// In en, this message translates to:
  /// **'Basmala'**
  String get basmala;

  /// No description provided for @murattal.
  ///
  /// In en, this message translates to:
  /// **'Murattal'**
  String get murattal;

  /// No description provided for @reciter.
  ///
  /// In en, this message translates to:
  /// **'Reciter'**
  String get reciter;

  /// No description provided for @chooseReciter.
  ///
  /// In en, this message translates to:
  /// **'Choose reciter'**
  String get chooseReciter;

  /// Settings section title.
  ///
  /// In en, this message translates to:
  /// **'Recitations'**
  String get recitations;

  /// No description provided for @playRecitation.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playRecitation;

  /// No description provided for @pauseRecitation.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseRecitation;

  /// No description provided for @previousAyah.
  ///
  /// In en, this message translates to:
  /// **'Previous ayah'**
  String get previousAyah;

  /// No description provided for @nextAyah.
  ///
  /// In en, this message translates to:
  /// **'Next ayah'**
  String get nextAyah;

  /// No description provided for @closePlayer.
  ///
  /// In en, this message translates to:
  /// **'Stop and close'**
  String get closePlayer;

  /// No description provided for @repeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat off'**
  String get repeatOff;

  /// No description provided for @repeatAyah.
  ///
  /// In en, this message translates to:
  /// **'Repeating this ayah'**
  String get repeatAyah;

  /// No description provided for @repeatPage.
  ///
  /// In en, this message translates to:
  /// **'Repeating this page'**
  String get repeatPage;

  /// No description provided for @repeatSurah.
  ///
  /// In en, this message translates to:
  /// **'Repeating this surah'**
  String get repeatSurah;

  /// No description provided for @repeatAyahShort.
  ///
  /// In en, this message translates to:
  /// **'Ayah'**
  String get repeatAyahShort;

  /// No description provided for @repeatPageShort.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get repeatPageShort;

  /// No description provided for @repeatSurahShort.
  ///
  /// In en, this message translates to:
  /// **'Surah'**
  String get repeatSurahShort;

  /// No description provided for @recitationOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection. Download this surah to listen offline.'**
  String get recitationOffline;

  /// No description provided for @recitationFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this ayah.'**
  String get recitationFetchFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @reciterNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'{name} isn\'t downloaded for this surah'**
  String reciterNotDownloaded(String name);

  /// No description provided for @recitationEnded.
  ///
  /// In en, this message translates to:
  /// **'Recitation finished'**
  String get recitationEnded;

  /// No description provided for @backToRecitation.
  ///
  /// In en, this message translates to:
  /// **'Back to recitation'**
  String get backToRecitation;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @downloadRecitation.
  ///
  /// In en, this message translates to:
  /// **'Download recitation ({size})'**
  String downloadRecitation(String size);

  /// No description provided for @stopDownload.
  ///
  /// In en, this message translates to:
  /// **'Stop download'**
  String get stopDownload;

  /// No description provided for @deleteDownload.
  ///
  /// In en, this message translates to:
  /// **'Delete download'**
  String get deleteDownload;

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get deleteAll;

  /// No description provided for @deleteAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all {name} downloads?'**
  String deleteAllConfirm(String name);

  /// No description provided for @waiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get waiting;

  /// No description provided for @stoppedResume.
  ///
  /// In en, this message translates to:
  /// **'Stopped — Resume'**
  String get stoppedResume;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @stopReasonNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get stopReasonNoConnection;

  /// No description provided for @stopReasonNoStorage.
  ///
  /// In en, this message translates to:
  /// **'Not enough storage'**
  String get stopReasonNoStorage;

  /// No description provided for @stopReasonFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download'**
  String get stopReasonFailed;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @surahOptions.
  ///
  /// In en, this message translates to:
  /// **'Surah options'**
  String get surahOptions;

  /// No description provided for @downloadsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No surahs downloaded yet. Download one from the Surahs index.'**
  String get downloadsEmpty;

  /// No description provided for @downloadOnMobileData.
  ///
  /// In en, this message translates to:
  /// **'You\'re on mobile data. Download {size}?'**
  String downloadOnMobileData(String size);

  /// No description provided for @notEnoughStorage.
  ///
  /// In en, this message translates to:
  /// **'Not enough storage: {size} needed'**
  String notEnoughStorage(String size);

  /// No description provided for @noInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternet;

  /// No description provided for @clearRecent.
  ///
  /// In en, this message translates to:
  /// **'Clear recent recitations'**
  String get clearRecent;

  /// No description provided for @clearRecentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete recently played ayat ({size})? Downloads are kept.'**
  String clearRecentConfirm(String size);

  /// No description provided for @spaceFreed.
  ///
  /// In en, this message translates to:
  /// **'{size} freed'**
  String spaceFreed(String size);

  /// No description provided for @sizeMb.
  ///
  /// In en, this message translates to:
  /// **'{n} MB'**
  String sizeMb(String n);

  /// No description provided for @sizeKb.
  ///
  /// In en, this message translates to:
  /// **'{n} KB'**
  String sizeKb(String n);

  /// Android notification channel name for the recitation player.
  ///
  /// In en, this message translates to:
  /// **'Recitation'**
  String get recitationChannel;

  /// No description provided for @recitationAttribution.
  ///
  /// In en, this message translates to:
  /// **'Recitations: the reciters in the reciter list, via EveryAyah.com and quranicaudio.com'**
  String get recitationAttribution;

  /// Onboarding: greeting on the language step, shown in both languages.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Mathani'**
  String get onboardingWelcome;

  /// No description provided for @onboardingLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the app language'**
  String get onboardingLanguageTitle;

  /// Onboarding: the follow-the-device language choice, with the language it resolves to.
  ///
  /// In en, this message translates to:
  /// **'Device ({language})'**
  String onboardingSystemLanguage(String language);

  /// No description provided for @onboardingThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'How should the Mushaf look?'**
  String get onboardingThemeTitle;

  /// No description provided for @onboardingReciterTitle.
  ///
  /// In en, this message translates to:
  /// **'Whom would you like to listen to?'**
  String get onboardingReciterTitle;

  /// No description provided for @onboardingReciterHint.
  ///
  /// In en, this message translates to:
  /// **'You can change the reciter any time from the player or Settings.'**
  String get onboardingReciterHint;

  /// Onboarding: plays a few seconds of a reciter.
  ///
  /// In en, this message translates to:
  /// **'Play sample'**
  String get playSample;

  /// No description provided for @stopSample.
  ///
  /// In en, this message translates to:
  /// **'Stop sample'**
  String get stopSample;

  /// No description provided for @sampleOffline.
  ///
  /// In en, this message translates to:
  /// **'Samples need an internet connection. You can still choose.'**
  String get sampleOffline;

  /// Onboarding: progress through the preference steps. Numbers are already formatted.
  ///
  /// In en, this message translates to:
  /// **'Step {index} of {total}'**
  String onboardingStep(String index, String total);

  /// Onboarding: progress through the tour stops. Numbers are already formatted.
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String tourProgress(String index, String total);

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// Onboarding: the last tour stop's button.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get tourDone;

  /// No description provided for @tourTurnPagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn the pages'**
  String get tourTurnPagesTitle;

  /// No description provided for @tourTurnPagesMushaf.
  ///
  /// In en, this message translates to:
  /// **'Swipe to turn the page, as you would in a printed Mushaf.'**
  String get tourTurnPagesMushaf;

  /// No description provided for @tourTurnPagesFlowing.
  ///
  /// In en, this message translates to:
  /// **'Scroll to read on. The text flows from one surah to the next.'**
  String get tourTurnPagesFlowing;

  /// No description provided for @tourControlsTitle.
  ///
  /// In en, this message translates to:
  /// **'The controls'**
  String get tourControlsTitle;

  /// No description provided for @tourControlsMushaf.
  ///
  /// In en, this message translates to:
  /// **'Tap the page to show or hide the controls.'**
  String get tourControlsMushaf;

  /// No description provided for @tourControlsFlowing.
  ///
  /// In en, this message translates to:
  /// **'The controls stay at the top and bottom. In the Mushaf pages layout, tap the page to show them.'**
  String get tourControlsFlowing;

  /// No description provided for @tourAyahTitle.
  ///
  /// In en, this message translates to:
  /// **'Ayah actions'**
  String get tourAyahTitle;

  /// No description provided for @tourAyahBody.
  ///
  /// In en, this message translates to:
  /// **'Press and hold an ayah to play from it, bookmark, copy or share it.'**
  String get tourAyahBody;

  /// Onboarding stop that explains the coloured ayat (specs/010).
  ///
  /// In en, this message translates to:
  /// **'Similar ayat'**
  String get tourSimilarTitle;

  /// No description provided for @tourSimilarBody.
  ///
  /// In en, this message translates to:
  /// **'Ayat in green have similar ayat elsewhere in the Quran, which are easy to mix up when memorizing. Press and hold one and choose “Show similar ayat” to see them together, with an explanation of the difference.'**
  String get tourSimilarBody;

  /// No description provided for @tourIndexTitle.
  ///
  /// In en, this message translates to:
  /// **'Index'**
  String get tourIndexTitle;

  /// No description provided for @tourIndexBody.
  ///
  /// In en, this message translates to:
  /// **'Surahs, ajza\' and your bookmarks. Go anywhere from here.'**
  String get tourIndexBody;

  /// No description provided for @tourSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get tourSearchTitle;

  /// No description provided for @tourSearchBody.
  ///
  /// In en, this message translates to:
  /// **'Search the Quran text, with or without diacritics.'**
  String get tourSearchBody;

  /// No description provided for @tourPlayerTitle.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get tourPlayerTitle;

  /// No description provided for @tourPlayerBody.
  ///
  /// In en, this message translates to:
  /// **'Listen ayah by ayah as each one is highlighted. Download surahs from the Surahs index or the player to listen offline.'**
  String get tourPlayerBody;

  /// No description provided for @tourSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tourSettingsTitle;

  /// No description provided for @tourSettingsBody.
  ///
  /// In en, this message translates to:
  /// **'Change your choices any time, and find more: keep screen on, printed lettering, downloads, and this tour.'**
  String get tourSettingsBody;

  /// No description provided for @tourAgainSetting.
  ///
  /// In en, this message translates to:
  /// **'See the tour again'**
  String get tourAgainSetting;

  /// No description provided for @tourAgainHint.
  ///
  /// In en, this message translates to:
  /// **'How to turn pages and use the ayah actions, index, search and player.'**
  String get tourAgainHint;

  /// No description provided for @mujawwad.
  ///
  /// In en, this message translates to:
  /// **'Mujawwad'**
  String get mujawwad;

  /// Recording style: each ayah recited with repetitions for learners (specs/006 research R3).
  ///
  /// In en, this message translates to:
  /// **'Teaching'**
  String get muallim;

  /// No description provided for @searchReciters.
  ///
  /// In en, this message translates to:
  /// **'Search reciters'**
  String get searchReciters;

  /// No description provided for @noReciterFound.
  ///
  /// In en, this message translates to:
  /// **'No reciter with this name'**
  String get noReciterFound;

  /// No description provided for @qulRecitationsCredit.
  ///
  /// In en, this message translates to:
  /// **'Ayah timings and some recitations: Quranic Universal Library (QUL)'**
  String get qulRecitationsCredit;

  /// No description provided for @memorize.
  ///
  /// In en, this message translates to:
  /// **'Memorize'**
  String get memorize;

  /// No description provided for @memorizeFromAyah.
  ///
  /// In en, this message translates to:
  /// **'Memorize from this ayah'**
  String get memorizeFromAyah;

  /// No description provided for @memorizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Test your memorization'**
  String get memorizeTitle;

  /// No description provided for @memorizeFrom.
  ///
  /// In en, this message translates to:
  /// **'From ayah'**
  String get memorizeFrom;

  /// No description provided for @memorizeTo.
  ///
  /// In en, this message translates to:
  /// **'To ayah'**
  String get memorizeTo;

  /// No description provided for @memorizeSummary.
  ///
  /// In en, this message translates to:
  /// **'{ayat} · {pages}'**
  String memorizeSummary(String ayat, String pages);

  /// No description provided for @memorizePage.
  ///
  /// In en, this message translates to:
  /// **'page {page}'**
  String memorizePage(String page);

  /// No description provided for @memorizePages.
  ///
  /// In en, this message translates to:
  /// **'pages {from}–{to}'**
  String memorizePages(String from, String to);

  /// No description provided for @memorizeModelNeeded.
  ///
  /// In en, this message translates to:
  /// **'Memorization needs a one-time download of the recitation model ({size}). After that it works offline.'**
  String memorizeModelNeeded(String size);

  /// No description provided for @memorizeModelDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading the model… {percent}%'**
  String memorizeModelDownloading(String percent);

  /// No description provided for @memorizeModelFailed.
  ///
  /// In en, this message translates to:
  /// **'The model couldn\'t be downloaded. Try again.'**
  String get memorizeModelFailed;

  /// No description provided for @memorizeStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get memorizeStart;

  /// No description provided for @memorizeUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Memorization isn\'t available on this device'**
  String get memorizeUnsupported;

  /// No description provided for @memorizeUnsupported64.
  ///
  /// In en, this message translates to:
  /// **'It needs a 64-bit processor.'**
  String get memorizeUnsupported64;

  /// No description provided for @memorizeUnsupportedMemory.
  ///
  /// In en, this message translates to:
  /// **'It needs at least 3 GB of memory.'**
  String get memorizeUnsupportedMemory;

  /// No description provided for @micExplainerTitle.
  ///
  /// In en, this message translates to:
  /// **'The microphone is only for following you'**
  String get micExplainerTitle;

  /// No description provided for @micExplainerBody.
  ///
  /// In en, this message translates to:
  /// **'Mathani listens to your recitation to reveal each ayah as you complete it. This happens on your device only; your voice is never recorded or sent.'**
  String get micExplainerBody;

  /// No description provided for @micExplainerContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get micExplainerContinue;

  /// No description provided for @micDenied.
  ///
  /// In en, this message translates to:
  /// **'Memorization can\'t start without the microphone.'**
  String get micDenied;

  /// No description provided for @memorizeListening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get memorizeListening;

  /// No description provided for @memorizeMicOn.
  ///
  /// In en, this message translates to:
  /// **'Microphone on'**
  String get memorizeMicOn;

  /// No description provided for @memorizePreparing.
  ///
  /// In en, this message translates to:
  /// **'Getting ready…'**
  String get memorizePreparing;

  /// No description provided for @memorizePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get memorizePaused;

  /// No description provided for @memorizePausedSilence.
  ///
  /// In en, this message translates to:
  /// **'Stopped listening after 30 seconds of silence'**
  String get memorizePausedSilence;

  /// No description provided for @memorizePausedInterruption.
  ///
  /// In en, this message translates to:
  /// **'Paused for a call or other audio'**
  String get memorizePausedInterruption;

  /// No description provided for @memorizePausedBackground.
  ///
  /// In en, this message translates to:
  /// **'Paused when you left the app'**
  String get memorizePausedBackground;

  /// No description provided for @memorizePausedRoute.
  ///
  /// In en, this message translates to:
  /// **'The microphone was disconnected'**
  String get memorizePausedRoute;

  /// No description provided for @memorizeProgress.
  ///
  /// In en, this message translates to:
  /// **'Ayah {n} of {total}'**
  String memorizeProgress(String n, String total);

  /// No description provided for @memorizePause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get memorizePause;

  /// No description provided for @memorizeResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get memorizeResume;

  /// No description provided for @memorizeNextWord.
  ///
  /// In en, this message translates to:
  /// **'Next word'**
  String get memorizeNextWord;

  /// No description provided for @memorizeShowAyah.
  ///
  /// In en, this message translates to:
  /// **'Show this ayah'**
  String get memorizeShowAyah;

  /// No description provided for @memorizeEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get memorizeEnd;

  /// No description provided for @memorizeMistake.
  ///
  /// In en, this message translates to:
  /// **'Mistake — carry on from the word'**
  String get memorizeMistake;

  /// No description provided for @memorizeBackToAyah.
  ///
  /// In en, this message translates to:
  /// **'Back to the ayah'**
  String get memorizeBackToAyah;

  /// No description provided for @memorizeHiddenAyah.
  ///
  /// In en, this message translates to:
  /// **'Ayah {n}, hidden'**
  String memorizeHiddenAyah(String n);

  /// No description provided for @memorizeRevealed.
  ///
  /// In en, this message translates to:
  /// **'Ayah {n} revealed'**
  String memorizeRevealed(String n);

  /// No description provided for @resultTitle.
  ///
  /// In en, this message translates to:
  /// **'Your result'**
  String get resultTitle;

  /// No description provided for @resultOutOf.
  ///
  /// In en, this message translates to:
  /// **'out of 100'**
  String get resultOutOf;

  /// No description provided for @resultNoMistake.
  ///
  /// In en, this message translates to:
  /// **'No mistake {n}'**
  String resultNoMistake(String n);

  /// No description provided for @resultCorrected.
  ///
  /// In en, this message translates to:
  /// **'Corrected {n}'**
  String resultCorrected(String n);

  /// No description provided for @resultHinted.
  ///
  /// In en, this message translates to:
  /// **'Hinted {n}'**
  String resultHinted(String n);

  /// No description provided for @resultRevealedCount.
  ///
  /// In en, this message translates to:
  /// **'Revealed {n}'**
  String resultRevealedCount(String n);

  /// No description provided for @resultNotReachedCount.
  ///
  /// In en, this message translates to:
  /// **'Not reached {n}'**
  String resultNotReachedCount(String n);

  /// No description provided for @resultReached.
  ///
  /// In en, this message translates to:
  /// **'You reached {reached} of {total}'**
  String resultReached(String reached, String total);

  /// No description provided for @resultRevealed.
  ///
  /// In en, this message translates to:
  /// **'Revealed'**
  String get resultRevealed;

  /// No description provided for @resultNotReached.
  ///
  /// In en, this message translates to:
  /// **'Not reached'**
  String get resultNotReached;

  /// No description provided for @resultNotFinished.
  ///
  /// In en, this message translates to:
  /// **'Not finished'**
  String get resultNotFinished;

  /// No description provided for @resultMissed.
  ///
  /// In en, this message translates to:
  /// **'missed'**
  String get resultMissed;

  /// No description provided for @resultWrong.
  ///
  /// In en, this message translates to:
  /// **'heard “{heard}”'**
  String resultWrong(String heard);

  /// No description provided for @resultAdded.
  ///
  /// In en, this message translates to:
  /// **'added word'**
  String get resultAdded;

  /// No description provided for @resultTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get resultTryAgain;

  /// No description provided for @resultDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get resultDone;

  /// No description provided for @mistakeSignal.
  ///
  /// In en, this message translates to:
  /// **'Mistake alert'**
  String get mistakeSignal;

  /// No description provided for @mistakeSignalVibrate.
  ///
  /// In en, this message translates to:
  /// **'Vibrate'**
  String get mistakeSignalVibrate;

  /// No description provided for @mistakeSignalSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get mistakeSignalSound;

  /// No description provided for @mistakeSignalNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get mistakeSignalNone;

  /// No description provided for @memorizationModel.
  ///
  /// In en, this message translates to:
  /// **'Memorization model'**
  String get memorizationModel;

  /// No description provided for @deleteMemorizationModel.
  ///
  /// In en, this message translates to:
  /// **'Delete the memorization model'**
  String get deleteMemorizationModel;

  /// No description provided for @tourMemorize.
  ///
  /// In en, this message translates to:
  /// **'Test your memorization: recite from memory and each ayah appears as you complete it'**
  String get tourMemorize;

  /// No description provided for @openSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSystemSettings;

  /// No description provided for @webDataKeptHere.
  ///
  /// In en, this message translates to:
  /// **'Your bookmarks, settings and downloads are kept only in this browser.'**
  String get webDataKeptHere;

  /// No description provided for @memorizationBrowserUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Memorization isn\'t available in this browser. It works in {browsers}.'**
  String memorizationBrowserUnsupported(String browsers);

  /// No description provided for @micDeniedBrowser.
  ///
  /// In en, this message translates to:
  /// **'Allow the microphone for this site in your browser\'s site settings, then try again.'**
  String get micDeniedBrowser;

  /// No description provided for @pageNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'This page needs a connection the first time you open it.'**
  String get pageNeedsConnection;

  /// No description provided for @prayerTimesTitle.
  ///
  /// In en, this message translates to:
  /// **'Prayer times'**
  String get prayerTimesTitle;

  /// No description provided for @prayerFirstTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Set your place'**
  String get prayerFirstTimeTitle;

  /// No description provided for @prayerLocationWhy.
  ///
  /// In en, this message translates to:
  /// **'Your approximate location is used only to work out prayer times for your city. You can search for a city instead.'**
  String get prayerLocationWhy;

  /// No description provided for @prayerUseMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get prayerUseMyLocation;

  /// No description provided for @prayerSearchCity.
  ///
  /// In en, this message translates to:
  /// **'Search for a city'**
  String get prayerSearchCity;

  /// No description provided for @prayerSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested: {place}'**
  String prayerSuggested(String place);

  /// No description provided for @prayerEstimateNote.
  ///
  /// In en, this message translates to:
  /// **'Estimated from your internet connection'**
  String get prayerEstimateNote;

  /// No description provided for @prayerNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching cities. Try another name.'**
  String get prayerNoResults;

  /// No description provided for @prayerGeoNamesAttribution.
  ///
  /// In en, this message translates to:
  /// **'Place data: GeoNames'**
  String get prayerGeoNamesAttribution;

  /// No description provided for @prayerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get prayerCancel;

  /// No description provided for @prayerRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get prayerRetry;

  /// No description provided for @prayerSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get prayerSave;

  /// No description provided for @prayerDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get prayerDelete;

  /// No description provided for @prayerRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get prayerRename;

  /// No description provided for @prayerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get prayerUnavailable;

  /// No description provided for @prayerFajr.
  ///
  /// In en, this message translates to:
  /// **'Fajr'**
  String get prayerFajr;

  /// No description provided for @prayerSunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get prayerSunrise;

  /// No description provided for @prayerDhuhr.
  ///
  /// In en, this message translates to:
  /// **'Dhuhr'**
  String get prayerDhuhr;

  /// No description provided for @prayerAsr.
  ///
  /// In en, this message translates to:
  /// **'Asr'**
  String get prayerAsr;

  /// No description provided for @prayerMaghrib.
  ///
  /// In en, this message translates to:
  /// **'Maghrib'**
  String get prayerMaghrib;

  /// No description provided for @prayerIsha.
  ///
  /// In en, this message translates to:
  /// **'Isha'**
  String get prayerIsha;

  /// No description provided for @prayerQiyam.
  ///
  /// In en, this message translates to:
  /// **'Qiyam'**
  String get prayerQiyam;

  /// No description provided for @prayerNotAPrayer.
  ///
  /// In en, this message translates to:
  /// **'Not a prayer'**
  String get prayerNotAPrayer;

  /// No description provided for @prayerNext.
  ///
  /// In en, this message translates to:
  /// **'Next prayer'**
  String get prayerNext;

  /// No description provided for @prayerToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get prayerToday;

  /// No description provided for @prayerPreviousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get prayerPreviousDay;

  /// No description provided for @prayerNextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get prayerNextDay;

  /// No description provided for @prayerZoneNote.
  ///
  /// In en, this message translates to:
  /// **'Times in {zone}'**
  String prayerZoneNote(String zone);

  /// No description provided for @prayerAdjustedLatitude.
  ///
  /// In en, this message translates to:
  /// **'Adjusted: {rule}'**
  String prayerAdjustedLatitude(String rule);

  /// No description provided for @prayerAdjustedMinutes.
  ///
  /// In en, this message translates to:
  /// **'Adjusted {minutes} min'**
  String prayerAdjustedMinutes(String minutes);

  /// No description provided for @prayerMovedTo.
  ///
  /// In en, this message translates to:
  /// **'Moved to {city}. Times and alerts are updated.'**
  String prayerMovedTo(String city);

  /// No description provided for @prayerViewingNote.
  ///
  /// In en, this message translates to:
  /// **'Viewing only. Alerts follow {place}.'**
  String prayerViewingNote(String place);

  /// No description provided for @prayerUseThisPlace.
  ///
  /// In en, this message translates to:
  /// **'Use this place'**
  String get prayerUseThisPlace;

  /// No description provided for @prayerCalculationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Times can\'t be calculated for this place and date.'**
  String get prayerCalculationUnavailable;

  /// No description provided for @prayerAutoplayBlocked.
  ///
  /// In en, this message translates to:
  /// **'The browser blocked the athan sound.'**
  String get prayerAutoplayBlocked;

  /// No description provided for @prayerAthanPlay.
  ///
  /// In en, this message translates to:
  /// **'Play athan'**
  String get prayerAthanPlay;

  /// No description provided for @prayerPlaces.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get prayerPlaces;

  /// No description provided for @prayerMyLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get prayerMyLocation;

  /// No description provided for @prayerCurrentPlace.
  ///
  /// In en, this message translates to:
  /// **'Alerts follow this place'**
  String get prayerCurrentPlace;

  /// No description provided for @prayerPlaceActions.
  ///
  /// In en, this message translates to:
  /// **'Place options'**
  String get prayerPlaceActions;

  /// No description provided for @prayerRefreshLocation.
  ///
  /// In en, this message translates to:
  /// **'Update my location'**
  String get prayerRefreshLocation;

  /// No description provided for @prayerAddPlace.
  ///
  /// In en, this message translates to:
  /// **'Add a place'**
  String get prayerAddPlace;

  /// No description provided for @prayerPlaceName.
  ///
  /// In en, this message translates to:
  /// **'Place name'**
  String get prayerPlaceName;

  /// No description provided for @prayerLabelError.
  ///
  /// In en, this message translates to:
  /// **'Enter 1–80 characters without line breaks or control characters.'**
  String get prayerLabelError;

  /// No description provided for @prayerDeletePlace.
  ///
  /// In en, this message translates to:
  /// **'Delete place'**
  String get prayerDeletePlace;

  /// No description provided for @prayerDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {place} and its settings?'**
  String prayerDeleteConfirm(String place);

  /// No description provided for @prayerDeleteLastConfirm.
  ///
  /// In en, this message translates to:
  /// **'This is your only place. Delete it and turn off all prayer alerts?'**
  String get prayerDeleteLastConfirm;

  /// No description provided for @prayerDeleteCurrentTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts follow this place'**
  String get prayerDeleteCurrentTitle;

  /// No description provided for @prayerDeleteCurrentBody.
  ///
  /// In en, this message translates to:
  /// **'Choose where alerts should follow, or turn them off.'**
  String get prayerDeleteCurrentBody;

  /// No description provided for @prayerAlertsFollow.
  ///
  /// In en, this message translates to:
  /// **'Alerts follow {place}'**
  String prayerAlertsFollow(String place);

  /// No description provided for @prayerDeleteAlertsOff.
  ///
  /// In en, this message translates to:
  /// **'Delete and turn alerts off'**
  String get prayerDeleteAlertsOff;

  /// No description provided for @prayerClearData.
  ///
  /// In en, this message translates to:
  /// **'Delete all prayer data'**
  String get prayerClearData;

  /// No description provided for @prayerClearDataConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all saved places and prayer settings, and turn off prayer alerts? Your Quran bookmarks, reading position and downloads are kept.'**
  String get prayerClearDataConfirm;

  /// No description provided for @prayerCalculationSettings.
  ///
  /// In en, this message translates to:
  /// **'Calculation settings'**
  String get prayerCalculationSettings;

  /// No description provided for @prayerMethod.
  ///
  /// In en, this message translates to:
  /// **'Calculation method'**
  String get prayerMethod;

  /// No description provided for @prayerMethodMwl.
  ///
  /// In en, this message translates to:
  /// **'Muslim World League'**
  String get prayerMethodMwl;

  /// No description provided for @prayerMethodEgypt.
  ///
  /// In en, this message translates to:
  /// **'Egyptian General Authority of Survey'**
  String get prayerMethodEgypt;

  /// No description provided for @prayerMethodMakkah.
  ///
  /// In en, this message translates to:
  /// **'Umm al-Qura, Makkah'**
  String get prayerMethodMakkah;

  /// No description provided for @prayerMethodKarachi.
  ///
  /// In en, this message translates to:
  /// **'University of Islamic Sciences, Karachi'**
  String get prayerMethodKarachi;

  /// No description provided for @prayerMethodNorthAmerica.
  ///
  /// In en, this message translates to:
  /// **'North America (ISNA)'**
  String get prayerMethodNorthAmerica;

  /// No description provided for @prayerMethodDubai.
  ///
  /// In en, this message translates to:
  /// **'Dubai'**
  String get prayerMethodDubai;

  /// No description provided for @prayerMethodKuwait.
  ///
  /// In en, this message translates to:
  /// **'Kuwait'**
  String get prayerMethodKuwait;

  /// No description provided for @prayerMethodQatar.
  ///
  /// In en, this message translates to:
  /// **'Qatar'**
  String get prayerMethodQatar;

  /// No description provided for @prayerMethodSingapore.
  ///
  /// In en, this message translates to:
  /// **'Singapore'**
  String get prayerMethodSingapore;

  /// No description provided for @prayerMethodTurkey.
  ///
  /// In en, this message translates to:
  /// **'Turkey (Diyanet)'**
  String get prayerMethodTurkey;

  /// No description provided for @prayerMethodMoonsighting.
  ///
  /// In en, this message translates to:
  /// **'Moonsighting Committee'**
  String get prayerMethodMoonsighting;

  /// No description provided for @prayerSuggestedMethod.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get prayerSuggestedMethod;

  /// No description provided for @prayerAsrSetting.
  ///
  /// In en, this message translates to:
  /// **'Asr'**
  String get prayerAsrSetting;

  /// No description provided for @prayerAsrStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard (Shafi\'i, Maliki, Hanbali)'**
  String get prayerAsrStandard;

  /// No description provided for @prayerAsrHanafi.
  ///
  /// In en, this message translates to:
  /// **'Hanafi'**
  String get prayerAsrHanafi;

  /// No description provided for @prayerAsrNote.
  ///
  /// In en, this message translates to:
  /// **'This setting changes Asr only.'**
  String get prayerAsrNote;

  /// No description provided for @prayerHighLatitude.
  ///
  /// In en, this message translates to:
  /// **'High-latitude rule'**
  String get prayerHighLatitude;

  /// No description provided for @prayerMiddleNight.
  ///
  /// In en, this message translates to:
  /// **'Middle of the night'**
  String get prayerMiddleNight;

  /// No description provided for @prayerSeventhNight.
  ///
  /// In en, this message translates to:
  /// **'One seventh of the night'**
  String get prayerSeventhNight;

  /// No description provided for @prayerMiddleNightNote.
  ///
  /// In en, this message translates to:
  /// **'Fajr no earlier, and Isha no later, than the middle of the night.'**
  String get prayerMiddleNightNote;

  /// No description provided for @prayerSeventhNightNote.
  ///
  /// In en, this message translates to:
  /// **'Fajr no earlier than the last seventh of the night, Isha no later than the first.'**
  String get prayerSeventhNightNote;

  /// No description provided for @prayerOffsets.
  ///
  /// In en, this message translates to:
  /// **'Adjust times'**
  String get prayerOffsets;

  /// No description provided for @prayerOffsetsNote.
  ///
  /// In en, this message translates to:
  /// **'Match your local mosque by moving a prayer up to 30 minutes.'**
  String get prayerOffsetsNote;

  /// No description provided for @prayerNoOffset.
  ///
  /// In en, this message translates to:
  /// **'No change'**
  String get prayerNoOffset;

  /// No description provided for @prayerOffsetMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String prayerOffsetMinutes(String minutes);

  /// No description provided for @prayerEarlier.
  ///
  /// In en, this message translates to:
  /// **'{prayer} 1 minute earlier'**
  String prayerEarlier(String prayer);

  /// No description provided for @prayerLater.
  ///
  /// In en, this message translates to:
  /// **'{prayer} 1 minute later'**
  String prayerLater(String prayer);

  /// No description provided for @prayerAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get prayerAlerts;

  /// No description provided for @prayerSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get prayerSound;

  /// No description provided for @prayerSoundTone.
  ///
  /// In en, this message translates to:
  /// **'Simple tone'**
  String get prayerSoundTone;

  /// No description provided for @prayerSoundSilent.
  ///
  /// In en, this message translates to:
  /// **'Silent'**
  String get prayerSoundSilent;

  /// No description provided for @prayerPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview {sound}'**
  String prayerPreview(String sound);

  /// No description provided for @prayerAthanStop.
  ///
  /// In en, this message translates to:
  /// **'Stop athan'**
  String get prayerAthanStop;

  /// No description provided for @prayerAthanLength.
  ///
  /// In en, this message translates to:
  /// **'Athan length'**
  String get prayerAthanLength;

  /// No description provided for @prayerAthanOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening takbirat'**
  String get prayerAthanOpening;

  /// No description provided for @prayerAthanFull.
  ///
  /// In en, this message translates to:
  /// **'Full athan'**
  String get prayerAthanFull;

  /// No description provided for @prayerFullAndroid.
  ///
  /// In en, this message translates to:
  /// **'Plays in full even when your phone is locked.'**
  String get prayerFullAndroid;

  /// No description provided for @prayerFullIos.
  ///
  /// In en, this message translates to:
  /// **'The alert plays the opening; tap it to hear the full athan.'**
  String get prayerFullIos;

  /// No description provided for @prayerFullWeb.
  ///
  /// In en, this message translates to:
  /// **'Plays only while this page is open.'**
  String get prayerFullWeb;

  /// No description provided for @prayerFullNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Until downloaded, alerts play the opening.'**
  String get prayerFullNotDownloaded;

  /// No description provided for @prayerDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get prayerDownload;

  /// No description provided for @prayerAudioDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading and checking audio…'**
  String get prayerAudioDownloading;

  /// No description provided for @prayerAudioFailed.
  ///
  /// In en, this message translates to:
  /// **'The recording couldn\'t be downloaded. Try again.'**
  String get prayerAudioFailed;

  /// No description provided for @prayerAudioReady.
  ///
  /// In en, this message translates to:
  /// **'Downloaded and ready offline'**
  String get prayerAudioReady;

  /// No description provided for @prayerNotificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'Alerts are blocked. Your choices are saved.'**
  String get prayerNotificationsDenied;

  /// No description provided for @prayerOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get prayerOpenSettings;

  /// No description provided for @prayerExactOff.
  ///
  /// In en, this message translates to:
  /// **'Exact alarms are off, so alerts may be a few minutes late.'**
  String get prayerExactOff;

  /// No description provided for @prayerAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get prayerAllow;

  /// No description provided for @prayerWebLimit.
  ///
  /// In en, this message translates to:
  /// **'Alerts work only while this page is open.'**
  String get prayerWebLimit;

  /// No description provided for @prayerMobileApps.
  ///
  /// In en, this message translates to:
  /// **'Get the mobile app'**
  String get prayerMobileApps;

  /// No description provided for @prayerQiyamUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Tonight at {time}'**
  String prayerQiyamUpcoming(String time);

  /// No description provided for @prayerQiyamExplanation.
  ///
  /// In en, this message translates to:
  /// **'Starts the last third of the night, from Maghrib to Fajr.'**
  String get prayerQiyamExplanation;

  /// No description provided for @prayerQiyamUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable tonight: Maghrib or the next Fajr can\'t be calculated here.'**
  String get prayerQiyamUnavailable;

  /// No description provided for @prayerQiyamNotification.
  ///
  /// In en, this message translates to:
  /// **'The last third of the night has begun.'**
  String get prayerQiyamNotification;

  /// No description provided for @prayerAlertBody.
  ///
  /// In en, this message translates to:
  /// **'{time} · {place}'**
  String prayerAlertBody(String time, String place);

  /// No description provided for @prayerChannelSound.
  ///
  /// In en, this message translates to:
  /// **'Prayer alerts: {sound}'**
  String prayerChannelSound(String sound);

  /// No description provided for @prayerChannelQiyam.
  ///
  /// In en, this message translates to:
  /// **'Qiyam reminder'**
  String get prayerChannelQiyam;

  /// No description provided for @prayerChannelAthan.
  ///
  /// In en, this message translates to:
  /// **'Athan playback'**
  String get prayerChannelAthan;

  /// No description provided for @prayerLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location wasn\'t allowed. Search for a city instead.'**
  String get prayerLocationDenied;

  /// No description provided for @prayerLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your location couldn\'t be found. Try again or search for a city.'**
  String get prayerLocationUnavailable;

  /// No description provided for @prayerTimezoneUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This place\'s time zone couldn\'t be found. Choose another city.'**
  String get prayerTimezoneUnavailable;

  /// No description provided for @prayerServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the place service. Try again later.'**
  String get prayerServiceUnavailable;

  /// No description provided for @prayerOffline.
  ///
  /// In en, this message translates to:
  /// **'You need a connection for this. Saved places still work offline.'**
  String get prayerOffline;

  /// No description provided for @prayerRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many searches right now. Try again in a minute.'**
  String get prayerRateLimited;

  /// Long-press action for an ayah linked to similar ayat (specs/010)
  ///
  /// In en, this message translates to:
  /// **'Show similar ayat'**
  String get showSimilar;

  /// No description provided for @similarTitle.
  ///
  /// In en, this message translates to:
  /// **'Similar ayat'**
  String get similarTitle;

  /// No description provided for @similarThisAyah.
  ///
  /// In en, this message translates to:
  /// **'This ayah'**
  String get similarThisAyah;

  /// No description provided for @similarClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get similarClose;

  /// Chip that switches between the groups of an ayah in several groups
  ///
  /// In en, this message translates to:
  /// **'Group {n}'**
  String similarGroup(String n);

  /// Screen reader label of a similar ayah in the overlay
  ///
  /// In en, this message translates to:
  /// **'{ref}, open in the Mushaf'**
  String similarOpenAyah(String ref);

  /// Screen reader label of the end marker of an ayah that has similar ayat
  ///
  /// In en, this message translates to:
  /// **'Ayah {n}, has similar ayat'**
  String similarAyahSemantics(String n);

  /// Added to the page label when the page has ayat with similar ayat
  ///
  /// In en, this message translates to:
  /// **'Similar ayat on this page: {list}'**
  String similarOnPage(String list);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
