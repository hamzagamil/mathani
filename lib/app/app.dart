import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/models.dart';
import '../features/memorization/memorization_controller.dart';
import '../features/onboarding/onboarding_controller.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/recitation/recitation_controller.dart';
import '../features/reader/mushaf_view.dart';
import '../features/reader/page_geometry.dart';
import '../features/reader/reader_screen.dart';
import '../features/prayer_times/prayer_alerts.dart';
import '../features/prayer_times/prayer_notification_open_host.dart';
import '../shared/reader_state.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';

/// In a browser window wider than this, the app is shown in a centred phone-width column
/// (specs/008 FR-012, research R13). The column widens for two facing Mushaf pages (specs/012).
const wideWindowMin = 600.0;
const phoneColumnWidth = 480.0;

class MathaniApp extends StatelessWidget {
  const MathaniApp({
    super.key,
    required this.controller,
    this.recitation,
    this.onboarding,
    this.memorization,
    this.prayer,
  });

  final ReaderController controller;

  /// Recitations (specs/004). Null in tests that do not need audio: no Listen button then.
  final RecitationController? recitation;

  /// The onboarding (specs/005). Null in tests that open straight on the reader.
  final OnboardingController? onboarding;

  /// Memorization (specs/006). Null in tests that do not need it: no Memorize button then.
  final MemorizationController? memorization;

  /// Prayer times and their alerts (specs/009). Null in tests that do not need them.
  final PrayerAlerts? prayer;

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
              : (context, child) {
                  syncOrientation(MediaQuery.sizeOf(context));
                  return child!;
                },
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
    final prayer = this.prayer;
    final withPrayer = prayer == null
        ? withMemorization
        : PrayerScope(alerts: prayer, child: withMemorization);
    final scoped = onboarding == null
        ? withPrayer
        : OnboardingScope(controller: onboarding, child: withPrayer);
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
///
/// While the Mushaf shows two facing pages ([showsSpread]), the column is as wide as two
/// full-size pages, within the window (specs/012 FR-016, research R7). Below it, [ScreenArea]
/// keeps the window's size, which decides one or two pages.
class PhoneColumn extends StatelessWidget {
  const PhoneColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= wideWindowMin) return child;
    final height = media.size.height;
    // The onboarding's setup steps and gesture stops cover the reader: they keep the phone column.
    final phase = OnboardingScope.maybeOf(context)?.phase;
    final onboarding = phase == OnboardingPhase.setup || phase == OnboardingPhase.gestures;
    final width = !onboarding && showsSpread(context)
        ? math.min(media.size.width,
            math.max(2 * phoneColumnWidth, 2 * PageGeometry.fullPageWidth(height)))
        : phoneColumnWidth;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: ClipRect(
            child: MediaQuery(
              data: media.copyWith(size: Size(width, height)),
              child: ScreenArea(size: media.size, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

bool? _portraitOnly;

/// On Android, portrait on phones and folded foldables, and any orientation on large screens
/// (shortest side 600 dp or more), so an open foldable can be held either way (specs/012
/// research R6). The manifest keeps phones in portrait from launch. iOS keeps its Info.plist
/// orientations, which the iPhone Duo's inner screen ignores. Calls the platform only on a change.
void syncOrientation(Size screen) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || screen.isEmpty) return;
  final portrait = screen.shortestSide < 600;
  if (portrait == _portraitOnly) return;
  _portraitOnly = portrait;
  SystemChrome.setPreferredOrientations(
      portrait ? const [DeviceOrientation.portraitUp] : const []);
}

/// Forgets the last orientation sent, so a test sees the next call.
@visibleForTesting
void resetOrientationSync() => _portraitOnly = null;

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
