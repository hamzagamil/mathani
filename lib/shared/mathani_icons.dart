import 'package:flutter/widgets.dart';

/// Outline icons from Lucide (lucide-static 1.48.0, ISC; assets/fonts/LICENSE-Lucide.txt).
/// Release builds tree-shake the font down to the glyphs referenced here.
abstract final class MathaniIcons {
  static const _family = 'Lucide';

  static const mushaf = IconData(0xe05f, fontFamily: _family); // book-open
  static const flowing = IconData(0xe54b, fontFamily: _family); // book-text
  static const index = IconData(0xe106, fontFamily: _family); // list
  static const search = IconData(0xe151, fontFamily: _family);
  static const settings = IconData(0xe154, fontFamily: _family);
  static const bookmark = IconData(0xe060, fontFamily: _family);
  static const bookmarked = IconData(0xe51f, fontFamily: _family); // bookmark-check
  static const copy = IconData(0xe09e, fontFamily: _family);
  static const share = IconData(0xe156, fontFamily: _family); // share-2
  static const goTo = IconData(0xe0ef, fontFamily: _family); // hash
  static const close = IconData(0xe1b2, fontFamily: _family); // x
  static const clear = IconData(0xe084, fontFamily: _family); // circle-x
  static const check = IconData(0xe06c, fontFamily: _family);
  static const delete = IconData(0xe18e, fontFamily: _family); // trash-2
  static const day = IconData(0xe178, fontFamily: _family); // sun
  static const night = IconData(0xe11e, fontFamily: _family); // moon
  static const themeSystem = IconData(0xe2b2, fontFamily: _family); // sun-moon
  static const textSize = IconData(0xe198, fontFamily: _family); // type
  static const screenOn = IconData(0xe163, fontFamily: _family); // smartphone
  static const language = IconData(0xe0fe, fontFamily: _family); // languages
  static const info = IconData(0xe0f9, fontFamily: _family);
  static const externalLink = IconData(0xe0b9, fontFamily: _family);
  static const download = IconData(0xe0b2, fontFamily: _family);
  static const downloaded = IconData(0xe226, fontFamily: _family); // circle-check
  static const more = IconData(0xe0b6, fontFamily: _family); // ellipsis
  static const recitation = IconData(0xe0f1, fontFamily: _family); // headphones

  // Media controls (specs/004). They keep their left-to-right form in Arabic, as media players
  // do everywhere: play points right, and previous/next follow the timeline, not the text.
  static const play = IconData(0xe13c, fontFamily: _family);
  static const pause = IconData(0xe12e, fontFamily: _family);
  static const previous = IconData(0xe15f, fontFamily: _family); // skip-back
  static const next = IconData(0xe160, fontFamily: _family); // skip-forward

  // Direction icons mirror with the interface direction; media icons never do (brand guide).
  // Glyphs are the left-to-right forms; they flip automatically in Arabic (RTL).
  static const back = IconData(0xe06e, fontFamily: _family, matchTextDirection: true); // chevron-left
  static const forward = IconData(0xe06f, fontFamily: _family, matchTextDirection: true); // chevron-right
}
