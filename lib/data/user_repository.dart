import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// On-device user data: reading position, preferences and bookmarks.
/// Schema and operations: specs/001-quran-mushaf-reader/contracts/user-data.md.
class UserRepository extends ChangeNotifier {
  UserRepository._(this._db);

  static const _schemaVersion = 1;

  final Database _db;

  static Future<UserRepository> open() async {
    final db = await openDatabase(
      '${await getDatabasesPath()}/user.db',
      version: _schemaVersion,
      onCreate: (db, version) => _migrate(db, 0, version),
      onUpgrade: _migrate,
    );
    return UserRepository._(db);
  }

  /// Forward-only migrations. A migration never deletes bookmarks.
  static Future<void> _migrate(Database db, int from, int to) async {
    if (from < 1) {
      final batch = db.batch()
        ..execute('''
          CREATE TABLE bookmarks (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            surah       INTEGER NOT NULL,
            ayah        INTEGER NOT NULL,
            page        INTEGER NOT NULL,
            created_at  INTEGER NOT NULL,
            UNIQUE (surah, ayah)
          )''')
        ..execute('CREATE INDEX bookmarks_created ON bookmarks(created_at DESC)')
        ..execute('''
          CREATE TABLE reading_state (
            id            INTEGER PRIMARY KEY CHECK (id = 1),
            anchor_surah  INTEGER NOT NULL DEFAULT 1,
            anchor_ayah   INTEGER NOT NULL DEFAULT 1,
            updated_at    INTEGER NOT NULL
          )''')
        ..execute('''
          CREATE TABLE preferences (
            key    TEXT PRIMARY KEY,
            value  TEXT NOT NULL
          ) WITHOUT ROWID''');
      await batch.commit(noResult: true);
    }
  }

  /// Anchor and all preferences in one call, before the first reader frame (≤ 30 ms).
  /// Out-of-range preference values fall back to their defaults.
  Future<(AyahRef, ReaderPreferences)> loadStartup() async {
    final results = await Future.wait([
      _db.query('reading_state', where: 'id = 1'),
      _db.query('preferences'),
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
    }.entries) {
      batch.insert('preferences', {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    return batch.commit(noResult: true);
  }
}
