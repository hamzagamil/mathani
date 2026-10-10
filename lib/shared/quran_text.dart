// Display helpers shared by the Mushaf renderer, the flowing layout and the line-width tool.
// They change only how ayah-end markers are drawn, never the Quran text itself (FR-002).

/// The basmala as drawn on basmala lines, verbatim from the Tanzil Uthmani text (CC BY 3.0).
const basmalaText = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';

/// Hizb-quarter mark (rub' al-hizb) and sajdah mark, drawn in the page margin.
const rubAlHizbMark = '۞';
const sajdahMark = '۩';

/// End-of-ayah sign. Fonts such as Amiri Quran draw it as an ornament enclosing the digits that
/// follow it; the KFGQPC Hafs font draws the digits themselves as the ornament.
const ayahEndSign = '۝';

/// The string to draw for an ayah-end marker token [text] (Eastern Arabic digits) in [font]
/// (`meta.font`: `amiri-quran` or `kfgqpc-hafs`).
String ayahEndGlyphs(String text, String font) =>
    font == 'kfgqpc-hafs' || text.startsWith(ayahEndSign) ? text : '$ayahEndSign$text';
