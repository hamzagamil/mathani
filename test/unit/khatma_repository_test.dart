// The personal khatma's tables (specs/014 data-model.md › 1): the migration from schema 1, and
// each state change as the data model's table says.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/data/user_repository.dart';
import 'package:mathani/features/khatma/khatma_models.dart';
import 'package:mathani/features/khatma/khatma_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<String> freshDir() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final dir = Directory.systemTemp.createTempSync('mathani_khatma');
  await databaseFactory.setDatabasesPath(dir.path);
  return dir.path;
}

final day1 = CalendarDay.parse('2026-03-01');
const ranges = [WirdRange(1, 148), WirdRange(149, 259), WirdRange(260, 385)];

void main() {
  test('schema 1 to 2 keeps bookmarks, the reading position and preferences', () async {
    final dir = await freshDir();
    final v1 = await databaseFactory.openDatabase('$dir/user.db',
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('CREATE TABLE bookmarks (id INTEGER PRIMARY KEY AUTOINCREMENT, '
                'surah INTEGER NOT NULL, ayah INTEGER NOT NULL, page INTEGER NOT NULL, '
                'created_at INTEGER NOT NULL, UNIQUE (surah, ayah))');
            await db.execute('CREATE INDEX bookmarks_created ON bookmarks(created_at DESC)');
            await db.execute('CREATE TABLE reading_state (id INTEGER PRIMARY KEY CHECK (id = 1), '
                'anchor_surah INTEGER NOT NULL DEFAULT 1, anchor_ayah INTEGER NOT NULL DEFAULT 1, '
                'updated_at INTEGER NOT NULL)');
            await db.execute(
                'CREATE TABLE preferences (key TEXT PRIMARY KEY, value TEXT NOT NULL) WITHOUT ROWID');
          },
        ));
    await v1.insert('bookmarks', {'surah': 2, 'ayah': 255, 'page': 42, 'created_at': 1});
    await v1.insert('reading_state', {'id': 1, 'anchor_surah': 18, 'anchor_ayah': 10, 'updated_at': 1});
    await v1.insert('preferences', {'key': 'theme', 'value': 'night'});
    await v1.close();

    final user = await UserRepository.open();
    expect(user.bookmarks.single.page, 42);
    final (anchor, prefs) = await user.loadStartup();
    expect('$anchor', '18:10');
    expect(prefs.theme.name, 'night');
    final repo = KhatmaRepository.of(user);
    expect(await repo.loadOpen(), isNull);
    expect(await repo.loadFinished(), isEmpty);
  });

  test('an upgrade that kept its tables but lost the version bump runs again', () async {
    // Seen in a browser: the schema 3 tables were saved but user_version stayed 1, so every
    // visit re-ran the upgrade and failed on «table khatmas already exists» (blank page).
    final dir = await freshDir();
    final first = await UserRepository.open();
    await first.addBookmark(const AyahRef(2, 255), 42);
    await first.database.setVersion(1);
    await first.database.close();

    final user = await UserRepository.open();
    expect(user.bookmarks.single.page, 42);
    expect(await user.database.getVersion(), 3);
    expect(await KhatmaRepository.of(user).loadOpen(), isNull);
    expect(dir, isNotEmpty);
  });

  test('start, and a second start is refused while one is open', () async {
    await freshDir();
    final repo = KhatmaRepository.of(await UserRepository.open());
    final open = await repo.start(
        plan: const MarksPlan(8), startAyah: 1, startDate: day1, ranges: ranges, placePage: 1);
    expect(open.khatma.state, KhatmaState.active);
    expect(open.khatma.plannedFinish, CalendarDay.parse('2026-03-03'));
    expect(open.wirds.map((w) => w.number), [1, 2, 3]);
    await expectLater(
        repo.start(plan: const SevenPlan(), startAyah: 1, startDate: day1, ranges: ranges, placePage: 1),
        throwsA(isA<KhatmaInProgress>()));
    // Paused counts as open too (FR-005).
    await repo.apply(open.khatma.copyWith(state: KhatmaState.paused, pausedOn: () => day1));
    await expectLater(
        repo.start(plan: const SevenPlan(), startAyah: 1, startDate: day1, ranges: ranges, placePage: 1),
        throwsA(isA<KhatmaInProgress>()));
    final loaded = (await repo.loadOpen())!;
    expect(loaded.khatma.state, KhatmaState.paused);
    expect(loaded.khatma.pausedOn, day1);
    expect(loaded.khatma.plan, const MarksPlan(8));
  });

  test('marking read, the place, Undo by replacing, and finishing', () async {
    await freshDir();
    final repo = KhatmaRepository.of(await UserRepository.open());
    final open = await repo.start(
        plan: const DaysPlan(3), startAyah: 1, startDate: day1, ranges: ranges, placePage: 1);
    await repo.apply(open.khatma.copyWith(placePage: 22), reads: {1: day1});
    var loaded = (await repo.loadOpen())!;
    expect(loaded.khatma.placePage, 22);
    expect(loaded.wirds.first.readOn, day1);
    expect(loaded.wirds[1].readOn, isNull);

    await repo.savePlace(open.khatma.id, 30);
    expect((await repo.loadOpen())!.khatma.placePage, 30);

    // Undo: the khatma and its wirds as they were.
    await repo.replace(open.khatma, open.wirds);
    loaded = (await repo.loadOpen())!;
    expect(loaded.khatma, open.khatma);
    expect(loaded.wirds, open.wirds);

    final done = open.khatma.copyWith(
        state: KhatmaState.finished, finishedOn: () => CalendarDay.parse('2026-03-03'));
    await repo.replace(done, const []);
    expect(await repo.loadOpen(), isNull);
    final record = await repo.loadFinished();
    expect(record.single.wirdCount, 3);
    expect(record.single.days, 3);
  });

  test('ending deletes the khatma and its wirds, and nothing else', () async {
    await freshDir();
    final user = await UserRepository.open();
    final repo = KhatmaRepository.of(user);
    await user.saveAnchor(const AyahRef(36, 1));
    final open = await repo.start(
        plan: const MarksPlan(8), startAyah: 1, startDate: day1, ranges: ranges, placePage: 1);
    await repo.delete(open.khatma.id);
    expect(await repo.loadOpen(), isNull);
    expect(await repo.loadFinished(), isEmpty);
    expect(await user.database.query('khatma_wirds'), isEmpty);
    final (anchor, _) = await user.loadStartup();
    expect('$anchor', '36:1');
  });

  test('the reminder setting is kept, and not read at startup', () async {
    await freshDir();
    final user = await UserRepository.open();
    final repo = KhatmaRepository.of(user);
    expect(await repo.readReminder(), ReminderSetting.off);
    await repo.writeReminder(const ReminderSetting(on: true, hour: 6, minute: 15));
    expect(await repo.readReminder(), const ReminderSetting(on: true, hour: 6, minute: 15));
    final rows = await user.database.query('preferences');
    expect(rows.map((r) => r['key']), contains(UserRepository.khatmaReminderKey));
    // The startup query skips the row (research R10).
    final startup = await user.database.query('preferences',
        where: 'key NOT IN (?, ?)', whereArgs: [UserRepository.prayerStateKey, UserRepository.khatmaReminderKey]);
    expect(startup.map((r) => r['key']), isNot(contains(UserRepository.khatmaReminderKey)));
  });

  test('schema 3 adds the group khatma tables, and startup skips their preferences', () async {
    await freshDir();
    final user = await UserRepository.open();
    final tables = (await user.database.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
        .map((r) => r['name'])
        .toSet();
    expect(tables, containsAll(['khatmas', 'khatma_wirds', 'group_khatmas', 'group_parts']));
    await user.writePreference('group.key', 'k');
    await user.writePreference('group.name', 'Amina');
    final (_, prefs) = await user.loadStartup();
    expect(prefs, isNotNull);
  });
}
