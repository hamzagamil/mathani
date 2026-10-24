// The preference steps of the onboarding (specs/005-app-onboarding/contracts/onboarding-ui.md ›
// OnboardingScreen). Each choice is applied and saved at once, through the same calls as
// Settings (FR-008, FR-012).
import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../shared/device_channel.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/numerals.dart';
import '../../shared/reader_state.dart';
import '../reader/flowing_view.dart';
import '../recitation/recitation_controller.dart';
import '../recitation/reciter_sheet.dart';
import 'tour_illustration.dart';

/// A large choice, read by screen readers as one of a group of radio buttons.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MathaniColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s2),
      child: Material(
        color: selected ? colors.rowSelected : colors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: selected ? colors.accent : colors.line, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                inMutuallyExclusiveGroup: true,
                checked: selected,
                button: true,
                child: InkWell(
                  onTap: onTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
                      child: Row(
                        children: [
                          if (icon != null) ...[
                            Icon(icon, color: colors.ink),
                            const SizedBox(width: Space.s3),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: TypeScale.titleSm.copyWith(color: colors.ink)),
                                if (subtitle != null)
                                  Text(subtitle!,
                                      style: TypeScale.caption.copyWith(color: colors.inkMuted)),
                              ],
                            ),
                          ),
                          ExcludeSemantics(
                            child: Icon(MathaniIcons.check,
                                color: selected ? colors.accentInk : Colors.transparent),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Always derive from the current preferences, as Settings does: two quick changes before a
/// rebuild must not overwrite each other.
void _set(ReaderController reader, ReaderPreferences Function(ReaderPreferences p) change) =>
    reader.updatePreferences(change(reader.preferences));

/// «أهلاً بك في مثاني» · "Welcome to Mathani", in both languages, so either reader knows where
/// they are before choosing.
class OnboardingWelcome extends StatelessWidget {
  const OnboardingWelcome({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = MathaniColors.of(context);
    final style = TypeScale.titleSm.copyWith(color: colors.accentInk);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(lookupAppLocalizations(const Locale('ar')).onboardingWelcome,
            style: style, textDirection: TextDirection.rtl, textAlign: TextAlign.center),
        Text(lookupAppLocalizations(const Locale('en')).onboardingWelcome,
            style: style, textDirection: TextDirection.ltr, textAlign: TextAlign.center),
      ],
    );
  }
}

class LanguageStep extends StatelessWidget {
  const LanguageStep({super.key});

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    final l10n = AppLocalizations.of(context);
    final current = reader.preferences.language;
    // The language "follow the device" gives (edge case: neither Arabic nor English → English).
    final device = MathaniApp.resolveLocale(
        LanguagePref.system, WidgetsBinding.instance.platformDispatcher.locales);
    final deviceName = device.languageCode == 'ar' ? 'العربية' : 'English';
    void choose(LanguagePref p) => _set(reader, (prefs) => prefs.copyWith(language: p));
    return Column(
      children: [
        _ChoiceCard(
          icon: MathaniIcons.language,
          title: l10n.onboardingSystemLanguage(deviceName),
          selected: current == LanguagePref.system,
          onTap: () => choose(LanguagePref.system),
        ),
        _ChoiceCard(
          title: 'العربية',
          selected: current == LanguagePref.ar,
          onTap: () => choose(LanguagePref.ar),
        ),
        _ChoiceCard(
          title: 'English',
          selected: current == LanguagePref.en,
          onTap: () => choose(LanguagePref.en),
        ),
      ],
    );
  }
}

class ThemeStep extends StatelessWidget {
  const ThemeStep({super.key});

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    final l10n = AppLocalizations.of(context);
    final current = reader.preferences.theme;
    void choose(ThemePref t) => _set(reader, (p) => p.copyWith(theme: t));
    return Column(
      children: [
        TourIllustration(layout: reader.layout),
        const SizedBox(height: Space.s4),
        _ChoiceCard(
          icon: MathaniIcons.themeSystem,
          title: l10n.themeSystem,
          selected: current == ThemePref.system,
          onTap: () => choose(ThemePref.system),
        ),
        _ChoiceCard(
          icon: MathaniIcons.day,
          title: l10n.themeDay,
          selected: current == ThemePref.day,
          onTap: () => choose(ThemePref.day),
        ),
        _ChoiceCard(
          icon: MathaniIcons.night,
          title: l10n.themeNight,
          selected: current == ThemePref.night,
          onTap: () => choose(ThemePref.night),
        ),
      ],
    );
  }
}

