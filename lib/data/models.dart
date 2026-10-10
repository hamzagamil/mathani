// Immutable data models. Fields and rules: specs/001-quran-mushaf-reader/data-model.md.

enum Revelation { makki, madani }

enum LineType { ayah, surahName, basmallah }

enum DivisionKind { juz, hizbQuarter }

enum ReadingLayout { mushaf, flowing }

enum ThemePref { system, day, night }

enum LanguagePref { system, ar, en }

/// A surah:ayah reference. Value type used for anchors, selection and navigation.
class AyahRef implements Comparable<AyahRef> {
  const AyahRef(this.surah, this.ayah);

  final int surah;
  final int ayah;

  @override
  int compareTo(AyahRef other) =>
      surah != other.surah ? surah.compareTo(other.surah) : ayah.compareTo(other.ayah);

  @override
  bool operator ==(Object other) =>
      other is AyahRef && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surah, ayah);

  @override
  String toString() => '$surah:$ayah';
}

class Surah {
  const Surah({
    required this.number,
    required this.nameAr,
    required this.nameTranslit,
    required this.ayahCount,
    required this.revelation,
    required this.startPage,
  });

  final int number; // 1..114
  final String nameAr;
  final String nameTranslit;
  final int ayahCount;
  final Revelation revelation;
  final int startPage; // 1..604
}

class Ayah {
  const Ayah({
    required this.id,
    required this.surah,
    required this.ayah,
    required this.page,
    required this.juz,
    required this.hizbQuarter,
    required this.sajdah,
    required this.firstWordId,
    required this.lastWordId,
  });

  final int id; // 1..6236
  final int surah;
  final int ayah;
  final int page; // page where the ayah starts
  final int juz; // 1..30
  final int hizbQuarter; // 1..240
  final bool sajdah;
  final int firstWordId;
  final int lastWordId;

  AyahRef get ref => AyahRef(surah, ayah);
}

class Word {
  const Word({
    required this.id,
    required this.surah,
    required this.ayah,
    required this.position,
    required this.text,
    required this.isAyahEnd,
  });

  final int id;
  final int surah;
  final int ayah;
  final int position; // from 1 within the ayah
  final String text; // exact Uthmani text (FR-002)
  final bool isAyahEnd;

  AyahRef get ref => AyahRef(surah, ayah);
}

class MushafLine {
  const MushafLine({
    required this.page,
    required this.line,
    required this.type,
    required this.centered,
    this.words = const [],
    this.surah,
  });

  final int page; // 1..604
  final int line; // 1..15
  final LineType type;
  final bool centered;
  final List<Word> words; // only for LineType.ayah
  final int? surah; // only for surahName / basmallah
}

/// One Mushaf page with its lines (Mushaf layout) and the ayahs that start on it.
class MushafPage {
  const MushafPage({required this.number, required this.lines});

  final int number;
  final List<MushafLine> lines;
}

class Division {
  const Division({
    required this.kind,
    required this.number,
    required this.start,
    required this.startPage,
    required this.openingWords,
  });

  final DivisionKind kind;
  final int number; // juz 1..30, quarter 1..240
  final AyahRef start;
  final int startPage;
  final String openingWords;

  /// For a hizb quarter: hizb = ⌈quarter / 4⌉, juz = ⌈quarter / 8⌉.
  int get hizb => (number + 3) ~/ 4;
  int get juzOfQuarter => (number + 7) ~/ 8;
}

class Bookmark {
  const Bookmark({
    required this.id,
    required this.ref,
    required this.page,
    required this.createdAt,
  });

  final int id;
  final AyahRef ref;
  final int page;
  final DateTime createdAt;
}

class ReaderPreferences {
  const ReaderPreferences({
    this.layout = ReadingLayout.mushaf,
    this.theme = ThemePref.system,
    this.flowFontSize = 24,
    this.keepScreenOn = false,
    this.language = LanguagePref.system,
  });

  static const minFlowFontSize = 18;
  static const maxFlowFontSize = 34;

  final ReadingLayout layout;
  final ThemePref theme;
  final int flowFontSize; // 18..34
  final bool keepScreenOn;
  final LanguagePref language;

  ReaderPreferences copyWith({
    ReadingLayout? layout,
    ThemePref? theme,
    int? flowFontSize,
    bool? keepScreenOn,
    LanguagePref? language,
  }) =>
      ReaderPreferences(
        layout: layout ?? this.layout,
        theme: theme ?? this.theme,
        flowFontSize: flowFontSize ?? this.flowFontSize,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        language: language ?? this.language,
      );
}
