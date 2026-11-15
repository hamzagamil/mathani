import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../data/user_repository.dart';
import 'khatma_models.dart';

/// The khatma in progress (or paused) with its wirds in order.
class OpenKhatma {
  const OpenKhatma(this.khatma, this.wirds);
  final Khatma khatma;
  final List<Wird> wirds;
}

/// Starting a khatma while one is in progress or paused (FR-005).
class KhatmaInProgress implements Exception {
  const KhatmaInProgress();
}

/// The personal khatma's tables in `user.db` (specs/014 data-model.md › 1). Every state change is
/// one transaction, and writes run one at a time in the order they were asked for. Wird rows are
/// deleted with their khatma in the same transaction: the app does not rely on cascades.
class KhatmaRepository {
  KhatmaRepository(this._db, this._user, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  factory KhatmaRepository.of(UserRepository user) => KhatmaRepository(user.database, user);

  final Database _db;
  final UserRepository _user;
  final DateTime Function() _now;
  Future<void> _last = Future.value();

  /// Runs [action] after every write asked for before it.
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _last.then((_) => action());
    _last = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  // --- Reading -------------------------------------------------------------------------------

  Future<OpenKhatma?> loadOpen() => _serial(() async {
        final rows = await _db.query('khatmas',
            where: 'state != ?', whereArgs: [KhatmaState.finished.name], orderBy: 'id DESC');
        for (final row in rows) {
          final k = _khatma(row);
          if (k == null) continue; // a plan this version does not know: left as it is
          final wirds = await _db.query('khatma_wirds',
              where: 'khatma_id = ?', whereArgs: [k.id], orderBy: 'number');
          return OpenKhatma(k, [for (final w in wirds) _wird(w)]);
        }
        return null;
      });

  /// Finished khatmas, the record, newest first (FR-035).
  Future<List<Khatma>> loadFinished() => _serial(() async => [
        for (final row in await _db.query('khatmas',
            where: 'state = ?',
            whereArgs: [KhatmaState.finished.name],
            orderBy: 'finished_on DESC, id DESC'))
          ?_khatma(row),
      ]);

  Future<ReminderSetting> readReminder() async =>
      ReminderSetting.decode(await _user.readPreference(UserRepository.khatmaReminderKey));

  Future<void> writeReminder(ReminderSetting r) =>
      _user.writePreference(UserRepository.khatmaReminderKey, r.encode());

  // --- Writing -------------------------------------------------------------------------------

  /// Starts a khatma with [ranges] as its wirds. Throws [KhatmaInProgress] when one is in progress
  /// or paused, checked inside the same transaction (FR-005).
  Future<OpenKhatma> start({
    required KhatmaPlan plan,
    required int startAyah,
    required CalendarDay startDate,
    required List<WirdRange> ranges,
    required int placePage,
  }) =>
      _serial(() => _db.transaction((txn) async {
            final open = Sqflite.firstIntValue(await txn.rawQuery(
                'SELECT COUNT(*) FROM khatmas WHERE state != ?', [KhatmaState.finished.name]));
            if ((open ?? 0) > 0) throw const KhatmaInProgress();
            final createdAt = _now().millisecondsSinceEpoch;
            final planned = plannedFinishFor(startDate, ranges.length);
            final id = await txn.insert('khatmas', {
              'state': KhatmaState.active.name,
              'plan': plan.encode(),
              'start_ayah': startAyah,
              'start_date': '$startDate',
              'planned_finish': '$planned',
              'paused_on': null,
              'place_page': placePage,
              'wird_count': ranges.length,
              'finished_on': null,
              'created_at': createdAt,
            });
            final wirds = [
              for (var i = 0; i < ranges.length; i++)
                Wird(
                    khatmaId: id,
                    number: i + 1,
                    firstAyah: ranges[i].firstAyah,
                    lastAyah: ranges[i].lastAyah),
            ];
            await _insertWirds(txn, wirds);
            return OpenKhatma(
              Khatma(
                id: id,
                state: KhatmaState.active,
                plan: plan,
                startAyah: startAyah,
                startDate: startDate,
                plannedFinish: planned,
                placePage: placePage,
                wirdCount: ranges.length,
                createdAt: createdAt,
              ),
              wirds,
            );
          }));

  /// Writes [khatma]'s row and the read dates of the wirds in [reads] (number → day, or null for
  /// unread): marking read, reading on, Undo, setting the place, pausing and resuming.
  Future<void> apply(Khatma khatma, {Map<int, CalendarDay?> reads = const {}}) =>
      _serial(() => _db.transaction((txn) async {
            await _updateKhatma(txn, khatma);
            final batch = txn.batch();
            for (final e in reads.entries) {
              batch.update('khatma_wirds', {'read_on': e.value?.toString()},
                  where: 'khatma_id = ? AND number = ?', whereArgs: [khatma.id, e.key]);
            }
            await batch.commit(noResult: true);
          }));

  /// Writes [khatma]'s row and replaces all its wirds with [wirds]: changing the plan, finishing
  /// (no wirds) and undoing a finish.
  Future<void> replace(Khatma khatma, List<Wird> wirds) =>
      _serial(() => _db.transaction((txn) async {
            await _updateKhatma(txn, khatma);
            await txn.delete('khatma_wirds', where: 'khatma_id = ?', whereArgs: [khatma.id]);
            await _insertWirds(txn, wirds);
          }));

  /// Moves the khatma place only, coalesced by the caller (FR-014).
  Future<void> savePlace(int khatmaId, int page) => _serial(() => _db.update(
      'khatmas', {'place_page': page}, where: 'id = ?', whereArgs: [khatmaId]));

  /// Ends a khatma in progress, or deletes a record entry: the row and its wirds (FR-032,
  /// FR-037). Bookmarks and the reading position are never touched.
  Future<void> delete(int khatmaId) => _serial(() => _db.transaction((txn) async {
        await txn.delete('khatma_wirds', where: 'khatma_id = ?', whereArgs: [khatmaId]);
        await txn.delete('khatmas', where: 'id = ?', whereArgs: [khatmaId]);
      }));

  // --- Rows ----------------------------------------------------------------------------------

  Future<void> _updateKhatma(Transaction txn, Khatma k) => txn.update(
        'khatmas',
        {
          'state': k.state.name,
          'plan': k.plan.encode(),
          'planned_finish': '${k.plannedFinish}',
          'paused_on': k.pausedOn?.toString(),
          'place_page': k.placePage,
          'wird_count': k.wirdCount,
          'finished_on': k.finishedOn?.toString(),
        },
        where: 'id = ?',
        whereArgs: [k.id],
      );

  Future<void> _insertWirds(Transaction txn, List<Wird> wirds) async {
    final batch = txn.batch();
    for (final w in wirds) {
      batch.insert('khatma_wirds', {
        'khatma_id': w.khatmaId,
        'number': w.number,
        'first_ayah': w.firstAyah,
        'last_ayah': w.lastAyah,
        'read_on': w.readOn?.toString(),
      });
    }
    await batch.commit(noResult: true);
  }

  static Khatma? _khatma(Map<String, Object?> r) {
    final plan = KhatmaPlan.tryDecode(r['plan'] as String?);
    final start = CalendarDay.tryParse(r['start_date'] as String?);
    final planned = CalendarDay.tryParse(r['planned_finish'] as String?);
    final state = KhatmaState.values.where((s) => s.name == r['state']).firstOrNull;
    if (plan == null || start == null || planned == null || state == null) return null;
    return Khatma(
      id: r['id'] as int,
      state: state,
      plan: plan,
      startAyah: r['start_ayah'] as int,
      startDate: start,
      plannedFinish: planned,
      pausedOn: CalendarDay.tryParse(r['paused_on'] as String?),
      placePage: r['place_page'] as int,
      wirdCount: r['wird_count'] as int,
      finishedOn: CalendarDay.tryParse(r['finished_on'] as String?),
      createdAt: r['created_at'] as int,
    );
  }

  static Wird _wird(Map<String, Object?> r) => Wird(
        khatmaId: r['khatma_id'] as int,
        number: r['number'] as int,
        firstAyah: r['first_ayah'] as int,
        lastAyah: r['last_ayah'] as int,
        readOn: CalendarDay.tryParse(r['read_on'] as String?),
      );
}