class LayoutStep extends StatelessWidget {
  const LayoutStep({super.key});

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    final l10n = AppLocalizations.of(context);
    final current = reader.layout;
    void choose(ReadingLayout l) => _set(reader, (p) => p.copyWith(layout: l));
    return Column(
      children: [
        TourIllustration(layout: current),
        const SizedBox(height: Space.s4),
        _ChoiceCard(
          icon: MathaniIcons.mushaf,
          title: l10n.layoutMushaf,
          subtitle: l10n.onboardingLayoutMushafHint,
          selected: current == ReadingLayout.mushaf,
          onTap: () => choose(ReadingLayout.mushaf),
        ),
        _ChoiceCard(
          icon: MathaniIcons.flowing,
          title: l10n.layoutFlowing,
          subtitle: l10n.onboardingLayoutFlowingHint,
          selected: current == ReadingLayout.flowing,
          onTap: () => choose(ReadingLayout.flowing),
        ),
      ],
    );
  }
}

/// The flowing text size, with Al-Fatiha 1–3 set at that size (Story 1 AS5).
class TextSizeStep extends StatefulWidget {
  const TextSizeStep({super.key});

  @override
  State<TextSizeStep> createState() => _TextSizeStepState();
}

class _TextSizeStepState extends State<TextSizeStep> {
  String? _sample;

  @override
  void initState() {
    super.initState();
    final quran = ReaderScope.read(context).quran;
    unawaited(quran.flowingPage(1).then((page) {
      if (!mounted) return;
      setState(() => _sample = [
            for (final (_, words) in page.take(3)) flowingAyahText(words, quran.font),
          ].join());
    }));
  }

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    final colors = MathaniColors.of(context);
    final locale = Localizations.localeOf(context);
    final size = reader.preferences.flowFontSize;
    final sample = _sample;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Slider(
                min: ReaderPreferences.minFlowFontSize.toDouble(),
                max: ReaderPreferences.maxFlowFontSize.toDouble(),
                divisions: ReaderPreferences.maxFlowFontSize - ReaderPreferences.minFlowFontSize,
                value: size.toDouble(),
                label: formatNumber(size, locale),
                onChanged: (v) => _set(reader, (p) => p.copyWith(flowFontSize: v.round())),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                formatNumber(size, locale),
                textAlign: TextAlign.center,
                style: TypeScale.titleSm.copyWith(color: colors.accentInk),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.s2),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: colors.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Space.s4),
            child: sample == null
                // Fixed height until the words load, so nothing jumps.
                ? SizedBox(height: size * 2.0 * 3)
                : Text(
                    sample,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.justify,
                    style: flowingTextStyle(colors, size.toDouble()),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Choose the reciter, with a short sample of each (FR-010).
class ReciterStep extends StatefulWidget {
  const ReciterStep({super.key});

  @override
  State<ReciterStep> createState() => _ReciterStepState();
}

class _ReciterStepState extends State<ReciterStep> {
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    // Read once when the step opens; a sample that fails later shows the same note.
    unawaited(const DeviceChannel().networkState().then((n) {
      if (mounted && n == NetworkState.none) setState(() => _offline = true);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    final recitation = RecitationScope.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final selected = reader.quran.reciterOrDefault(reader.preferences.reciter)?.id;
    final preview = recitation?.preview;
    final unavailable = _offline || preview?.status == PreviewStatus.unavailable;

    Widget sampleButton(Reciter r) {
      final mine = preview?.reciterId == r.id ? preview : null;
      final active = mine != null && mine.status != PreviewStatus.unavailable;
      final name = r.name(arabic: arabic);
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: Space.s2),
        child: IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          tooltip: '${active ? l10n.stopSample : l10n.playSample}, $name',
          onPressed: _offline || recitation == null
              ? null
              : () => active ? recitation.stopPreview() : recitation.previewReciter(r),
          icon: switch (mine?.status) {
            PreviewStatus.loading => const SizedBox.square(
                dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            PreviewStatus.playing => const Icon(MathaniIcons.pause),
            _ => const Icon(MathaniIcons.play),
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in reader.quran.reciters)
          _ChoiceCard(
            title: r.name(arabic: arabic),
            // The Arabic name is always shown, as in the reciter sheet.
            subtitle: arabic ? l10n.murattal : '${r.nameAr} · ${l10n.murattal}',
            selected: r.id == selected,
            trailing: sampleButton(r),
            onTap: () => chooseReciter(reader, recitation, r),
          ),
        const SizedBox(height: Space.s2),
        Text(l10n.onboardingReciterHint, style: TypeScale.caption.copyWith(color: colors.inkMuted)),
        if (unavailable) ...[
          const SizedBox(height: Space.s3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(MathaniIcons.info, size: 18, color: colors.inkMuted),
              const SizedBox(width: Space.s2),
              Expanded(
                child: Text(l10n.sampleOffline,
                    style: TypeScale.caption.copyWith(color: colors.inkMuted)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
