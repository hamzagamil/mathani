import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/numerals.dart';
import '../../shared/reader_state.dart';
import 'about_section.dart';

/// Reading layout, theme, flowing text size, keep-screen-on and language. Every change applies
/// immediately and persists (FR-016–FR-019, FR-025).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    final prefs = reader.preferences;
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final locale = Localizations.localeOf(context);
    // Always derive from the current preferences: two quick changes before a rebuild must
    // not overwrite each other with a stale copy.
    void set(ReaderPreferences Function(ReaderPreferences p) change) =>
        reader.updatePreferences(change(reader.preferences));

    Widget section(String title, Widget child, {String? hint}) => Padding(
          padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: TypeScale.titleSm.copyWith(color: colors.ink)),
              if (hint != null)
                Text(hint, style: TypeScale.caption.copyWith(color: colors.inkMuted)),
              const SizedBox(height: Space.s2),
              child,
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(MathaniIcons.back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.settingsTitle),
      ),
      body: ListView(
        children: [
          section(
            l10n.layoutSetting,
            SegmentedButton<ReadingLayout>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ReadingLayout.mushaf,
                  icon: const Icon(MathaniIcons.mushaf),
                  label: Text(l10n.layoutMushaf),
                ),
                ButtonSegment(
                  value: ReadingLayout.flowing,
                  icon: const Icon(MathaniIcons.flowing),
                  label: Text(l10n.layoutFlowing),
                ),
              ],
              selected: {prefs.layout},
              onSelectionChanged: (s) => set((p) => p.copyWith(layout: s.first)),
            ),
          ),
          section(
            l10n.themeSetting,
            SegmentedButton<ThemePref>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ThemePref.system,
                  icon: const Icon(MathaniIcons.themeSystem),
                  // With an icon, «حسب الجهاز» wraps to two lines in a third of a phone's width;
                  // shrink it to one line instead.
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.themeSystem)),
                ),
                ButtonSegment(
                  value: ThemePref.day,
                  icon: const Icon(MathaniIcons.day),
                  label: Text(l10n.themeDay),
                ),
                ButtonSegment(
                  value: ThemePref.night,
                  icon: const Icon(MathaniIcons.night),
                  label: Text(l10n.themeNight),
                ),
              ],
              selected: {prefs.theme},
              onSelectionChanged: (s) => set((p) => p.copyWith(theme: s.first)),
            ),
          ),
          if (prefs.layout == ReadingLayout.flowing)
            section(
              l10n.textSizeSetting,
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      min: ReaderPreferences.minFlowFontSize.toDouble(),
                      max: ReaderPreferences.maxFlowFontSize.toDouble(),
                      divisions:
                          ReaderPreferences.maxFlowFontSize - ReaderPreferences.minFlowFontSize,
                      value: prefs.flowFontSize.toDouble(),
                      label: formatNumber(prefs.flowFontSize, locale),
                      onChanged: (v) => set((p) => p.copyWith(flowFontSize: v.round())),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      formatNumber(prefs.flowFontSize, locale),
                      textAlign: TextAlign.center,
                      style: TypeScale.titleSm.copyWith(color: colors.accentInk),
                    ),
                  ),
                ],
              ),
              hint: l10n.textSizeHint,
            ),
          if (reader.quran.hasPrintedLettering)
            Padding(
              padding: const EdgeInsets.only(top: Space.s3),
              child: SwitchListTile(
                secondary: const Icon(MathaniIcons.mushaf),
                title: Text(l10n.printedLetteringSetting),
                subtitle: Text(
                  l10n.printedLetteringHint,
                  style: TypeScale.caption.copyWith(color: colors.inkMuted),
                ),
                value: prefs.lettering == Lettering.printed,
                onChanged: (v) =>
                    set((p) => p.copyWith(lettering: v ? Lettering.printed : Lettering.builtin)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: Space.s3),
            child: SwitchListTile(
              secondary: const Icon(MathaniIcons.screenOn),
              title: Text(l10n.keepScreenOnSetting),
              subtitle: Text(
                l10n.keepScreenOnHint,
                style: TypeScale.caption.copyWith(color: colors.inkMuted),
              ),
              value: prefs.keepScreenOn,
              onChanged: (v) => set((p) => p.copyWith(keepScreenOn: v)),
            ),
          ),
          section(
            l10n.languageSetting,
            SegmentedButton<LanguagePref>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: LanguagePref.system, label: Text(l10n.languageSystem)),
                const ButtonSegment(value: LanguagePref.ar, label: Text('العربية')),
                const ButtonSegment(value: LanguagePref.en, label: Text('English')),
              ],
              selected: {prefs.language},
              onSelectionChanged: (s) => set((p) => p.copyWith(language: s.first)),
            ),
          ),
          const SizedBox(height: Space.s4),
          Divider(color: colors.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s4, Space.s2, Space.s4, 0),
            child: Text(l10n.aboutTitle, style: TypeScale.titleSm.copyWith(color: colors.ink)),
          ),
          const AboutSection(),
          const SizedBox(height: Space.s8),
        ],
      ),
    );
  }
}
