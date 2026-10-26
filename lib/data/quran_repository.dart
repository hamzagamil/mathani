import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

import '../platform/database.dart';
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
    required this.justifyTargetEm,
    required this.font,
    this.printedTargetEm = 0,
    this.printedSpaceEm = 0,
  });

  static const pageCount = 604;
  static const supportedSchemaMajor = '1';
  static const _assetVersion = 'assets/db/quran.version';

  final Database _db;
  final List<Ayah> _ayahs; // index = ayah id - 1, Mushaf order
  final List<int> _pageFirstAyah; // index = page - 1 → index into _ayahs (start or continuation)
  final double maxLineWidthEm;

  /// 98th-percentile Mushaf line width in em (001 research R4).
  final double p98LineWidthEm;

  /// Width every justified Mushaf line is filled to, in em; sizes the Mushaf layout
  /// (specs/002-print-like-mushaf-page/contracts/page-typesetting.md).
  final double justifyTargetEm;

  /// Quran font the database was built for (`amiri-quran` or `kfgqpc-hafs`).
  final String font;

  /// Width every printed-lettering line is filled to, in em; 0 when the database has no printed
  /// lettering (specs/002, tool/build_replica_lettering_test.dart).
  final double printedTargetEm;

  /// The gap between printed words, in em.
  final double printedSpaceEm;

  /// Whether the King Fahd Complex page fonts and their lines are bundled.
  bool get hasPrintedLettering => printedTargetEm > 0;

  List<Surah>? _surahs;
  List<Division>? _divisions;
  List<Reciter> _reciters = const [];
  final Map<(String, int), List<int>> _recordingBytes = {};
  final Map<(String, int), int?> _rangeStarts = {};
  final Map<bool, List<int>> _basmalaPages = {};

  /// Installs the bundled database on first launch (or when the bundled build changed), then
  /// opens it read-only and loads the small in-memory ayah index used for navigation.
  static Future<QuranRepository> open() async {
    final bundledVersion = (await rootBundle.loadString(_assetVersion)).trim();
    return _openAt(await installQuranDb(bundledVersion));
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
    final p98 = double.tryParse(meta['p98_line_width_em'] ?? '') ?? maxEm;
    final repo = QuranRepository._(
      db,
      ayahs,
      pageFirst,
      maxLineWidthEm: maxEm,
      p98LineWidthEm: p98,
      justifyTargetEm: double.tryParse(meta['justify_target_em'] ?? '') ?? p98 * 1.034,
      font: meta['font'] ?? 'amiri-quran',
      printedTargetEm: double.tryParse(meta['replica_target_em'] ?? '') ?? 0,
      printedSpaceEm: double.tryParse(meta['replica_space_em'] ?? '') ?? 0,
    );
    // Small tables used by every page header and index; loaded once, before the first frame.
    await (repo.surahs(), repo.divisions(), repo._loadReciters()).wait;
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
  /// One Mushaf page. With [printed], its lines are the printed edition's: the same words on
  /// the same page, with that edition's line breaks and surah-title placement.
  Future<MushafPage> page(int page, {bool printed = false}) async {
    final lineRows = await _db.query(
      printed ? 'replica_lines' : 'mushaf_lines',
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
  /// The printed-lettering glyphs of every word on [page]: word id → glyph string, drawn in
  /// that page's font. Empty when the previous word's glyph covers this word too.
  Future<Map<int, String>> printedGlyphs(MushafPage page) async {
    final ids = [for (final l in page.lines) for (final w in l.words) w.id];
    if (ids.isEmpty) return const {};
    return {
      for (final r in await _db.rawQuery(
        'SELECT word_id, glyphs FROM replica_glyphs WHERE word_id BETWEEN ? AND ?',
        [ids.reduce(_min), ids.reduce(_max)],
      ))
        r['word_id'] as int: r['glyphs'] as String,
    };
  }

  Future<List<Word>> wordsOf(AyahRef ref) {
    final a = ayahAt(ref);
    return _words(a.firstWordId, a.lastWordId);
  }

  /// The reference words of ayat [from]..[to] of [surah] for memorization (specs/006 research
  /// R11): per ayah, each Uthmani word (ayah-end markers excluded) with its position and its
  /// normalised imla'i form from `ayahs.search_text`, cut at the next word's offset. One Uthmani
  /// word can be two imla'i words (يَٰٓأَيُّهَا: «يا ايها»).
  Future<List<List<({int wordId, int position, String form})>>> memorizationWords(
      int surah, int from, int to) async {
    final ayahs = await _db.rawQuery(
        'SELECT ayah, first_word_id, last_word_id, search_text FROM ayahs '
        'WHERE surah = ? AND ayah BETWEEN ? AND ? ORDER BY ayah',
        [surah, from, to]);
    if (ayahs.isEmpty) return const [];
    final words = await _db.rawQuery(
        'SELECT id, position, is_ayah_end, search_offset FROM words WHERE id BETWEEN ? AND ? '
        'ORDER BY id',
        [ayahs.first['first_word_id'], ayahs.last['last_word_id']]);
    final byId = {for (final w in words) w['id'] as int: w};
    return [
      for (final a in ayahs)
        () {
          final text = a['search_text'] as String;
          final ids = [
            for (var id = a['first_word_id'] as int; id <= (a['last_word_id'] as int); id++)
              if (byId[id]!['is_ayah_end'] != 1) id,
          ];
          return [
            for (var k = 0; k < ids.length; k++)
              (
                wordId: ids[k],
                position: byId[ids[k]]!['position'] as int,
                form: text
                    .substring(
                      byId[ids[k]]!['search_offset'] as int,
                      k + 1 < ids.length ? byId[ids[k + 1]]!['search_offset'] as int : text.length,
                    )
                    .trim(),
              ),
          ];
        }(),
    ];
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

  // --- Recitations (specs/004-ayah-recitations/contracts/recitation-catalogue.md) -----------

  /// Reciters in list order. Empty when the database has no recitation catalogue.
  List<Reciter> get reciters => _reciters;

  Reciter? reciter(String id) {
    for (final r in _reciters) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// The reciter with [id], or the default when it is unknown (for example, removed in a later
  /// release). Null only when there is no catalogue at all.
  Reciter? reciterOrDefault(String id) =>
      reciter(id) ?? reciter(Reciter.defaultId) ?? (_reciters.isEmpty ? null : _reciters.first);

  Future<void> _loadReciters() async {
    final exists = await _db.rawQuery(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'reciters'");
    if (exists.isEmpty) return;
    _reciters = [
      for (final r in await _db.query('reciters', orderBy: 'sort'))
        Reciter(
          id: r['id'] as String,
          nameAr: r['name_ar'] as String,
          nameEn: r['name_en'] as String,
          shortAr: r['short_ar'] as String,
          shortEn: r['short_en'] as String,
          style: RecitationStyle.parse(r['style'] as String),
          baseUrl: r['base_url'] as String,
          mirrorUrl: r['mirror_url'] as String?,
          bitrateKbps: r['bitrate_kbps'] as int,
          sort: r['sort'] as int,
          source: RecitationSource.parse(r['source'] as String),
          filePattern: r['file_pattern'] as String,
          basmalaInAyah1: r['basmala_in_ayah1'] == 1,
        ),
    ];
  }

  /// Whether a basmala is recited before ayah 1 of [surah]: not in Al-Fatiha (its 1:1 is the
  /// basmala) and not in At-Tawbah.
  static bool hasBasmalaItem(int surah) => surah != 1 && surah != 9;

  /// Sizes of [reciter]'s recordings of ayat 1..n of [surah]: file sizes, or for surah files the
  /// exact length of each ayah's clip. Loaded on first use per surah, never on the startup path.
  Future<List<int>> recordingBytes(String reciter, int surah) async {
    final key = (reciter, surah);
    final cached = _recordingBytes[key];
    if (cached != null) return cached;
    final rows = await _db.query('recitation_sizes',
        columns: ['sizes', 'range_start'],
        where: 'reciter = ? AND surah = ?',
        whereArgs: [reciter, surah]);
    if (rows.isEmpty) return _recordingBytes[key] = const [];
    _rangeStarts[key] = rows.first['range_start'] as int?;
    return _recordingBytes[key] = unpackSizes(rows.first['sizes'] as Uint8List);
  }

  /// The byte range `[start, end)` of [ayah]'s clip in [surah]'s file, for a reciter recorded one
  /// surah per file (specs/006 research R18); null for one file per ayah.
  Future<(int, int)?> clipRange(String reciter, int surah, int ayah) async {
    final sizes = await recordingBytes(reciter, surah);
    final start = _rangeStarts[(reciter, surah)];
    if (start == null || ayah < 1 || ayah > sizes.length) return null;
    var offset = start;
    for (var a = 1; a < ayah; a++) {
      offset += sizes[a - 1];
    }
    return (offset, offset + sizes[ayah - 1]);
  }

  /// Length of [surah]'s file for a reciter recorded one surah per file (its first frame offset
  /// plus every clip); null for one file per ayah.
  Future<int?> surahFileBytes(String reciter, int surah) async {
    final sizes = await recordingBytes(reciter, surah);
    final start = _rangeStarts[(reciter, surah)];
    return start == null ? null : start + sizes.fold<int>(0, (a, b) => a + b);
  }

  /// Bytes to download [surah] for [reciter]: every ayah, plus 1:1 as the basmala when the surah
  /// has one and the reciter's basmala is a separate recording (FR-028).
  Future<int> surahDownloadBytes(String reciter, int surah) async {
    var total = (await recordingBytes(reciter, surah)).fold(0, (a, b) => a + b);
    final basmalaSeparate = !(this.reciter(reciter)?.basmalaInAyah1 ?? false);
    if (hasBasmalaItem(surah) && basmalaSeparate) {
      total += (await recordingBytes(reciter, 1)).first;
    }
    return total;
  }

  /// The page holding [surah]'s basmala line, in the printed edition's lines when [printed]
  /// (where 36 surah titles sit at the foot of the previous page) or the built-in layout's.
  /// Falls back to the page of ayah 1 when the surah has no basmala line.
  Future<int> basmalaPageOf(int surah, {required bool printed}) async {
    final table = printed && hasPrintedLettering ? 'replica_lines' : 'mushaf_lines';
    final pages = _basmalaPages[printed && hasPrintedLettering] ??= await () async {
      final byStart = [for (final s in _surahs!) s.startPage];
      for (final r in await _db.rawQuery(
          "SELECT surah, MIN(page) AS page FROM $table WHERE type = 'basmallah' GROUP BY surah")) {
        final s = r['surah'] as int?;
        if (s != null && s >= 1 && s <= 114) byStart[s - 1] = r['page'] as int;
      }
      return byStart;
    }();
    return pages[surah - 1];
  }

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

/// Reads sizes packed as 3-byte little-endian integers (specs/006 research R4).
List<int> unpackSizes(Uint8List packed) => [
      for (var i = 0; i + 2 < packed.length; i += 3)
        packed[i] | (packed[i + 1] << 8) | (packed[i + 2] << 16),
    ];
