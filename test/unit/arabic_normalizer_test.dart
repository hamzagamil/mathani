import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/search/arabic_normalizer.dart';

void main() {
  test('strips tashkeel, Quranic marks and tatweel', () {
    expect(normalizeArabic('ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ'), 'الرحمن الرحيم');
    // Uthmani writes some alefs as a superscript mark, which is stripped: «ٱلْكِتَـٰبُ» → «الكتب».
    // This is why search runs on the imla'i text (research R7), not on normalised Uthmani.
    expect(normalizeArabic('ذَٰلِكَ ٱلْكِتَـٰبُ لَا رَيْبَ ۛ فِيهِ ۛ'), 'ذلك الكتب لا ريب فيه');
  });

  test('unifies alef, hamza, yaa and taa marbuta forms', () {
    expect(normalizeArabic('أإآٱا'), 'ااااا');
    expect(normalizeArabic('مؤمن شيئ هدى رحمة'), 'مومن شيي هدي رحمه');
  });

  test('collapses and trims whitespace', () {
    expect(normalizeArabic('  بسم   الله \n الرحمن  '), 'بسم الله الرحمن');
  });

  test('query and text normalise to the same form', () {
    expect(normalizeArabic('الرحمن الرحيم'), normalizeArabic('ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ'));
  });
}
