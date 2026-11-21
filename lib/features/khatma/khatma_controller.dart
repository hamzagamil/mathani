import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../data/models.dart';
import '../../data/quran_repository.dart';
import '../../platform/device.dart';
import '../../shared/reader_state.dart';
import '../analytics/usage.dart';
import 'khatma_division.dart';
import 'khatma_models.dart';
import 'khatma_repository.dart';
import 'reading_tracker.dart';

/// What happened, for the reading screen's message with Undo (FR-016).
enum KhatmaEventKind {
  /// A wird was marked as read, by Done or by reading on.
  wirdDone,

  /// The last wird was marked as read: the khatma is complete (FR-034).
  finished,
}

class KhatmaEvent {
  const KhatmaEvent(this.serial, this.kind, {required this.byReadingOn});
  final int serial;
  final KhatmaEventKind kind;
  final bool byReadingOn;
}

/// The group parts the reader holds, as readings (release B). The personal khatma works without
/// it.
abstract interface class GroupReadings implements Listenable {
  List<Reading> get groupReadings;

  /// The reader moved the place of the part [key] to [page].
  void moveGroupPlace(String key, int page);

  /// Done on the part [key], from the reading screen.
  Future<void> markGroupPartRead(String key);
}

/// The personal khatma while the app runs (specs/014 contracts/khatma-ui-and-reminders.md ›
/// Dart interfaces): the khatma in progress, its current wird and the readings; the actions of
/// the data model's state-change table, and Undo; and what the reading screen shows.
///
/// Created at launch and idle until [load], which runs after the first frame (FR-039).
class KhatmaController extends ChangeNotifier with WidgetsBindingObserver {
  KhatmaController({
    required this.repository,
    required this.reader,
    bool Function()? isMemorizing,
    Clock? clock,
    this.keepBrowserData,
  })  : _isMemorizing = isMemorizing ?? _never,
        _clock = clock ?? DateTime.now;

  static bool _never() => false;
  static const _placeSaveDelay = Duration(milliseconds: 500);

  final KhatmaRepository repository;
  final ReaderController reader;
  final bool Function() _isMemorizing;
  final Clock _clock;

  /// Asks the browser to keep the site's data, as the first bookmark does (FR-042). Null uses
  /// the device channel.
  final Future<void> Function()? keepBrowserData;

  QuranRepository get quran => reader.quran;
  late final QuranIndex index = QuranIndex.fromAyahs(quran.ayahList, quran.divisionList);

  bool _loaded = false;
  bool _disposed = false;
  Khatma? _khatma;
  List<Wird> _wirds = const [];
  List<Khatma> _record = const [];
  ReminderSetting _reminder = ReminderSetting.off;

  /// Before an action that Undo reverses: the khatma and its wirds as they were.
  OpenKhatma? _undo;
  bool _undoByReadingOn = false;

  final _trackers = <String, ReadingTracker>{};
  int? _lastFirst, _lastLast, _lastSerial;
  Timer? _placeTimer;

  GroupReadings? _groups;

  /// Messages for the reading screen.
  final events = ValueNotifier<KhatmaEvent?>(null);
  int _eventSerial = 0;

  bool get loaded => _loaded;
  CalendarDay get today => CalendarDay.of(_clock());

  /// The khatma in progress or paused; null when there is none.
  Khatma? get khatma => _khatma;
  List<Wird> get wirds => _wirds;

  /// Finished khatmas, newest first (FR-035).
  List<Khatma> get record => _record;
  ReminderSetting get reminder => _reminder;

  bool get isActive => _khatma?.state == KhatmaState.active;
  bool get isPaused => _khatma?.state == KhatmaState.paused;

  /// Active, with a start date after today (data-model.md › khatmas).
  bool get notStarted => isActive && _khatma!.startDate.isAfter(today);

  /// The first wird not read yet (FR-007).
  Wird? get currentWird {
    for (final w in _wirds) {
      if (!w.isRead) return w;
    }
    return null;
  }

  int get wirdsRead => _wirds.where((w) => w.isRead).length;

