import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../platform/database.dart';
import '../platform/device.dart';
import 'models.dart';

/// On-device user data: reading position, preferences and bookmarks.
/// Schema and operations: specs/001-quran-mushaf-reader/contracts/user-data.md.
class UserRepository extends ChangeNotifier {
  UserRepository._(this._db);

  static const _schemaVersion = 4;

  /// The prayer-times state, one JSON value in `preferences` (specs/009 data-model.md).
  static const prayerStateKey = 'prayer.state';

  /// The khatma's daily reminder setting (specs/014 data-model.md).
  static const khatmaReminderKey = 'khatma.reminder';

  /// Rows that features read when they load, not at startup.
  static const _notAtStartup = [
    prayerStateKey,
    khatmaReminderKey,
    // The group khatma (specs/014 data-model.md › 2).
    'group.name',
    'group.terms',
    'group.installed',
    'group.key',
  ];

  final Database _db;

  /// The database, for features that keep their own tables in it (specs/014 khatmas).
  Database get database => _db;

  /// Bookmarks, newest first (FR-015). Kept in memory; the table is small.
  List<Bookmark> _bookmarks = const [];
  List<Bookmark> get bookmarks => _bookmarks;

  static Future<UserRepository> open() async {
    final db = await openDatabase(
      await databasePath('user.db'),
      version: _schemaVersion,
      onCreate: (db, version) => _migrate(db, 0, version),
      onUpgrade: _migrate,
    );
    final repo = UserRepository._(db);
    await repo._loadBookmarks();
    return repo;
  }

  Future<void> _loadBookmarks() async {
    _bookmarks = [
      for (final r in await _db.query('bookmarks', orderBy: 'created_at DESC, id DESC'))
        Bookmark(
          id: r['id'] as int,
          ref: AyahRef(r['surah'] as int, r['ayah'] as int),
          page: r['page'] as int,
          createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
          note: r['note'] as String?,
        ),
    ];
  }

