import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/models.dart';
import '../features/memorization/memorization_controller.dart';
import '../features/onboarding/onboarding_controller.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/recitation/recitation_controller.dart';
import '../features/reader/reader_screen.dart';
import '../features/prayer_times/prayer_notification_open_host.dart';
import '../shared/reader_state.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';

/// In a browser window wider than this, the app is shown in a centred phone-width column
/// (specs/008 FR-012, research R13); a layout made for wide screens is a later feature.
const wideWindowMin = 600.0;
const phoneColumnWidth = 480.0;

class MathaniApp extends StatelessWidget {
  const MathaniApp({
    super.key,
    required this.controller,
    this.recitation,
    this.onboarding,
    this.memorization,
  });

  final ReaderController controller;

  /// Recitations (specs/004). Null in tests that do not need audio: no Listen button then.
  final RecitationController? recitation;

  /// The onboarding (specs/005). Null in tests that open straight on the reader.
  final OnboardingController? onboarding;

  /// Memorization (specs/006). Null in tests that do not need it: no Memorize button then.
  final MemorizationController? memorization;

  static const supportedLocales = [Locale('ar'), Locale('en')];

  /// `system` → Arabic for Arabic device locales, English for everything else (FR-025).
  static Locale resolveLocale(LanguagePref pref, List<Locale>? deviceLocales) =>
      switch (pref) {
        LanguagePref.ar => const Locale('ar'),
        LanguagePref.en => const Locale('en'),
        LanguagePref.system =>
          (deviceLocales ?? const []).isNotEmpty &&
                  deviceLocales!.first.languageCode == 'ar'
              ? const Locale('ar')
              : const Locale('en'),
      };

  @override
  Widget build(BuildContext context) {
    final Widget app = ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final prefs = controller.preferences;
        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appName,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: switch (prefs.theme) {
            ThemePref.system => ThemeMode.system,
            ThemePref.day => ThemeMode.light,
            ThemePref.night => ThemeMode.dark,
          },
          supportedLocales: supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          locale: prefs.language == LanguagePref.system
              ? null
              : resolveLocale(prefs.language, null),
          localeListResolutionCallback: (deviceLocales, _) =>
              resolveLocale(prefs.language, deviceLocales),
          // Around the Navigator, so sheets, dialogs and snack bars stay inside the column.
          builder: kIsWeb
              ? (context, child) => PhoneColumn(child: child!)
              : null,
          home: const PrayerNotificationOpenHost(child: _Home()),
        );
      },
    );
    final recitation = this.recitation;
    final onboarding = this.onboarding;
    final memorization = this.memorization;
    final withMemorization = memorization == null
        ? app
        : MemorizationScope(controller: memorization, child: app);
    final scoped = onboarding == null
        ? withMemorization
        : OnboardingScope(controller: onboarding, child: withMemorization);
    return ReaderScope(
      controller: controller,
      child: recitation == null
          ? scoped
          : RecitationScope(controller: recitation, child: scoped),
    );
  }
}

/// The app in a centred column of [phoneColumnWidth] when the window is wider than
/// [wideWindowMin], told through [MediaQuery] that its screen is that column, so every screen and
/// the Mushaf page are laid out as on a phone. Narrower windows get the child as it is.
class PhoneColumn extends StatelessWidget {
  const PhoneColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= wideWindowMin) return child;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: SizedBox(
          width: phoneColumnWidth,
          height: media.size.height,
          child: ClipRect(
            child: MediaQuery(
              data: media.copyWith(
                size: Size(phoneColumnWidth, media.size.height),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The onboarding while it is on a setup step or gesture stop, otherwise the reader (which lays
/// the button hints over itself) (specs/005 contracts/onboarding-flow.md › App shell).
class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) =>
      switch (OnboardingScope.maybeOf(context)?.phase) {
        OnboardingPhase.setup ||
        OnboardingPhase.gestures => const OnboardingScreen(),
        _ => const ReaderScreen(),
      };
}
