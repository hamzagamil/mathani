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

  /// No description provided for @switchToFlowing.
  ///
  /// In en, this message translates to:
  /// **'Switch to flowing text'**
  String get switchToFlowing;

  /// No description provided for @switchToMushaf.
  ///
  /// In en, this message translates to:
  /// **'Switch to Mushaf pages'**
  String get switchToMushaf;

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

  /// No description provided for @onboardingLayoutTitle.
  ///
  /// In en, this message translates to:
  /// **'How would you like to read?'**
  String get onboardingLayoutTitle;

  /// No description provided for @onboardingLayoutMushafHint.
  ///
  /// In en, this message translates to:
  /// **'Pages as printed in the Madinah Mushaf'**
  String get onboardingLayoutMushafHint;

  /// No description provided for @onboardingLayoutFlowingHint.
  ///
  /// In en, this message translates to:
  /// **'Continuous text you can enlarge'**
  String get onboardingLayoutFlowingHint;

  /// No description provided for @onboardingTextSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the text size'**
  String get onboardingTextSizeTitle;

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

  /// No description provided for @prayerAddLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose location'**
  String get prayerAddLocation;

  /// No description provided for @prayerDetectLocation.
  ///
  /// In en, this message translates to:
  /// **'Detect my location'**
  String get prayerDetectLocation;

  /// No description provided for @prayerSearchCity.
  ///
  /// In en, this message translates to:
  /// **'Search for a city'**
  String get prayerSearchCity;

  /// No description provided for @prayerApproximateLocation.
  ///
  /// In en, this message translates to:
  /// **'Try approximate location'**
  String get prayerApproximateLocation;

  /// No description provided for @prayerLocationDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Device location is used only to find prayer times. To resolve the place and time zone, coordinates are sent to Mathani/Cloudflare and GeoNames. You can choose a city instead.'**
  String get prayerLocationDisclosure;

  /// No description provided for @prayerIpDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Approximate lookup uses your connection\'s IP address at Cloudflare. It may be wrong with a VPN. Confirm or change the result before use.'**
  String get prayerIpDisclosure;

  /// No description provided for @prayerApproximate.
  ///
  /// In en, this message translates to:
  /// **'Approximate location'**
  String get prayerApproximate;

  /// No description provided for @prayerConfirmLocation.
  ///
  /// In en, this message translates to:
  /// **'Use this location'**
  String get prayerConfirmLocation;

  /// No description provided for @prayerChangeLocation.
  ///
  /// In en, this message translates to:
  /// **'Change location'**
  String get prayerChangeLocation;

  /// No description provided for @prayerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get prayerCancel;

  /// No description provided for @prayerNoLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose a location to see its prayer times.'**
  String get prayerNoLocation;

  /// No description provided for @prayerNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching cities. Try another name.'**
  String get prayerNoResults;

  /// No description provided for @prayerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get prayerUnavailable;

  /// No description provided for @prayerAdjusted.
  ///
  /// In en, this message translates to:
  /// **'Adjusted for high latitude'**
  String get prayerAdjusted;

  /// No description provided for @prayerNext.
  ///
  /// In en, this message translates to:
  /// **'Next prayer'**
  String get prayerNext;

  /// No description provided for @prayerFajr.
  ///
  /// In en, this message translates to:
  /// **'Fajr'**
  String get prayerFajr;

  /// No description provided for @prayerSunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise (information only)'**
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

  /// No description provided for @prayerMethod.
  ///
  /// In en, this message translates to:
  /// **'Calculation method'**
  String get prayerMethod;

  /// No description provided for @prayerMadhhab.
  ///
  /// In en, this message translates to:
  /// **'Asr madhhab'**
  String get prayerMadhhab;

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

  /// No description provided for @prayerMethodKarachi.
  ///
  /// In en, this message translates to:
  /// **'University of Islamic Sciences, Karachi'**
  String get prayerMethodKarachi;

  /// No description provided for @prayerMethodMakkah.
  ///
  /// In en, this message translates to:
  /// **'Umm al-Qura, Makkah'**
  String get prayerMethodMakkah;

  /// No description provided for @prayerMethodNorthAmerica.
  ///
  /// In en, this message translates to:
  /// **'North America (ISNA)'**
  String get prayerMethodNorthAmerica;

  /// No description provided for @prayerHanafi.
  ///
  /// In en, this message translates to:
  /// **'Hanafi'**
  String get prayerHanafi;

  /// No description provided for @prayerShafii.
  ///
  /// In en, this message translates to:
  /// **'Shafi‘i'**
  String get prayerShafii;

  /// No description provided for @prayerMaliki.
  ///
  /// In en, this message translates to:
  /// **'Maliki'**
  String get prayerMaliki;

  /// No description provided for @prayerHanbali.
  ///
  /// In en, this message translates to:
  /// **'Hanbali'**
  String get prayerHanbali;

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

  /// No description provided for @prayerHighLatitude.
  ///
  /// In en, this message translates to:
  /// **'High-latitude rule'**
  String get prayerHighLatitude;

  /// No description provided for @prayerLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location access was denied. You can choose a city manually.'**
  String get prayerLocationDenied;

  /// No description provided for @prayerLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Device location is unavailable. Choose a city or try approximate location.'**
  String get prayerLocationUnavailable;

  /// No description provided for @prayerTimezoneUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The time zone could not be resolved. Choose a city instead.'**
  String get prayerTimezoneUnavailable;

  /// No description provided for @prayerOffline.
  ///
  /// In en, this message translates to:
  /// **'A connection is needed for this lookup. Saved places still work offline.'**
  String get prayerOffline;

  /// No description provided for @prayerStorageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Saved location data could not be read securely. Retry, or continue for this session without changing existing saved data.'**
  String get prayerStorageUnavailable;

  /// No description provided for @prayerSessionOnly.
  ///
  /// In en, this message translates to:
  /// **'Use for this session'**
  String get prayerSessionOnly;

  /// No description provided for @prayerSessionNotice.
  ///
  /// In en, this message translates to:
  /// **'Changes are kept only until you close this session.'**
  String get prayerSessionNotice;

  /// No description provided for @prayerServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location lookup is unavailable. Try again later or keep using a saved place.'**
  String get prayerServiceUnavailable;

  /// No description provided for @prayerCalculationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Times cannot be calculated for this date and convention. No reminder is scheduled for unavailable times.'**
  String get prayerCalculationUnavailable;

  /// No description provided for @prayerNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Saved prayer settings need attention. Existing saved data has been preserved.'**
  String get prayerNeedsAttention;

  /// No description provided for @prayerRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get prayerRetry;

  /// No description provided for @prayerGeoNamesAttribution.
  ///
  /// In en, this message translates to:
  /// **'Place data: GeoNames'**
  String get prayerGeoNamesAttribution;

  /// No description provided for @prayerSavedLocations.
  ///
  /// In en, this message translates to:
  /// **'Saved locations'**
  String get prayerSavedLocations;

  /// No description provided for @prayerNewLocation.
  ///
  /// In en, this message translates to:
  /// **'Add a location'**
  String get prayerNewLocation;

  /// No description provided for @prayerLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location name'**
  String get prayerLocationLabel;

  /// No description provided for @prayerLabelError.
  ///
  /// In en, this message translates to:
  /// **'Enter 1–80 characters without line breaks or control characters.'**
  String get prayerLabelError;

  /// No description provided for @prayerRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get prayerRename;

  /// No description provided for @prayerViewLocation.
  ///
  /// In en, this message translates to:
  /// **'View times'**
  String get prayerViewLocation;

  /// No description provided for @prayerUseForReminders.
  ///
  /// In en, this message translates to:
  /// **'Use for reminders'**
  String get prayerUseForReminders;

  /// No description provided for @prayerActiveLocation.
  ///
  /// In en, this message translates to:
  /// **'Active reminder location'**
  String get prayerActiveLocation;

  /// No description provided for @prayerViewedLocation.
  ///
  /// In en, this message translates to:
  /// **'Viewing another location'**
  String get prayerViewedLocation;

  /// No description provided for @prayerDeleteLocation.
  ///
  /// In en, this message translates to:
  /// **'Delete location'**
  String get prayerDeleteLocation;

  /// No description provided for @prayerDeleteInactiveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this saved location and its calculation settings?'**
  String get prayerDeleteInactiveConfirm;

  /// No description provided for @prayerDeleteActiveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Choose a replacement for reminders, or delete this location and turn off all prayer reminders.'**
  String get prayerDeleteActiveConfirm;

  /// No description provided for @prayerDeleteAndDisable.
  ///
  /// In en, this message translates to:
  /// **'Delete and turn off reminders'**
  String get prayerDeleteAndDisable;

  /// No description provided for @prayerReplaceAndDelete.
  ///
  /// In en, this message translates to:
  /// **'Replace and delete'**
  String get prayerReplaceAndDelete;

  /// No description provided for @prayerReplacementLocation.
  ///
  /// In en, this message translates to:
  /// **'Replacement location'**
  String get prayerReplacementLocation;

  /// No description provided for @prayerClearData.
  ///
  /// In en, this message translates to:
  /// **'Clear prayer data'**
  String get prayerClearData;

  /// No description provided for @prayerClearDataConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all saved prayer locations and prayer settings, and cancel prayer reminders? Your Quran bookmarks and reading position will be kept.'**
  String get prayerClearDataConfirm;

  /// No description provided for @prayerActivateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Use this location for reminders? Future prayer reminders will use its calculation settings.'**
  String get prayerActivateConfirm;

  /// No description provided for @prayerCalculationSettings.
  ///
  /// In en, this message translates to:
  /// **'Calculation settings'**
  String get prayerCalculationSettings;

  /// No description provided for @prayerSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get prayerSave;

  /// No description provided for @prayerSuggestedMethod.
  ///
  /// In en, this message translates to:
  /// **'Suggested for this country'**
  String get prayerSuggestedMethod;

  /// No description provided for @prayerAsrExplanation.
  ///
  /// In en, this message translates to:
  /// **'These madhhab choices affect Asr only. Hanafi uses shadow factor 2; Shafi‘i, Maliki and Hanbali use factor 1. Your chosen label is saved.'**
  String get prayerAsrExplanation;

  /// No description provided for @prayerCalculationExplanation.
  ///
  /// In en, this message translates to:
  /// **'Choose the convention you follow. High-latitude adjustments are labelled; unavailable times are never replaced with guessed times.'**
  String get prayerCalculationExplanation;

  /// No description provided for @prayerNoActiveLocation.
  ///
  /// In en, this message translates to:
  /// **'No active reminder location'**
  String get prayerNoActiveLocation;

  /// No description provided for @prayerReminderLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Viewing times here does not change the reminder location.'**
  String get prayerReminderLocationHint;

  /// No description provided for @prayerDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get prayerDelete;

  /// No description provided for @prayerReminderSettings.
  ///
  /// In en, this message translates to:
  /// **'Prayer reminders'**
  String get prayerReminderSettings;

  /// No description provided for @prayerReminderBody.
  ///
  /// In en, this message translates to:
  /// **'It is time for {prayer}.'**
  String prayerReminderBody(String prayer);

  /// No description provided for @prayerAthanRecording.
  ///
  /// In en, this message translates to:
  /// **'Athan recording'**
  String get prayerAthanRecording;

  /// No description provided for @prayerAthanFull.
  ///
  /// In en, this message translates to:
  /// **'Full athan'**
  String get prayerAthanFull;

  /// No description provided for @prayerAthanOpening.
  ///
  /// In en, this message translates to:
  /// **'Four opening takbirs'**
  String get prayerAthanOpening;

  /// No description provided for @prayerAthanPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get prayerAthanPreview;

  /// No description provided for @prayerAthanStop.
  ///
  /// In en, this message translates to:
  /// **'Stop athan'**
  String get prayerAthanStop;

  /// No description provided for @prayerAthanPlay.
  ///
  /// In en, this message translates to:
  /// **'Play athan'**
  String get prayerAthanPlay;

  /// No description provided for @prayerAthanDownload.
  ///
  /// In en, this message translates to:
  /// **'Download for offline playback'**
  String get prayerAthanDownload;

  /// No description provided for @prayerAudioAbsent.
  ///
  /// In en, this message translates to:
  /// **'Audio has not been downloaded.'**
  String get prayerAudioAbsent;

  /// No description provided for @prayerAudioDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading and checking audio…'**
  String get prayerAudioDownloading;

  /// No description provided for @prayerAudioVerified.
  ///
  /// In en, this message translates to:
  /// **'Audio verified and ready offline'**
  String get prayerAudioVerified;

  /// No description provided for @prayerAudioFailed.
  ///
  /// In en, this message translates to:
  /// **'Audio could not be verified. Download it again.'**
  String get prayerAudioFailed;

  /// No description provided for @prayerRecordingCredit.
  ///
  /// In en, this message translates to:
  /// **'Recording credit: {credit}'**
  String prayerRecordingCredit(String credit);

  /// No description provided for @prayerRecordingSource.
  ///
  /// In en, this message translates to:
  /// **'Recording source and licence'**
  String get prayerRecordingSource;

  /// No description provided for @prayerRequestedMode.
  ///
  /// In en, this message translates to:
  /// **'Your choice: {mode}'**
  String prayerRequestedMode(String mode);

  /// No description provided for @prayerEffectiveMode.
  ///
  /// In en, this message translates to:
  /// **'Available delivery: {mode}'**
  String prayerEffectiveMode(String mode);

  /// No description provided for @prayerNotificationsPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow prayer notifications'**
  String get prayerNotificationsPermission;

  /// No description provided for @prayerNotificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked. Your reminder choices are saved; allow notifications in settings to use them.'**
  String get prayerNotificationsDenied;

  /// No description provided for @prayerNotificationsOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open notification settings'**
  String get prayerNotificationsOpenSettings;

  /// No description provided for @prayerExactAlarmAccess.
  ///
  /// In en, this message translates to:
  /// **'Allow alarms and reminders'**
  String get prayerExactAlarmAccess;

  /// No description provided for @prayerExactAlarmLimit.
  ///
  /// In en, this message translates to:
  /// **'Precise Android reminders need alarm access. Without it, you can accept approximate short alerts or keep reminders off. Late Android alerts are skipped, so approximate scheduling may miss reminders.'**
  String get prayerExactAlarmLimit;

  /// No description provided for @prayerIosFullLimit.
  ///
  /// In en, this message translates to:
  /// **'iOS cannot automatically play the full athan in the background or while locked. You can choose the short opening alert, then open Mathani and press Play for the full recording.'**
  String get prayerIosFullLimit;

  /// No description provided for @prayerIosSystemSoundLimit.
  ///
  /// In en, this message translates to:
  /// **'iOS controls notification sounds and delivery timing. Mathani cannot filter a delayed alert before the system presents it, guarantee pausing Quran playback, or stop a sound already playing. Device sound and notification settings apply.'**
  String get prayerIosSystemSoundLimit;

  /// No description provided for @prayerWebLimit.
  ///
  /// In en, this message translates to:
  /// **'Browser reminders work only while this page is open, visible and running. Closing, hiding or suspending it can prevent delivery. Automatic audio may require pressing Play. Use the mobile app for supported background reminders.'**
  String get prayerWebLimit;

  /// No description provided for @prayerMobileApps.
  ///
  /// In en, this message translates to:
  /// **'Get the mobile app'**
  String get prayerMobileApps;

  /// No description provided for @prayerForegroundOnly.
  ///
  /// In en, this message translates to:
  /// **'Active page only'**
  String get prayerForegroundOnly;

  /// No description provided for @prayerRemindersBlocked.
  ///
  /// In en, this message translates to:
  /// **'Reminders need attention before they can run.'**
  String get prayerRemindersBlocked;

  /// No description provided for @prayerRemindersPartial.
  ///
  /// In en, this message translates to:
  /// **'Some reminders could not be scheduled. Try again and check the available delivery period.'**
  String get prayerRemindersPartial;

  /// No description provided for @prayerScheduledThrough.
  ///
  /// In en, this message translates to:
  /// **'Scheduled through {time}'**
  String prayerScheduledThrough(String time);

  /// No description provided for @prayerReopenBy.
  ///
  /// In en, this message translates to:
  /// **'Open Prayer Times in Mathani again by {time} to refresh upcoming reminders. Delivery is not scheduled indefinitely.'**
  String prayerReopenBy(String time);

  /// No description provided for @prayerReconcile.
  ///
  /// In en, this message translates to:
  /// **'Refresh reminders'**
  String get prayerReconcile;

  /// No description provided for @prayerAcceptFallback.
  ///
  /// In en, this message translates to:
  /// **'Use this alternative'**
  String get prayerAcceptFallback;

  /// No description provided for @prayerNoReminders.
  ///
  /// In en, this message translates to:
  /// **'All prayer reminders are off.'**
  String get prayerNoReminders;

  /// No description provided for @prayerAutoplayBlocked.
  ///
  /// In en, this message translates to:
  /// **'The browser did not start the athan. Press Play while this reminder is still current.'**
  String get prayerAutoplayBlocked;

  /// No description provided for @prayerAthanNotCleared.
  ///
  /// In en, this message translates to:
  /// **'Athan recordings are not available yet. Your reminder choices are saved.'**
  String get prayerAthanNotCleared;

  /// No description provided for @prayerSystemSound.
  ///
  /// In en, this message translates to:
  /// **'Standard notification sound'**
  String get prayerSystemSound;

  /// No description provided for @prayerApproximateDelivery.
  ///
  /// In en, this message translates to:
  /// **'Approximate delivery is active. Alerts more than one minute late are skipped.'**
  String get prayerApproximateDelivery;

  /// No description provided for @prayerSystemSoundLimit.
  ///
  /// In en, this message translates to:
  /// **'Your device controls short notification sounds. Mathani cannot reliably stop a system sound or pause Quran playback for it. Device notification and sound settings apply.'**
  String get prayerSystemSoundLimit;

  /// No description provided for @prayerUseSystemSound.
  ///
  /// In en, this message translates to:
  /// **'Use standard notification sound'**
  String get prayerUseSystemSound;

  /// No description provided for @prayerSystemSoundDisclosure.
  ///
  /// In en, this message translates to:
  /// **'The selected athan recording is unavailable. You can use your device’s standard short notification sound instead. This does not play the athan or its opening takbirs. System sounds may overlap Quran playback and cannot reliably be stopped from Mathani. Your athan choice stays saved.'**
  String get prayerSystemSoundDisclosure;

  /// No description provided for @prayerQiyamExplanation.
  ///
  /// In en, this message translates to:
  /// **'An optional reminder at the start of the last third of the night, from Maghrib to the following Fajr. It is independent of the five daily prayer reminders.'**
  String get prayerQiyamExplanation;

  /// No description provided for @prayerQiyamTone.
  ///
  /// In en, this message translates to:
  /// **'Short Qiyam reminder tone'**
  String get prayerQiyamTone;

  /// No description provided for @prayerQiyamNotification.
  ///
  /// In en, this message translates to:
  /// **'The last third of the night has begun. Optional Qiyam reminder.'**
  String get prayerQiyamNotification;

  /// No description provided for @prayerQiyamUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Qiyam time is unavailable because this night’s Maghrib or following Fajr cannot be calculated.'**
  String get prayerQiyamUnavailable;

  /// No description provided for @prayerQiyamUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Next Qiyam reminder: {time}'**
  String prayerQiyamUpcoming(String time);
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
