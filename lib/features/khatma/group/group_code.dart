// A group khatma's code and link (specs/014 research R16). Plain Dart.

/// 16 characters of Crockford base32 (80 random bits), shown in groups of four.
abstract final class GroupCode {
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const linkBase = 'https://get.mthani.app/k/';

  /// The code in [text]: a code alone, or a whole link. Case, spaces and hyphens are ignored, and
  /// the letters Crockford reads as digits (O, I, L) are read as them. Null for anything else.
  static String? parse(String text) {
    var t = text.trim();
    final link = RegExp(r'/k/([0-9A-Za-z\- ]+)').firstMatch(t);
    if (link != null) t = link.group(1)!;
    t = t.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    t = t.replaceAll('O', '0').replaceAll('I', '1').replaceAll('L', '1');
    if (t.length != 16) return null;
    for (final c in t.split('')) {
      if (!_alphabet.contains(c)) return null;
    }
    return t;
  }

  /// `XXXX-XXXX-XXXX-XXXX`.
  static String format(String code) => [
        for (var i = 0; i < code.length; i += 4) code.substring(i, i + 4 > code.length ? code.length : i + 4),
      ].join('-');

  static String linkOf(String code) => '$linkBase$code';
}
