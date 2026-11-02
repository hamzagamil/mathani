// The printed surah headers (King Fahd Complex header font): one glyph per surah.
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/reader/surah_header_glyphs.dart';

void main() {
  test('114 distinct glyphs, as mapped by the source', () {
    expect(surahHeaderGlyphs, hasLength(114));
    expect(surahHeaderGlyphs.toSet(), hasLength(114));
    expect(surahHeaderGlyphs.first, 0xFC45); // Al-Fatiha
    expect(surahHeaderGlyphs[20], 0xFC64); // Al-Anbiya
    expect(surahHeaderGlyphs[21], 0xFB51); // Al-Hajj
    expect(surahHeaderGlyphs.last, 0xFBEB); // An-Nas
  });
}