  /// Adds a bookmark for [ref] on [page]. Adding an ayah that is already bookmarked is a no-op
  /// (`UNIQUE (surah, ayah)` with INSERT OR IGNORE) that returns the existing bookmark.
  Future<Bookmark> addBookmark(AyahRef ref, int page) async {
    // In a browser, a first bookmark is when to ask to keep the site's data (specs/008 FR-014).
    unawaited(const DeviceChannel().keepBrowserData());
    await _db.insert(
      'bookmarks',
      {
        'surah': ref.surah,
        'ayah': ref.ayah,
        'page': page,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await _loadBookmarks();
    notifyListeners();
    return _bookmarks.firstWhere((b) => b.ref == ref);
  }

  Future<void> removeBookmark(int id) async {
    await _db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
    await _loadBookmarks();
    notifyListeners();
  }

  /// Sets the note on bookmark [id]. A blank note removes it. Longer notes are cut to
  /// [Bookmark.maxNoteLength].
  Future<void> setBookmarkNote(int id, String? note) async {
    var text = note?.trim() ?? '';
    if (text.length > Bookmark.maxNoteLength) text = text.substring(0, Bookmark.maxNoteLength);
    await _db.update('bookmarks', {'note': text.isEmpty ? null : text},
        where: 'id = ?', whereArgs: [id]);
    await _loadBookmarks();
    notifyListeners();
  }

  /// Bookmarks on [page], for the page indicator.
  List<Bookmark> bookmarksOnPage(int page) => [
        for (final b in _bookmarks)
          if (b.page == page) b,
      ];

  bool isBookmarked(AyahRef ref) => _bookmarks.any((b) => b.ref == ref);

  /// Forward-only migrations. A migration never deletes bookmarks. Each step may run again over
  /// tables it already made: a browser can keep the new tables but lose the version bump when the
  /// tab closes mid-upgrade, and the next visit then upgrades again.
  static Future<void> _migrate(Database db, int from, int to) async {
    if (from < 1) {
      final batch = db.batch()
        ..execute('''
          CREATE TABLE IF NOT EXISTS bookmarks (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            surah       INTEGER NOT NULL,
            ayah        INTEGER NOT NULL,
            page        INTEGER NOT NULL,
            created_at  INTEGER NOT NULL,
            UNIQUE (surah, ayah)
          )''')
        ..execute('CREATE INDEX IF NOT EXISTS bookmarks_created ON bookmarks(created_at DESC)')
        ..execute('''
          CREATE TABLE IF NOT EXISTS reading_state (
            id            INTEGER PRIMARY KEY CHECK (id = 1),
            anchor_surah  INTEGER NOT NULL DEFAULT 1,
            anchor_ayah   INTEGER NOT NULL DEFAULT 1,
            updated_at    INTEGER NOT NULL
          )''')
        ..execute('''
          CREATE TABLE IF NOT EXISTS preferences (
            key    TEXT PRIMARY KEY,
            value  TEXT NOT NULL
          ) WITHOUT ROWID''');
      await batch.commit(noResult: true);
    }
    if (from < 2) {
      // The personal khatma (specs/014 data-model.md). Adds tables only.
      final batch = db.batch()
        ..execute('''
          CREATE TABLE IF NOT EXISTS khatmas (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            state           TEXT NOT NULL,
            plan            TEXT NOT NULL,
            start_ayah      INTEGER NOT NULL,
            start_date      TEXT NOT NULL,
            planned_finish  TEXT NOT NULL,
            paused_on       TEXT,
            place_page      INTEGER NOT NULL,
            wird_count      INTEGER NOT NULL,
            finished_on     TEXT,
            created_at      INTEGER NOT NULL
          )''')
        ..execute('''
          CREATE TABLE IF NOT EXISTS khatma_wirds (
            khatma_id   INTEGER NOT NULL,
            number      INTEGER NOT NULL,
            first_ayah  INTEGER NOT NULL,
            last_ayah   INTEGER NOT NULL,
            read_on     TEXT,
            PRIMARY KEY (khatma_id, number)
          ) WITHOUT ROWID''');
      await batch.commit(noResult: true);
    }
    if (from < 3) {
      // Group khatmas the reader keeps, and the parts they hold (specs/014 data-model.md › 2).
      final batch = db.batch()
        ..execute('''
          CREATE TABLE IF NOT EXISTS group_khatmas (
            code      TEXT PRIMARY KEY,
            snapshot  TEXT NOT NULL,
            version   INTEGER NOT NULL,
            seen_at   INTEGER NOT NULL,
            hidden    TEXT NOT NULL DEFAULT '[]'
          ) WITHOUT ROWID''')
        ..execute('''
          CREATE TABLE IF NOT EXISTS group_parts (
            code        TEXT NOT NULL,
            number      INTEGER NOT NULL,
            place_page  INTEGER NOT NULL,
            pending     INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (code, number)
          ) WITHOUT ROWID''');
      await batch.commit(noResult: true);
    }
    if (from < 4) {
      // A note on each bookmark. Checked first: ADD COLUMN fails when it is already there.
      final columns = await db.rawQuery('PRAGMA table_info(bookmarks)');
      if (!columns.any((c) => c['name'] == 'note')) {
        await db.execute('ALTER TABLE bookmarks ADD COLUMN note TEXT');
      }
    }
  }

  /// Anchor and all preferences in one call, before the first reader frame (≤ 30 ms).
  /// Out-of-range preference values fall back to their defaults.
  Future<(AyahRef, ReaderPreferences)> loadStartup() async {
    final results = await Future.wait([
      _db.query('reading_state', where: 'id = 1'),
      // Prayer times and the khatma read their own rows only when needed (specs/009 research
      // R11, specs/014 research R10).
      _db.query('preferences',
          where: 'key NOT IN (${List.filled(_notAtStartup.length, '?').join(', ')})',
          whereArgs: _notAtStartup),
    ]);
    final state = results[0];
    final anchor = state.isEmpty
        ? const AyahRef(1, 1)
        : AyahRef(state.first['anchor_surah'] as int, state.first['anchor_ayah'] as int);
    final prefs = {for (final r in results[1]) r['key'] as String: r['value'] as String};
    return (anchor, _parsePreferences(prefs));
  }

  static ReaderPreferences _parsePreferences(Map<String, String> p) {
    const d = ReaderPreferences();
    T pick<T extends Enum>(List<T> values, String? raw, T fallback) =>
        values.firstWhere((v) => v.name == raw, orElse: () => fallback);
    final size = int.tryParse(p['flow_font_size'] ?? '');
    return ReaderPreferences(
      layout: pick(ReadingLayout.values, p['layout'], d.layout),
      theme: pick(ThemePref.values, p['theme'], d.theme),
      flowFontSize: size != null &&
              size >= ReaderPreferences.minFlowFontSize &&
              size <= ReaderPreferences.maxFlowFontSize
          ? size
          : d.flowFontSize,
      keepScreenOn: switch (p['keep_screen_on']) { 'true' => true, _ => d.keepScreenOn },
      language: pick(LanguagePref.values, p['language'], d.language),
      lettering: pick(Lettering.values, p['lettering'], d.lettering),
      // Kept as stored; an id no longer in quran.db falls back to the default where it is
      // resolved (QuranRepository.reciterOrDefault).
      reciter: (p['reciter'] ?? '').isEmpty ? d.reciter : p['reciter']!,
      // Missing for readers updating from 1.3.0 or earlier: they see the onboarding once
      // (specs/005 research R2). A stale `controls_hint_shown` row from 1.3.0 is ignored.
      onboardingDone: switch (p['onboarding_done']) { 'true' => true, _ => d.onboardingDone },
      similarIntroSeen:
          switch (p['similar_intro_seen']) { 'true' => true, _ => d.similarIntroSeen },
      mistakeSignal: pick(MistakeSignal.values, p['mistake_signal'], d.mistakeSignal),
      // Missing before specs/012: on by default.
      twoPages: switch (p['two_pages']) { 'false' => false, _ => d.twoPages },
      // Missing before specs/015: on by default (FR-014).
      announcements: switch (p['announcements']) { 'false' => false, _ => d.announcements },
    );
  }

  Future<void> saveAnchor(AyahRef ref) => _db.insert(
        'reading_state',
        {
          'id': 1,
          'anchor_surah': ref.surah,
          'anchor_ayah': ref.ayah,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> savePreferences(ReaderPreferences p) {
    final batch = _db.batch();
    for (final entry in {
      'layout': p.layout.name,
      'theme': p.theme.name,
      'flow_font_size': '${p.flowFontSize}',
      'keep_screen_on': '${p.keepScreenOn}',
      'language': p.language.name,
      'lettering': p.lettering.name,
      'reciter': p.reciter,
      'onboarding_done': '${p.onboardingDone}',
      'similar_intro_seen': '${p.similarIntroSeen}',
      'mistake_signal': p.mistakeSignal.name,
      'two_pages': '${p.twoPages}',
      'announcements': '${p.announcements}',
    }.entries) {
      batch.insert('preferences', {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    return batch.commit(noResult: true);
  }

  /// One preference row by [key], for features that keep their own value (specs/009).
  Future<String?> readPreference(String key) async {
    final rows = await _db.query('preferences', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> writePreference(String key, String value) => _db.insert(
        'preferences',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> deletePreference(String key) =>
      _db.delete('preferences', where: 'key = ?', whereArgs: [key]);
}
