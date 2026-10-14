import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Semantic colours for the current theme. Read with `MathaniColors.of(context)`.
@immutable
class MathaniColors extends ThemeExtension<MathaniColors> {
  const MathaniColors({
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.bar,
    required this.ink,
    required this.inkMuted,
    required this.inkOnBar,
    required this.accent,
    required this.accentInk,
    required this.onAccent,
    required this.selected,
    required this.rowSelected,
    required this.secondary,
    required this.secondarySoft,
    required this.line,
    required this.focusRing,
    required this.focusRingOnBar,
  });

  factory MathaniColors.forBrightness(Brightness b) => MathaniColors(
        surface: SemanticColors.surface.of(b),
        surfaceRaised: SemanticColors.surfaceRaised.of(b),
        surfaceSunken: SemanticColors.surfaceSunken.of(b),
        bar: SemanticColors.bar.of(b),
        ink: SemanticColors.ink.of(b),
        inkMuted: SemanticColors.inkMuted.of(b),
        inkOnBar: SemanticColors.inkOnBar.of(b),
        accent: SemanticColors.accent.of(b),
        accentInk: SemanticColors.accentInk.of(b),
        onAccent: SemanticColors.onAccent.of(b),
        selected: SemanticColors.selected.of(b),
        rowSelected: SemanticColors.rowSelected.of(b),
        secondary: SemanticColors.secondary.of(b),
        secondarySoft: SemanticColors.secondarySoft.of(b),
        line: SemanticColors.line.of(b),
        focusRing: SemanticColors.focusRing.of(b),
        focusRingOnBar: SemanticColors.focusRingOnBar.of(b),
      );

  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color bar;
  final Color ink;
  final Color inkMuted;
  final Color inkOnBar;
  final Color accent;
  final Color accentInk;
  final Color onAccent;
  final Color selected;
  final Color rowSelected;
  final Color secondary;
  final Color secondarySoft;
  final Color line;
  final Color focusRing;
  final Color focusRingOnBar;

  static MathaniColors of(BuildContext context) =>
      Theme.of(context).extension<MathaniColors>()!;

  @override
  MathaniColors copyWith() => this;

  @override
  MathaniColors lerp(MathaniColors? other, double t) => t < 0.5 || other == null ? this : other;
}

/// Minimum touch target: 44 pt on iOS, 48 dp on Android (constitution II).
double get minTouchTarget =>
    defaultTargetPlatform == TargetPlatform.iOS ? Sizes.touchMin : 48.0;

ThemeData buildTheme(Brightness brightness) {
  final c = MathaniColors.forBrightness(brightness);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.bar,
    onPrimary: c.inkOnBar,
    secondary: c.accent,
    onSecondary: c.onAccent,
    tertiary: c.secondary,
    onTertiary: c.surface,
    error: const Color(0xFFB3261E),
    onError: Colors.white,
    surface: c.surface,
    onSurface: c.ink,
    onSurfaceVariant: c.inkMuted,
    surfaceContainerLowest: c.surfaceSunken,
    surfaceContainer: c.surfaceRaised,
    surfaceContainerHigh: c.surfaceRaised,
    outline: c.line,
    outlineVariant: c.line,
  );

  TextStyle ui(TextStyle s, Color color) =>
      s.copyWith(fontFamily: TypeScale.uiFamily, color: color);

  final textTheme = TextTheme(
    displayLarge: ui(TypeScale.display, c.ink),
    headlineSmall: ui(TypeScale.titleLg, c.ink),
    titleLarge: ui(TypeScale.appbarTitle, c.ink),
    titleMedium: ui(TypeScale.titleSm, c.ink),
    titleSmall: ui(TypeScale.titleSm, c.ink),
    bodyLarge: ui(TypeScale.body, c.ink),
    bodyMedium: ui(TypeScale.body, c.ink),
    bodySmall: ui(TypeScale.caption, c.inkMuted),
    labelLarge: ui(TypeScale.titleSm, c.ink),
    labelMedium: ui(TypeScale.label, c.ink),
    labelSmall: ui(TypeScale.label, c.inkMuted),
  );

  final target = minTouchTarget;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: TypeScale.uiFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: c.surface,
    dividerColor: c.line,
    extensions: [c],
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: Size(target, target)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bar,
      foregroundColor: c.inkOnBar,
      centerTitle: true,
      elevation: 0,
      toolbarHeight: Sizes.appBarHeight,
      titleTextStyle: ui(TypeScale.appbarTitle, c.inkOnBar),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surfaceSunken,
      selectedColor: c.selected,
      labelStyle: ui(TypeScale.label, c.ink),
      shape: const StadiumBorder(),
      side: BorderSide.none,
    ),
    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      selectedTileColor: c.rowSelected,
      // Without this, selected rows use `primary` (the bar navy), unreadable on the night row.
      selectedColor: c.ink,
      iconColor: c.ink,
      textColor: c.ink,
      minVerticalPadding: Space.s3,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.s4),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.bar,
      contentTextStyle: ui(TypeScale.body, c.inkOnBar),
      behavior: SnackBarBehavior.floating,
    ),
    sliderTheme: SliderThemeData(activeTrackColor: c.accent, thumbColor: c.accent),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onAccent : c.inkMuted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.surfaceSunken),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceSunken,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.md)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(Radii.md)),
        borderSide: BorderSide(color: c.focusRing, width: 2),
      ),
    ),
  );
}