  /// Some wird was marked as read today (FR-018).
  bool get todayRead => _wirds.any((w) => w.readOn == today);

  int get startPage => index.pageOf(_khatma?.startAyah ?? 1);

  /// Pages from the start point to the end of the Quran.
  int get pagesTotal => QuranIndex.pageCount - startPage + 1;

  /// The place's page minus the start point's page (data-model.md › Values worked out).
  int get pagesRead => (( _khatma?.placePage ?? startPage) - startPage).clamp(0, pagesTotal);

  CalendarDay? get expectedFinishDate {
    final k = _khatma;
    if (k == null) return null;
    return expectedFinish(
      today: today,
      startDate: k.startDate,
      unread: _wirds.length - wirdsRead,
      todayRead: todayRead,
    );
  }

  int firstPageOf(Wird w) => index.pageOf(w.firstAyah);
  int lastPageOf(Wird w) => index.pageOf(w.lastAyah);
  int pagesOf(Wird w) => index.pagesOf(w.range);
  WirdName nameOf(Wird w) => wirdName(index, w.range, w.number);

  // --- Loading -------------------------------------------------------------------------------

  /// Reads the khatma, the record and the reminder setting, then starts following the reader.
  Future<void> load() async {
    if (_loaded) return;
    final (open, record, reminder) =
        await (repository.loadOpen(), repository.loadFinished(), repository.readReminder()).wait;
    if (_disposed) return;
    _khatma = open?.khatma;
    _wirds = open?.wirds ?? const [];
    _record = record;
    _reminder = reminder;
    _loaded = true;
    _syncTrackers();
    reader.addListener(_onReader);
    WidgetsBinding.instance.addObserver(this);
    notifyListeners();
  }

  /// Connects the group parts the reader holds (release B).
  void attachGroups(GroupReadings groups) {
    _groups?.removeListener(_onGroups);
    _groups = groups..addListener(_onGroups);
    _onGroups();
  }

  void _onGroups() {
    _syncTrackers();
    notifyListeners();
  }

  // --- Readings ------------------------------------------------------------------------------

  /// The current wird (while the khatma is active) and each unread group part the reader holds.
  List<Reading> get readings {
    final result = <Reading>[];
    final w = currentWird;
    final k = _khatma;
    if (k != null && k.state == KhatmaState.active && w != null) {
      result.add(Reading(
        key: wirdKey,
        kind: ReadingKind.wird,
        firstAyah: w.firstAyah,
        lastAyah: w.lastAyah,
        firstPage: firstPageOf(w),
        lastPage: lastPageOf(w),
        place: _trackers[wirdKey]?.place ?? k.placePage,
      ));
    }
    final groups = _groups;
    if (groups != null) {
      for (final r in groups.groupReadings) {
        result.add(Reading(
          key: r.key,
          kind: r.kind,
          firstAyah: r.firstAyah,
          lastAyah: r.lastAyah,
          firstPage: r.firstPage,
          lastPage: r.lastPage,
          place: _trackers[r.key]?.place ?? r.place,
          title: r.title,
          partNumber: r.partNumber,
        ));
      }
    }
    return result;
  }

  static const wirdKey = 'wird';

  /// The ayah-end word ids where a reading ends on [page] (R5). Empty during memorization.
  Set<int> endMarksOn(int page) {
    if (_isMemorizing()) return const {};
    return {
      for (final r in readings)
        if (index.pageOf(r.lastAyah) == page) ?index.endWordOf(r.lastAyah),
    };
  }

  /// The ayah numbers where a reading ends on [page], for the page's screen-reader label.
  List<int> endAyahsOn(int page) {
    if (_isMemorizing()) return const [];
    return [
      for (final r in readings)
        if (index.pageOf(r.lastAyah) == page) quran.ayahById(r.lastAyah).ayah,
    ];
  }

  /// Ayah ids where a reading ends, for the flowing layout.
  Set<int> get endAyahIds =>
      _isMemorizing() ? const {} : {for (final r in readings) r.lastAyah};

