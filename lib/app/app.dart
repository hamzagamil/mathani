import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/models.dart';
import '../features/recitation/recitation_controller.dart';
import '../features/reader/reader_screen.dart';
import '../shared/reader_state.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';

class MathaniApp extends StatelessWidget {
  const MathaniApp({super.key, required this.controller, this.recitation});

  final ReaderController controller;

  /// Recitations (specs/004). Null in tests that do not need audio: no Listen button then.
  final RecitationController? recitation;

  static const supportedLocales = [Locale('ar'), Locale('en')];

  /// `system` → Arabic for Arabic device locales, English for everything else (FR-025).
  static Locale resolveLocale(LanguagePref pref, List<Locale>? deviceLocales) => switch (pref) {
        LanguagePref.ar => const Locale('ar'),
        LanguagePref.en => const Locale('en'),
        LanguagePref.system =>
          (deviceLocales ?? const []).isNotEmpty && deviceLocales!.first.languageCode == 'ar'
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
          home: const ReaderScreen(),
        );
      },
    );
    final recitation = this.recitation;
    return ReaderScope(
      controller: controller,
      child: recitation == null ? app : RecitationScope(controller: recitation, child: app),
    );
  }
}
