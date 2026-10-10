// Pure Dart (no Flutter imports) so tool/build_quran_db.dart can reuse it to build
// ayahs.search_text. Rules: research R7.

/// Normalises Arabic text for diacritic- and spelling-insensitive search.
///
/// Strips tashkeel and Quranic annotation marks, unifies alef/hamza/yaa/taa-marbuta forms,
/// removes tatweel and collapses whitespace. The same function must be applied to both the
/// indexed text and the user's query.
String normalizeArabic(String input) {
  final out = StringBuffer();
  var lastWasSpace = true; // trims leading whitespace
  for (final rune in input.runes) {
    if (_isStripped(rune)) continue;
    final mapped = _unify[rune] ?? rune;
    if (_isSpace(mapped)) {
      if (!lastWasSpace) out.writeCharCode(0x20);
      lastWasSpace = true;
      continue;
    }
    out.writeCharCode(mapped);
    lastWasSpace = false;
  }
  final s = out.toString();
  return s.endsWith(' ') ? s.substring(0, s.length - 1) : s;
}

bool _isStripped(int c) =>
    (c >= 0x0610 && c <= 0x061A) || // Quranic honorifics and small marks
    (c >= 0x064B && c <= 0x065F) || // tashkeel (fathatan .. wavy hamza below)
    c == 0x0670 || // superscript alef
    (c >= 0x06D6 && c <= 0x06ED) || // Quranic annotation marks, pause signs, ayah-end sign
    c == 0x0640; // tatweel

bool _isSpace(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0xA0;

const Map<int, int> _unify = {
  0x0623: 0x0627, // أ → ا
  0x0625: 0x0627, // إ → ا
  0x0622: 0x0627, // آ → ا
  0x0671: 0x0627, // ٱ (alef wasla) → ا
  0x0649: 0x064A, // ى → ي
  0x0624: 0x0648, // ؤ → و
  0x0626: 0x064A, // ئ → ي
  0x0629: 0x0647, // ة → ه
};
