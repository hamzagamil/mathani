// Transcribed from the Mathani brand design system («مثاني — دليل الهوية»), project/tokens.json
// v1 (claude.ai artifact 2b08b81b-3fa4-4d13-8806-2681e820b520). Do not edit values here without
// changing the brand guide first.
import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';

/// A colour with a day (light) and night (dark) value.
class ThemedColor {
  const ThemedColor(this.day, this.night);
  final Color day;
  final Color night;
  Color of(Brightness b) => b == Brightness.dark ? night : day;
}

abstract final class BrandColors {
  // Identity colours (same in both themes). UI code uses the semantic tokens below.
  static const navy = Color(0xFF183159);
  static const gold = Color(0xFFBA9757);
  static const teal = Color(0xFF456967);
  static const cream = Color(0xFFF2EADD);
  static const terracotta = Color(0xFFC37254);
}

abstract final class SemanticColors {
  static const surface = ThemedColor(Color(0xFFF2EADD), Color(0xFF0E1A2E));
  static const surfaceRaised = ThemedColor(Color(0xFFFBF6F0), Color(0xFF16263F));
  static const surfaceSunken = ThemedColor(Color(0xFFE9DFCD), Color(0xFF0A1424));
  static const bar = ThemedColor(Color(0xFF183159), Color(0xFF1B2E4D));
  static const ink = ThemedColor(Color(0xFF183159), Color(0xFFEDE4D3));
  static const inkMuted = ThemedColor(Color(0xFF4C5466), Color(0xFFA7AEBD));
  static const inkOnBar = ThemedColor(Color(0xFFF2EADD), Color(0xFFEDE4D3));
  static const accent = ThemedColor(Color(0xFFBA9757), Color(0xFFCDAE6E));
  static const accentInk = ThemedColor(Color(0xFF755728), Color(0xFFD9BD82));
  static const onAccent = ThemedColor(Color(0xFF183159), Color(0xFF10203A));
  static const selected = ThemedColor(Color(0xFFDFC7A2), Color(0xFF3A3222));
  static const rowSelected = ThemedColor(Color(0xFFEADCC0), Color(0xFF2B2B26));
  static const secondary = ThemedColor(Color(0xFF456967), Color(0xFF86AFAB));
  static const secondarySoft = ThemedColor(Color(0xFFDCE6E3), Color(0xFF1C3436));
  static const line = ThemedColor(Color(0xFFD9CCB5), Color(0xFF2B3D59));
  static const focusRing = ThemedColor(Color(0xFF183159), Color(0xFFD9BD82));
  static const focusRingOnBar = ThemedColor(Color(0xFFBA9757), Color(0xFFD9BD82));
}

abstract final class Space {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0; // screen side gutter
  static const s6 = 24.0; // between sections
  static const s8 = 32.0;
}

abstract final class Radii {
  static const sm = 8.0; // chips
  static const md = 12.0; // cards
  static const lg = 20.0; // bottom sheets
  static const pill = 999.0;
}

abstract final class Sizes {
  static const appBarHeight = 56.0;
  static const touchMin = 44.0; // iOS; Android uses 48 dp (contracts/ui-screens.md)
}

/// Type scale. Interface styles use [uiFamily]; Quran styles use [quranFamily].
abstract final class TypeScale {
  static const uiFamily = 'PlexArabic';
  static const quranFamily = 'QuranText';

  static const display = TextStyle(fontSize: 32, height: 44 / 32, fontWeight: FontWeight.w700);
  static const titleLg = TextStyle(fontSize: 22, height: 32 / 22, fontWeight: FontWeight.w700);
  static const appbarTitle = TextStyle(fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w600);
  static const titleSm = TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 15, height: 24 / 15, fontWeight: FontWeight.w400);
  static const caption = TextStyle(fontSize: 12, height: 18 / 12, fontWeight: FontWeight.w400);
  static const label = TextStyle(fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w500);

  /// Line height 2.0 so tashkeel never collides (brand guide).
  static const quranLineHeight = 2.0;
  static const quranPage = TextStyle(fontFamily: quranFamily, fontSize: 24, height: 2.0);
  static const quranCard = TextStyle(fontFamily: quranFamily, fontSize: 20, height: 38 / 20);
  static const basmala = TextStyle(fontFamily: quranFamily, fontSize: 22, height: 40 / 22);
}
