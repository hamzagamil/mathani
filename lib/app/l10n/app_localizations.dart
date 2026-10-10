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
