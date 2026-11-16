import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../data/user_repository.dart';
import 'group_models.dart';

/// A group khatma the reader keeps on this device, with the last state it saw (FR-055).
class KeptKhatma {
  const KeptKhatma({required this.snapshot, required this.seenAt, this.hidden = const {}});
  final Snapshot snapshot;

  /// When the snapshot was fetched, milliseconds.
  final int seenAt;

  /// Participant ids the reader reported, hidden on this device (FR-061).
  final Set<String> hidden;

  String get code => snapshot.code;

  KeptKhatma copyWith({Snapshot? snapshot, int? seenAt, Set<String>? hidden}) => KeptKhatma(
        snapshot: snapshot ?? this.snapshot,
        seenAt: seenAt ?? this.seenAt,
        hidden: hidden ?? this.hidden,
      );
}

/// A part the reader holds: its place, and whether a "read" mark waits to be sent (FR-053).
class HeldPart {
  const HeldPart({required this.code, required this.number, required this.placePage, this.pending = false});
  final String code;
  final int number;
  final int placePage;
  final bool pending;
}

/// The two device tables of the group khatma and its preferences (data-model.md › 2).
class GroupRepository {
  GroupRepository(this._user);

  final UserRepository _user;
  Database get _db => _user.database;

  static const nameKey = 'group.name';
  static const termsKey = 'group.terms';

  Future<List<KeptKhatma>> loadKept() async => [
        for (final r in await _db.query('group_khatmas'))
          ?_kept(r),
      ];

  KeptKhatma? _kept(Map<String, Object?> r) {
    try {
      return KeptKhatma(
        snapshot: Snapshot.fromJson((jsonDecode(r['snapshot'] as String) as Map).cast()),
        seenAt: r['seen_at'] as int,
        hidden: {for (final h in jsonDecode(r['hidden'] as String) as List) h as String},
      );
    } on Object {
      return null; // a copy this version cannot read is refreshed from the server
    }
  }

  Future<void> save(KeptKhatma k) => _db.insert(
        'group_khatmas',
        {
          'code': k.code,
          'snapshot': jsonEncode(k.snapshot.toJson()),
          'version': k.snapshot.version,
          'seen_at': k.seenAt,
          'hidden': jsonEncode(k.hidden.toList()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  /// Forgets a khatma and the reader's places in it.
  Future<void> remove(String code) => _db.transaction((txn) async {
        await txn.delete('group_khatmas', where: 'code = ?', whereArgs: [code]);
        await txn.delete('group_parts', where: 'code = ?', whereArgs: [code]);
      });

  Future<List<HeldPart>> loadParts() async => [
        for (final r in await _db.query('group_parts'))
          HeldPart(
            code: r['code'] as String,
            number: r['number'] as int,
            placePage: r['place_page'] as int,
            pending: r['pending'] == 1,
          ),
      ];

  Future<void> savePart(HeldPart p) => _db.insert(
        'group_parts',
        {'code': p.code, 'number': p.number, 'place_page': p.placePage, 'pending': p.pending ? 1 : 0},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> removePart(String code, int number) =>
      _db.delete('group_parts', where: 'code = ? AND number = ?', whereArgs: [code, number]);

  Future<String?> name() => _user.readPreference(nameKey);
  Future<void> saveName(String name) => _user.writePreference(nameKey, name);
  Future<int?> acceptedTerms() async => int.tryParse(await _user.readPreference(termsKey) ?? '');
  Future<void> acceptTerms(int version) => _user.writePreference(termsKey, '$version');
}