  /// Pages left in the reading the screen is in, counted from the first page on screen (FR-011).
  /// Null when no reading holds that page, and during memorization.
  int? pagesLeft(int firstOnScreen) {
    if (_isMemorizing()) return null;
    for (final r in readings) {
      if (r.containsPage(firstOnScreen)) return r.pagesLeftFrom(firstOnScreen);
    }
    return null;
  }

  /// The readings whose last page is on screen: each gets a Done row (FR-012).
  List<Reading> readingsEndingOn(int firstOnScreen, int lastOnScreen) {
    if (_isMemorizing()) return const [];
    return [
      for (final r in readings)
        if (r.lastPage >= firstOnScreen && r.lastPage <= lastOnScreen) r,
    ];
  }

  /// Whether a page of the current wird is on screen: today's reminder waits (research R8).
  bool get currentWirdOnScreen {
    final first = _lastFirst, last = _lastLast;
    final w = currentWird;
    if (first == null || last == null || w == null || !isActive) return false;
    return firstPageOf(w) <= last && lastPageOf(w) >= first;
  }

  /// Opens the Mushaf at [r]'s place, in the reader's layout (FR-008).
  void openReading(Reading r) {
    if (reader.layout == ReadingLayout.flowing) {
      final ayah = r.place <= r.firstPage
          ? quran.ayahById(r.firstAyah).ref
          : quran.firstAyahOnPage(r.place).ref;
      reader.jumpTo(ayah, highlight: false);
    } else {
      reader.jumpToPage(r.place);
    }
  }

  /// Opens the first page of [w] without moving the place (FR-033).
  void openWird(Wird w) {
    if (reader.layout == ReadingLayout.flowing) {
      reader.jumpTo(quran.ayahById(w.firstAyah).ref, highlight: false);
    } else {
      reader.jumpToPage(firstPageOf(w));
    }
  }

  // --- Following the reader (research R3) ----------------------------------------------------

  (int, int) _pagesOnScreen() {
    final page = reader.page;
    if (reader.layout == ReadingLayout.mushaf && reader.spreadOnScreen) {
      final right = page.isOdd ? page : page - 1;
      return (right, (right + 1).clamp(1, QuranIndex.pageCount));
    }
    return (page, page);
  }

  void _syncTrackers() {
    final (first, last) = _pagesOnScreen();
    final wanted = {for (final r in readings) r.key: r};
    _trackers.removeWhere((key, t) {
      final r = wanted[key];
      return r == null || r.firstPage != t.firstPage || r.lastPage != t.lastPage;
    });
    for (final r in wanted.values) {
      if (_trackers.containsKey(r.key)) continue;
      _trackers[r.key] = ReadingTracker(
        firstPage: r.firstPage,
        lastPage: r.lastPage,
        place: r.place,
        marksOnPass: r.kind == ReadingKind.wird,
      )..onJump(first, last);
    }
  }

  void _onReader() {
    final (first, last) = _pagesOnScreen();
    final serial = reader.jumpSerial;
    if (first == _lastFirst && last == _lastLast && serial == _lastSerial) return;
    final jump = serial != _lastSerial || _lastFirst == null;
    _lastFirst = first;
    _lastLast = last;
    _lastSerial = serial;
    // During memorization the place never moves (P9).
    final byReader = !jump && !_isMemorizing();
    var changed = false;
    for (final entry in _trackers.entries.toList()) {
      final result = entry.value.onMove(first, last, byReader: byReader);
      switch (result) {
        case TrackResult.none:
          break;
        case TrackResult.moved:
          changed = true;
          _placeMoved(entry.key, entry.value.place);
        case TrackResult.passedEnd:
          if (entry.key == wirdKey) unawaited(_readOn(first));
      }
    }
    if (changed) notifyListeners();
  }

  void _placeMoved(String key, int page) {
    if (key != wirdKey) {
      _groups?.moveGroupPlace(key, page);
      return;
    }
    final k = _khatma;
    if (k == null) return;
    _khatma = k.copyWith(placePage: page);
    _placeTimer?.cancel();
    _placeTimer = Timer(_placeSaveDelay, _savePlace);
  }

