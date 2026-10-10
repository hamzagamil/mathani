import 'dart:ui' show Locale;

/// Converts [value] to Eastern Arabic digits (٠–٩). Used inside the Mushaf in every language.
String toEasternArabic(int value) {
  final s = value.toString();
  final out = StringBuffer();
  for (final unit in s.codeUnits) {
    out.writeCharCode(unit >= 0x30 && unit <= 0x39 ? unit - 0x30 + 0x0660 : unit);
  }
  return out.toString();
}

/// Formats an interface number: Eastern Arabic digits in Arabic, Western digits otherwise.
String formatNumber(int value, Locale locale) =>
    locale.languageCode == 'ar' ? toEasternArabic(value) : value.toString();
