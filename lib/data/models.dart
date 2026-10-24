// Immutable data models. Fields and rules: specs/001-quran-mushaf-reader/data-model.md.

enum Revelation { makki, madani }

enum LineType { ayah, surahName, basmallah }

enum DivisionKind { juz, hizbQuarter }

enum ReadingLayout { mushaf, flowing }

/// How Mushaf pages are lettered (specs/002, User Story 4): the King Fahd Complex page fonts,
/// exactly as printed, or the bundled Quran font set like print with kashida.
enum Lettering { printed, builtin }

enum ThemePref { system, day, night }

enum LanguagePref { system, ar, en }

/// How a mistake is signalled during memorization, besides the mark on screen (specs/006 FR-015).
enum MistakeSignal { vibrate, sound, none }

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

/// Where a reciter's recordings come from (specs/006 data-model › Reciter).
enum RecitationSource {
  /// One file per ayah on EveryAyah.
  everyayah,

  /// One file per ayah on a QUL host.
  qulAyah,

  /// One file per surah on a QUL host; each ayah is a byte range of it (specs/006 research R18).
  qulSurah;

  static RecitationSource parse(String value) => switch (value) {
        'qul_ayah' => qulAyah,
        'qul_surah' => qulSurah,
        _ => everyayah,
      };
}

/// The recording style shown after the reciter's name (specs/006 research R3).
enum RecitationStyle {
  murattal,
  mujawwad,

  /// Teaching recordings: each ayah recited with repetitions for learners.
  muallim;

  static RecitationStyle parse(String value) =>
      values.firstWhere((s) => s.name == value, orElse: () => murattal);
}

/// A reciter offered in the app, from the `reciters` table of quran.db
/// (specs/004-ayah-recitations/contracts/recitation-catalogue.md, changed by specs/006). Every
/// reciter has a recording of all 6,236 ayat. Al-Fatiha 1:1 doubles as the basmala, except for
/// reciters whose basmala is part of ayah 1 ([basmalaInAyah1]).
class Reciter {
  const Reciter({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.shortAr,
    required this.shortEn,
    required this.style,
    required this.baseUrl,
    required this.mirrorUrl,
    required this.bitrateKbps,
    required this.sort,
    this.source = RecitationSource.everyayah,
    this.filePattern = '{sss}{aaa}.mp3',
    this.basmalaInAyah1 = false,
  });

  static const defaultId = 'husary';

  final String id; // stable slug, used in preferences and file paths
  final String nameAr;
  final String nameEn;
  final String shortAr; // bar chip
  final String shortEn;
  final RecitationStyle style;
  final String baseUrl; // ends in `/` only where the host's path has a double slash
  final String? mirrorUrl; // null for QUL hosts
  final int bitrateKbps;
  final int sort;
  final RecitationSource source;
  final String filePattern; // `{sss}{aaa}.mp3`, or `{sss}.mp3` / `{s}.mp3` for surah files
  final bool basmalaInAyah1; // surah files: the basmala is inside ayah 1's clip

  String name({required bool arabic}) => arabic ? nameAr : nameEn;
  String shortName({required bool arabic}) => arabic ? shortAr : shortEn;

  /// The file holding [surah]:[ayah]: `<base>/<SSS><AAA>.mp3` for ayah sources, or the surah's
  /// file for [RecitationSource.qulSurah] (the ayah is then a byte range of it,
  /// [QuranRepository.clipRange]). Throws if [mirror] is asked of a reciter without one.
  String urlFor(int surah, int ayah, {bool mirror = false}) {
    final base = mirror ? mirrorUrl! : baseUrl;
    final file = filePattern
        .replaceAll('{sss}', pad3(surah))
        .replaceAll('{s}', '$surah')
        .replaceAll('{aaa}', pad3(ayah));
    return '$base/$file';
  }

  @override
  bool operator ==(Object other) => other is Reciter && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

String pad3(int n) => n.toString().padLeft(3, '0');

class ReaderPreferences {
  const ReaderPreferences({
    this.layout = ReadingLayout.mushaf,
    this.theme = ThemePref.system,
    this.flowFontSize = 24,
    this.keepScreenOn = false,
    this.language = LanguagePref.system,
    this.lettering = Lettering.printed,
    this.reciter = Reciter.defaultId,
    this.onboardingDone = false,
    this.mistakeSignal = MistakeSignal.vibrate,
  });

  static const minFlowFontSize = 18;
  static const maxFlowFontSize = 34;

  final ReadingLayout layout;
  final ThemePref theme;
  final int flowFontSize; // 18..34
  final bool keepScreenOn;
  final LanguagePref language;

  /// Lettering of the Mushaf layout. `printed` needs the bundled page fonts
  /// ([QuranRepository.hasPrintedLettering]); without them the built-in font is used.
  final Lettering lettering;

  /// Id of the chosen reciter (specs/004, FR-004).
  final String reciter;

  /// The first-run onboarding was finished or skipped (specs/005, FR-002).
  final bool onboardingDone;

  /// Vibration, sound or neither when memorization detects a mistake (specs/006 FR-015).
  final MistakeSignal mistakeSignal;

  ReaderPreferences copyWith({
    ReadingLayout? layout,
    ThemePref? theme,
    int? flowFontSize,
    bool? keepScreenOn,
    LanguagePref? language,
    Lettering? lettering,
    String? reciter,
    bool? onboardingDone,
    MistakeSignal? mistakeSignal,
  }) =>
      ReaderPreferences(
        layout: layout ?? this.layout,
        theme: theme ?? this.theme,
        flowFontSize: flowFontSize ?? this.flowFontSize,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        language: language ?? this.language,
        lettering: lettering ?? this.lettering,
        reciter: reciter ?? this.reciter,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        mistakeSignal: mistakeSignal ?? this.mistakeSignal,
      );
}