  void _savePlace() {
    _placeTimer?.cancel();
    _placeTimer = null;
    final k = _khatma;
    if (k != null) unawaited(repository.savePlace(k.id, k.placePage));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_placeTimer != null) _savePlace();
    }
  }

  /// Reading on past the end: the wird, and any very short one passed whole, are read; the next
  /// wird is current, its place the page on screen (R4, P7).
  Future<void> _readOn(int firstOnScreen) async {
    final k = _khatma;
    if (k == null || !isActive) return;
    _remember(byReadingOn: true);
    final day = today;
    final reads = <int, CalendarDay?>{};
    var wirds = _wirds;
    while (true) {
      final i = wirds.indexWhere((w) => !w.isRead);
      if (i < 0 || firstOnScreen <= lastPageOf(wirds[i])) break;
      reads[wirds[i].number] = day;
      wirds = [...wirds]..[i] = wirds[i].withReadOn(day);
    }
    await _afterReads(k, wirds, reads, placeFrom: firstOnScreen, byReadingOn: true);
  }

  // --- Actions -------------------------------------------------------------------------------

  /// Starts a khatma (FR-001). Throws [KhatmaInProgress] when one is in progress (FR-005).
  Future<void> start(KhatmaPlan plan, {required int startAyah, required CalendarDay startDate}) async {
    final ranges = divide(index, startAyah, plan);
    final open = await repository.start(
      plan: plan,
      startAyah: startAyah,
      startDate: startDate,
      ranges: ranges,
      placePage: index.pageOf(startAyah),
    );
    unawaited((keepBrowserData ?? const DeviceChannel().keepBrowserData)());
    Usage.khatmaStarted();
    _khatma = open.khatma;
    _wirds = open.wirds;
    _undo = null;
    _syncTrackers();
    notifyListeners();
  }

  /// Marks the current wird as read: Done, on the reading screen or the Khatma screen (FR-012).
  Future<void> markRead() async {
    final k = _khatma;
    final w = currentWird;
    if (k == null || w == null) return;
    _remember(byReadingOn: false);
    Usage.wirdCompleted();
    final day = today;
    final wirds = [for (final x in _wirds) x.number == w.number ? x.withReadOn(day) : x];
    await _afterReads(k, wirds, {w.number: day}, byReadingOn: false);
  }

  /// Done on a reading's row: the wird, or a group part.
  Future<void> markReadingRead(Reading r) async {
    if (r.kind == ReadingKind.wird) return markRead();
    await _groups?.markGroupPartRead(r.key);
  }

  /// Writes [reads], finishing the khatma when no wird is left (FR-034).
  Future<void> _afterReads(Khatma k, List<Wird> wirds, Map<int, CalendarDay?> reads,
      {int? placeFrom, required bool byReadingOn}) async {
    _placeTimer?.cancel();
    _placeTimer = null;
    final next = wirds.where((w) => !w.isRead).firstOrNull;
    if (next == null) {
      final done = k.copyWith(
        state: KhatmaState.finished,
        finishedOn: () => today,
        placePage: QuranIndex.pageCount,
        wirdCount: wirds.length,
      );
      await repository.replace(done, const []);
      _khatma = null;
      _wirds = const [];
      _record = [done, ..._record];
      _syncTrackers();
      _emit(KhatmaEventKind.finished, byReadingOn: byReadingOn);
      notifyListeners();
      return;
    }
    final first = firstPageOf(next), last = lastPageOf(next);
    final place = (placeFrom ?? first).clamp(first, last);
    final updated = k.copyWith(placePage: place);
    await repository.apply(updated, reads: reads);
    _khatma = updated;
    _wirds = wirds;
    _trackers.remove(wirdKey);
    _syncTrackers();
    if (placeFrom != null) {
      // Reading on: the reader is on the new place and goes on from it.
      final (f, l) = _pagesOnScreen();
      _trackers[wirdKey]?.onJump(f, l);
    }
    _emit(KhatmaEventKind.wirdDone, byReadingOn: byReadingOn);
    notifyListeners();
  }

  void _remember({required bool byReadingOn}) {
    final k = _khatma;
    if (k == null) return;
    _undo = OpenKhatma(k, _wirds);
    _undoByReadingOn = byReadingOn;
  }

  void _emit(KhatmaEventKind kind, {required bool byReadingOn}) =>
      events.value = KhatmaEvent(++_eventSerial, kind, byReadingOn: byReadingOn);

  bool get canUndo => _undo != null;

  /// Puts back the wird, the place and the state as they were before the last Done or reading
  /// on (FR-016). After reading on, the place is the wird's last page.
  Future<void> undo() async {
    final before = _undo;
    if (before == null) return;
    _undo = null;
    var k = before.khatma;
    if (_undoByReadingOn) {
      final w = before.wirds.where((w) => !w.isRead).firstOrNull;
      if (w != null) k = k.copyWith(placePage: lastPageOf(w));
    }
    await repository.replace(k, before.wirds);
    _record = [for (final r in _record) if (r.id != k.id) r];
    _khatma = k;
    _wirds = before.wirds;
    _trackers.remove(wirdKey);
    _syncTrackers();
    notifyListeners();
  }

  /// How many wirds "Set khatma place here" on ayah [ayahId] makes read and unread (FR-017).
  ({int read, int unread}) countChangesFor(int ayahId) {
    final at = _wirds.indexWhere((w) => w.firstAyah <= ayahId && w.lastAyah >= ayahId);
    if (at < 0) return (read: 0, unread: 0);
    var read = 0, unread = 0;
    for (var i = 0; i < _wirds.length; i++) {
      if (i < at && !_wirds[i].isRead) read++;
      if (i >= at && _wirds[i].isRead) unread++;
    }
    return (read: read, unread: unread);
  }

  /// Whether "Set khatma place here" applies to ayah [ayahId]: a khatma in progress or paused
  /// that covers it.
  bool canSetPlaceAt(int ayahId) =>
      _khatma != null && _wirds.any((w) => w.firstAyah <= ayahId && w.lastAyah >= ayahId);

  /// "Set khatma place here" (FR-017): the wird holding the ayah is current, the wirds before it
  /// are read (today, for those newly marked), the later ones unread, and the place is the
  /// ayah's page.
  Future<void> setPlaceAt(int ayahId) async {
    final k = _khatma;
    if (k == null) return;
    final at = _wirds.indexWhere((w) => w.firstAyah <= ayahId && w.lastAyah >= ayahId);
    if (at < 0) return;
    final day = today;
    final reads = <int, CalendarDay?>{};
    final wirds = <Wird>[];
    for (var i = 0; i < _wirds.length; i++) {
      final w = _wirds[i];
      if (i < at && !w.isRead) {
        reads[w.number] = day;
        wirds.add(w.withReadOn(day));
      } else if (i >= at && w.isRead) {
        reads[w.number] = null;
        wirds.add(w.withReadOn(null));
      } else {
        wirds.add(w);
      }
    }
    final updated = k.copyWith(placePage: index.pageOf(ayahId));
    await repository.apply(updated, reads: reads);
    _undo = null;
    _khatma = updated;
    _wirds = wirds;
    _trackers.remove(wirdKey);
    _syncTrackers();
    notifyListeners();
  }

  /// Where a changed plan starts: the place, or the current wird's start when the place is on
  /// its first page (data-model.md › State changes › Change plan).
  int get changePlanStartAyah {
    final w = currentWird;
    final k = _khatma;
    if (w == null || k == null) return 1;
    return k.placePage > firstPageOf(w) ? index.firstAyahOn(k.placePage) : w.firstAyah;
  }

  /// The first day the changed plan's wirds are for: tomorrow when today is read.
  CalendarDay get changePlanFirstDay {
    final k = _khatma;
    final day = todayRead ? today.addDays(1) : today;
    return k != null && k.startDate.isAfter(day) ? k.startDate : day;
  }

  /// Divides everything from the place to the end again with [plan] (FR-030). What was read
  /// stays read; the part of the current wird before the place stays as a read wird.
  Future<void> changePlan(KhatmaPlan plan) async {
    final k = _khatma;
    final w = currentWird;
    if (k == null || w == null) return;
    final start = changePlanStartAyah;
    final kept = <Wird>[for (final x in _wirds) if (x.isRead) x];
    if (start > w.firstAyah) {
      kept.add(Wird(
        khatmaId: k.id,
        number: w.number,
        firstAyah: w.firstAyah,
        lastAyah: start - 1,
        readOn: today,
      ));
    }
    var number = kept.isEmpty ? 0 : kept.last.number;
    final fresh = [
      for (final r in divide(index, start, plan))
        Wird(khatmaId: k.id, number: ++number, firstAyah: r.firstAyah, lastAyah: r.lastAyah),
    ];
    final wirds = [...kept, ...fresh];
    final firstDay = changePlanFirstDay;
    final updated = k.copyWith(
      plan: plan,
      wirdCount: wirds.length,
      plannedFinish: firstDay.addDays(fresh.length - 1),
      placePage: index.pageOf(start),
    );
    await repository.replace(updated, wirds);
    _undo = null;
    _khatma = updated;
    _wirds = wirds;
    _trackers.remove(wirdKey);
    _syncTrackers();
    notifyListeners();
  }

  /// Pauses the khatma (FR-031): no reminder for it while paused.
  Future<void> pause() async {
    final k = _khatma;
    if (k == null || k.state != KhatmaState.active) return;
    final updated = k.copyWith(state: KhatmaState.paused, pausedOn: () => today);
    await repository.apply(updated);
    _undo = null;
    _khatma = updated;
    _syncTrackers();
    notifyListeners();
  }

  /// Resumes it: the planned finish moves later by the days it was paused (FR-031).
  Future<void> resume() async {
    final k = _khatma;
    if (k == null || k.state != KhatmaState.paused) return;
    final paused = k.pausedOn == null ? 0 : today.daysSince(k.pausedOn!).clamp(0, 100000);
    final updated = k.copyWith(
      state: KhatmaState.active,
      pausedOn: () => null,
      plannedFinish: k.plannedFinish.addDays(paused),
    );
    await repository.apply(updated);
    _khatma = updated;
    _syncTrackers();
    notifyListeners();
  }

  /// Ends the khatma (FR-032): nothing is added to the record.
  Future<void> end() async {
    final k = _khatma;
    if (k == null) return;
    _placeTimer?.cancel();
    _placeTimer = null;
    await repository.delete(k.id);
    _undo = null;
    _khatma = null;
    _wirds = const [];
    _syncTrackers();
    notifyListeners();
  }

  /// Deletes a record entry (FR-037).
  Future<void> deleteRecord(int id) async {
    await repository.delete(id);
    _record = [for (final r in _record) if (r.id != id) r];
    if (_undo?.khatma.id == id) _undo = null;
    notifyListeners();
  }

  /// Changes the reminder setting (FR-019, FR-025).
  Future<void> setReminder(ReminderSetting r) async {
    if (r == _reminder) return;
    _reminder = r;
    notifyListeners();
    await repository.writeReminder(r);
  }

  @override
  void dispose() {
    _disposed = true;
    if (_loaded) {
      reader.removeListener(_onReader);
      WidgetsBinding.instance.removeObserver(this);
    }
    _groups?.removeListener(_onGroups);
    if (_placeTimer != null) _savePlace();
    events.dispose();
    super.dispose();
  }
}

/// Provides the [KhatmaController] to the widget tree and rebuilds dependents on change.
class KhatmaScope extends InheritedNotifier<KhatmaController> {
  const KhatmaScope({super.key, required KhatmaController controller, required super.child})
      : super(notifier: controller);

  static KhatmaController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KhatmaScope>()?.notifier;

  static KhatmaController of(BuildContext context) => maybeOf(context)!;

  /// Access without subscribing to changes (event handlers).
  static KhatmaController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<KhatmaScope>()?.notifier;
}
