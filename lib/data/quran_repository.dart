import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Read-only access to the bundled Quran database.
/// Schema and query budgets: specs/001-quran-mushaf-reader/contracts/quran-db.md.
class QuranRepository {
  QuranRepository._(
    this._db,
    this._ayahs,
    this._pageFirstAyah, {
    required this.maxLineWidthEm,
    required this.p98LineWidthEm,
    required this.font,
  });

  static const pageCount = 604;
  static const supportedSchemaMajor = '1';
  static const _assetDb = 'assets/db/quran.db';
  static const _assetVersion = 'assets/db/quran.version';

  final Database _db;
  final List<Ayah> _ayahs; // index = ayah id - 1, Mushaf order
  final List<int> _pageFirstAyah; // index = page - 1 → index into _ayahs (start or continuation)
  final double maxLineWidthEm;

  /// 98th-percentile Mushaf line width in em; sizes the Mushaf layout (research R4).
  final double p98LineWidthEm;

  /// Quran font the database was built for (`amiri-quran` or `kfgqpc-hafs`).
  final String font;

  List<Surah>? _surahs;
  List<Division>? _divisions;

  /// Copies the bundled database on first launch (or when the bundled build changed), then
  /// opens it read-only and loads the small in-memory ayah index used for navigation.
  static Future<QuranRepository> open() async {
    final dir = await getDatabasesPath();
    final path = '$dir/quran.db';
    if (kIsWeb) {
      // Development preview in a browser only (tool/web_preview.dart): no files, so write the
      // bundled bytes into the web SQLite store on every launch.
      final data = await rootBundle.load(_assetDb);
      await databaseFactory.writeDatabaseBytes(
          path, data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      return _openAt(path);
    }
    final bundledVersion = (await rootBundle.loadString(_assetVersion)).trim();
    final versionFile = File('$dir/quran.version');
    final installedVersion =
        versionFile.existsSync() ? versionFile.readAsStringSync().trim() : null;

    if (installedVersion != bundledVersion || !File(path).existsSync()) {
      await Directory(dir).create(recursive: true);
      final data = await rootBundle.load(_assetDb);
      await File(path).writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      await versionFile.writeAsString(bundledVersion, flush: true);
    }
    return _openAt(path);
  }

  static Future<QuranRepository> _openAt(String path) async {
    final db = await openReadOnlyDatabase(path);
    final meta = {
      for (final r in await db.query('meta')) r['key'] as String: r['value'] as String,
    };
    final schema = meta['schema_version'] ?? '';
    if (schema.split('.').first != supportedSchemaMajor) {
      await db.close();
      throw StateError('quran.db schema $schema is not supported (need $supportedSchemaMajor.x)');
    }

    final rows = await db.rawQuery(
      'SELECT id, surah, ayah, page, juz, hizb_quarter, sajdah, first_word_id, last_word_id '
      'FROM ayahs ORDER BY id',
    );
    final ayahs = [
      for (final r in rows)
        Ayah(
          id: r['id'] as int,
          surah: r['surah'] as int,
          ayah: r['ayah'] as int,
          page: r['page'] as int,
          juz: r['juz'] as int,
          hizbQuarter: r['hizb_quarter'] as int,
          sajdah: (r['sajdah'] as int) == 1,
          firstWordId: r['first_word_id'] as int,
          lastWordId: r['last_word_id'] as int,
        ),
    ];

    // For each page: the first ayah starting on it, or the ayah continuing from the previous
    // page when none starts there.
    final pageFirst = List<int>.filled(pageCount, -1);
    for (var i = ayahs.length - 1; i >= 0; i--) {
      pageFirst[ayahs[i].page - 1] = i;
    }
    for (var p = 1; p < pageCount; p++) {
      if (pageFirst[p] == -1) pageFirst[p] = pageFirst[p - 1];
    }

    final maxEm = double.tryParse(meta['max_line_width_em'] ?? '') ?? 0;
    final repo = QuranRepository._(
      db,
      ayahs,
      pageFirst,
      maxLineWidthEm: maxEm,
      p98LineWidthEm: double.tryParse(meta['p98_line_width_em'] ?? '') ?? maxEm,
      font: meta['font'] ?? 'amiri-quran',
    );
    // Small tables used by every page header and index; loaded once, before the first frame.
    await (repo.surahs(), repo.divisions()).wait;
    return repo;
  }

  late final List<int> _surahStart = () {
    final starts = List<int>.filled(115, _ayahs.length); // [114] = end sentinel
    for (var i = _ayahs.length - 1; i >= 0; i--) {
      starts[_ayahs[i].surah - 1] = i;
    }
    return starts;
  }();

  Ayah ayahAt(AyahRef ref) => tryAyah(ref) ?? (throw RangeError('No ayah $ref'));

  Ayah? tryAyah(AyahRef ref) {
    if (ref.surah < 1 || ref.surah > 114 || ref.ayah < 1) return null;
    final i = _surahStart[ref.surah - 1] + ref.ayah - 1;
    return i < _surahStart[ref.surah] ? _ayahs[i] : null;
  }

  /// The page on which [ref] starts.
  int pageOf(AyahRef ref) => ayahAt(ref).page;

  /// The first ayah that starts on [page], or the ayah continuing onto it.
  Ayah firstAyahOnPage(int page) => _ayahs[_pageFirstAyah[page - 1]];

  /// Ayahs that start on [page], in order.
  List<Ayah> ayahsStartingOnPage(int page) {
    var i = _pageFirstAyah[page - 1];
    if (_ayahs[i].page != page) i++; // the page starts mid-ayah
    final result = <Ayah>[];
    while (i < _ayahs.length && _ayahs[i].page == page) {
      result.add(_ayahs[i++]);
    }
    return result;
  }

  /// Lines of [page] with their words, for the Mushaf layout. Budget ≤ 10 ms.
  Future<MushafPage> page(int page) async {
    final lineRows = await _db.query(
      'mushaf_lines',
      where: 'page = ?',
      whereArgs: [page],
      orderBy: 'line',
    );
    final wordIds = [
      for (final r in lineRows)
        if (r['first_word_id'] != null) ...[r['first_word_id'] as int, r['last_word_id'] as int],
    ];
    final words = wordIds.isEmpty
        ? <int, Word>{}
        : {for (final w in await _words(wordIds.reduce(_min), wordIds.reduce(_max))) w.id: w};

    return MushafPage(
      number: page,
      lines: [
        for (final r in lineRows)
          MushafLine(
            page: page,
            line: r['line'] as int,
            type: switch (r['type'] as String) {
              'surah_name' => LineType.surahName,
              'basmallah' => LineType.basmallah,
              _ => LineType.ayah,
            },
            centered: (r['centered'] as int) == 1,
            surah: r['surah'] as int?,
            words: r['first_word_id'] == null
                ? const []
                : [
                    for (var id = r['first_word_id'] as int; id <= (r['last_word_id'] as int); id++)
                      words[id]!,
                  ],
          ),
      ],
    );
  }

  /// Words of the ayahs that start on [page], grouped by ayah, for the flowing layout.
  Future<List<(Ayah, List<Word>)>> flowingPage(int page) async {
    final ayahs = ayahsStartingOnPage(page);
    if (ayahs.isEmpty) return const [];
    final words = await _words(ayahs.first.firstWordId, ayahs.last.lastWordId);
    return [
      for (final a in ayahs)
        (a, [for (final w in words) if (w.id >= a.firstWordId && w.id <= a.lastWordId) w]),
    ];
  }

  /// Words of a single ayah (copy and share).
  Future<List<Word>> wordsOf(AyahRef ref) {
    final a = ayahAt(ref);
    return _words(a.firstWordId, a.lastWordId);
  }

  /// All surahs, after [open] (preloaded).
  List<Surah> get surahList => _surahs!;

  /// All juz and hizb-quarter divisions, after [open] (preloaded).
  List<Division> get divisionList => _divisions!;

  Future<List<Surah>> surahs() async => _surahs ??= [
        for (final r in await _db.query('surahs', orderBy: 'number'))
          Surah(
            number: r['number'] as int,
            nameAr: r['name_ar'] as String,
            nameTranslit: r['name_translit'] as String,
            ayahCount: r['ayah_count'] as int,
            revelation: r['revelation'] == 'makki' ? Revelation.makki : Revelation.madani,
            startPage: r['start_page'] as int,
          ),
      ];

  Future<List<Division>> divisions() async => _divisions ??= [
        for (final r in await _db.query('divisions', orderBy: 'kind, number'))
          Division(
            kind: r['kind'] == 'juz' ? DivisionKind.juz : DivisionKind.hizbQuarter,
            number: r['number'] as int,
            start: AyahRef(r['start_surah'] as int, r['start_ayah'] as int),
            startPage: r['start_page'] as int,
            openingWords: r['opening_words'] as String,
          ),
      ];

  /// Attribution strings from `meta` for the About screen.
  Future<Map<String, String>> attributions() async => {
        for (final r in await _db.query('meta', where: "key LIKE 'attribution_%'"))
          r['key'] as String: r['value'] as String,
      };

  /// Normalised search text per ayah and each word's offset into it (research R7).
  /// Loaded on first search; budget ≤ 150 ms.
  Future<SearchCorpus> searchCorpus() async {
    final texts = [
      for (final r in await _db.rawQuery('SELECT search_text FROM ayahs ORDER BY id'))
        r['search_text'] as String,
    ];
    final offsetRows = await _db.rawQuery('SELECT id, search_offset FROM words ORDER BY id');
    final offsets = [for (final r in offsetRows) r['search_offset'] as int];
    final firstWordId = offsetRows.isEmpty ? 1 : offsetRows.first['id'] as int;
    return SearchCorpus(_ayahs, texts, offsets, firstWordId);
  }

  Future<List<Word>> _words(int from, int to) async => [
        for (final r in await _db.rawQuery(
          'SELECT id, surah, ayah, position, text_uthmani, is_ayah_end FROM words '
          'WHERE id BETWEEN ? AND ? ORDER BY id',
          [from, to],
        ))
          Word(
            id: r['id'] as int,
            surah: r['surah'] as int,
            ayah: r['ayah'] as int,
            position: r['position'] as int,
            text: r['text_uthmani'] as String,
            isAyahEnd: (r['is_ayah_end'] as int) == 1,
          ),
      ];

  static int _min(int a, int b) => a < b ? a : b;
  static int _max(int a, int b) => a > b ? a : b;
}

/// In-memory search data. Index i of [texts] is the ayah with id i + 1.
class SearchCorpus {
  SearchCorpus(this.ayahs, this.texts, this.wordOffsets, this.firstWordId);

  final List<Ayah> ayahs;
  final List<String> texts;
  final List<int> wordOffsets; // index = word id - firstWordId
  final int firstWordId;

  int offsetOfWord(int wordId) => wordOffsets[wordId - firstWordId];
}
