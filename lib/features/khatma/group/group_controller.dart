import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../analytics/usage.dart';
import '../khatma_controller.dart';
import '../khatma_models.dart';
import 'group_client.dart';
import 'group_models.dart';
import 'group_repository.dart';

/// The version of the group khatma terms the app shows (FR-059).
const groupTermsVersion = 1;

/// The group khatmas while the app runs (specs/014 contracts/group-ui.md › Dart interfaces): the
/// kept list, the actions, the refresh and retry timers, and the readings it gives to the
/// [KhatmaController]. Idle, with no request, until the reader keeps a group khatma or opens one
/// (FR-054, SC-012).
class GroupController extends ChangeNotifier with WidgetsBindingObserver implements GroupReadings {
  GroupController({
    required this.client,
    required this.repository,
    required this.khatma,
    DateTime Function()? clock,
    this.pollEvery = const Duration(seconds: 20),
    this.retryEvery = const Duration(seconds: 60),
    this.keepBrowserData,
  }) : _clock = clock ?? DateTime.now;

  final GroupClient client;
  final GroupRepository repository;
  final KhatmaController khatma;
  final DateTime Function() _clock;
  final Duration pollEvery;
  final Duration retryEvery;

  /// Asks the browser to keep the site's data when starting or joining (FR-042).
  final Future<void> Function()? keepBrowserData;

  bool _loaded = false;
  final _kept = <String, KeptKhatma>{};
  final _parts = <(String, int), HeldPart>{};
  final _gone = <String>{};
  final _notYours = <String>{};
  String? _watching;
  Timer? _poll;
  Timer? _retry;
  bool _foreground = true;
  String? _name;
  int? _terms;

  bool get loaded => _loaded;

  /// The kept khatmas, newest first.
  List<KeptKhatma> get kept => _kept.values.toList()
    ..sort((a, b) => b.snapshot.createdAt.compareTo(a.snapshot.createdAt));

  KeptKhatma? keptOf(String code) => _kept[code];

  /// Khatmas the server said no longer exist, until the reader removes them (contracts › Gone).
  bool isGone(String code) => _gone.contains(code);

  /// A waiting mark the server refused: the part is no longer the reader's (contracts › States).
  bool lostPart(String code) => _notYours.contains(code);

  bool isPending(String code, int n) => _parts[(code, n)]?.pending ?? false;

  /// The name last typed, offered again (FR-049).
  String? get lastName => _name;

  bool get termsAccepted => (_terms ?? 0) >= groupTermsVersion;

  Future<void> load() async {
    if (_loaded) return;
    final (kept, parts, name, terms) =
        await (repository.loadKept(), repository.loadParts(), repository.name(), repository.acceptedTerms()).wait;
    for (final k in kept) {
      _kept[k.code] = k;
    }
    for (final p in parts) {
      _parts[(p.code, p.number)] = p;
    }
    _name = name;
    _terms = terms;
    _loaded = true;
    WidgetsBinding.instance.addObserver(this);
    khatma.attachGroups(this);
    _scheduleRetry();
    notifyListeners();
  }

  Future<void> acceptTerms() async {
    _terms = groupTermsVersion;
    await repository.acceptTerms(groupTermsVersion);
    notifyListeners();
  }

  // --- Keeping state ------------------------------------------------------------------------

  Future<void> _keep(Snapshot s) async {
    final old = _kept[s.code];
    final k = KeptKhatma(snapshot: s, seenAt: _clock().millisecondsSinceEpoch, hidden: old?.hidden ?? const {});
    _kept[s.code] = k;
    _gone.remove(s.code);
    // Places for parts the reader now holds; parts no longer held are forgotten, unless a mark
    // waits to be sent for them.
    final mine = {for (final p in s.mine) p.n};
    for (final n in mine) {
      if (!_parts.containsKey((s.code, n))) {
        final part = HeldPart(code: s.code, number: n, placePage: _rangeOf(s, n).firstPage);
        _parts[(s.code, n)] = part;
        await repository.savePart(part);
      }
    }
    for (final key in _parts.keys.where((k) => k.$1 == s.code && !mine.contains(k.$2)).toList()) {
      if (_parts[key]!.pending) continue;
      _parts.remove(key);
      await repository.removePart(key.$1, key.$2);
    }
    await repository.save(k);
    notifyListeners();
  }

  /// A snapshot with the reader's waiting marks applied, as the device shows it (FR-053).
  Snapshot shown(String code) {
    var s = _kept[code]!.snapshot;
    for (final p in _parts.values) {
      if (p.code != code || !p.pending) continue;
      final part = s.parts.firstWhere((x) => x.n == p.number);
      if (part.state == PartState.taken) {
        s = s.withPart(part.copyWith(state: PartState.read, readAt: () => _clock().millisecondsSinceEpoch));
      }
    }
    return s;
  }

  Future<T> _call<T>(String code, Future<T> Function() action) async {
    try {
      final result = await action();
      unawaited(sendWaiting());
      return result;
    } on GroupFailure catch (f) {
      if (f.kind == GroupFailureKind.gone) {
        _gone.add(code);
        notifyListeners();
      } else if (f.snapshot != null) {
        await _keep(f.snapshot!);
      }
      rethrow;
    }
  }

  // --- Reading the server -------------------------------------------------------------------

  /// Opens a khatma: the kept copy at once, then the server's (FR-055).
  Future<Snapshot?> open(String code) async {
    await load();
    try {
      await refresh(code);
    } on GroupFailure catch (f) {
      if (f.kind != GroupFailureKind.offline || !_kept.containsKey(code)) rethrow;
    }
    return _kept[code]?.snapshot;
  }

  /// One read, sending the kept version so an unchanged khatma answers 304.
  Future<void> refresh(String code) => _call(code, () async {
        try {
          await _keep(await client.read(code, version: _kept[code]?.snapshot.version));
        } on GroupFailure catch (f) {
          if (f.kind != GroupFailureKind.notModified) rethrow;
          final k = _kept[code];
          if (k != null) {
            _kept[code] = k.copyWith(seenAt: _clock().millisecondsSinceEpoch);
            await repository.save(_kept[code]!);
            notifyListeners();
          }
        }
      });

  /// A read of each kept khatma, when the Khatma screen opens (contracts › Refreshing).
  Future<void> refreshAll() async {
    await load();
    for (final code in _kept.keys.toList()) {
      try {
        await refresh(code);
      } on GroupFailure {
        // shown from the device's copy
      }
    }
  }

  /// A group khatma is on screen: a read every [pollEvery] while the app is in front (FR-054).
  void watch(String code) {
    _watching = code;
    _poll?.cancel();
    _poll = Timer.periodic(pollEvery, (_) {
      if (_foreground && _watching == code) unawaited(refresh(code).catchError((_) {}));
    });
  }

  void unwatch(String code) {
    if (_watching != code) return;
    _watching = null;
    _poll?.cancel();
    _poll = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(sendWaiting());
      final w = _watching;
      if (w != null) unawaited(refresh(w).catchError((_) {}));
    }
  }

  void _scheduleRetry() {
    _retry?.cancel();
    if (!_parts.values.any((p) => p.pending)) return;
    _retry = Timer.periodic(retryEvery, (_) {
      if (_foreground) unawaited(sendWaiting());
    });
  }

  bool _sending = false;

  /// Sends every waiting mark; a refused one is dropped and the reader told (research R18).
  Future<void> sendWaiting() async {
    if (_sending) return;
    _sending = true;
    try {
      for (final p in _parts.values.where((p) => p.pending).toList()) {
        try {
          final s = await client.markRead(p.code, p.number, read: true);
          await _clearPending(p);
          await _keep(s);
        } on GroupFailure catch (f) {
          if (f.kind == GroupFailureKind.offline) break;
          await _clearPending(p);
          if (f.kind == GroupFailureKind.notYours || f.kind == GroupFailureKind.gone) {
            _notYours.add(p.code);
          }
          if (f.snapshot != null) await _keep(f.snapshot!);
          if (f.kind == GroupFailureKind.gone) _gone.add(p.code);
        }
      }
    } finally {
      _sending = false;
      _scheduleRetry();
      notifyListeners();
    }
  }

  Future<void> _clearPending(HeldPart p) async {
    final cleared = HeldPart(code: p.code, number: p.number, placePage: p.placePage);
    _parts[(p.code, p.number)] = cleared;
    await repository.savePart(cleared);
  }

  void dismissLostPart(String code) {
    _notYours.remove(code);
    notifyListeners();
  }

  // --- Actions ------------------------------------------------------------------------------

  Future<Snapshot> start({required String title, required String name, required int division, String? finishDate}) async {
    await load();
    final s = await client.start(
        title: title, name: name, division: division, finishDate: finishDate, terms: groupTermsVersion);
    await _rememberName(name);
    unawaited(keepBrowserData?.call());
    Usage.groupKhatmaStarted(parts: division); // specs/016: never the title or names
    await _keep(s);
    return s;
  }

  Future<void> _rememberName(String name) async {
    _name = name;
    await repository.saveName(name);
  }

  /// Takes part [n]; [name] the first time the reader joins this khatma (FR-049).
  Future<void> take(String code, int n, {String? name}) => _call(code, () async {
        final s = await client.take(code, n, name: name, terms: name == null ? null : groupTermsVersion);
        if (name != null) {
          await _rememberName(name);
          Usage.groupKhatmaJoined(); // the first part taken in this khatma (FR-049)
        }
        unawaited(keepBrowserData?.call());
        await _keep(s);
      });

  Future<void> release(String code, int n) =>
      _call(code, () async => _keep(await client.release(code, n)));

  /// Done on a part: shown as read on the device at once, sent now or later (FR-053).
  Future<void> markRead(String code, int n) async {
    final p = _parts[(code, n)] ?? HeldPart(code: code, number: n, placePage: 1);
    final waiting = HeldPart(code: code, number: n, placePage: p.placePage, pending: true);
    _parts[(code, n)] = waiting;
    await repository.savePart(waiting);
    notifyListeners();
    await sendWaiting();
  }

  /// Undoes a mark while the khatma is not complete (FR-051).
  Future<void> undoRead(String code, int n) async {
    final p = _parts[(code, n)];
    if (p != null && p.pending) {
      await _clearPending(p);
      notifyListeners();
      return;
    }
    await _call(code, () async => _keep(await client.markRead(code, n, read: false)));
  }

  /// The organiser marks any part as read or not read (FR-071).
  Future<void> setRead(String code, int n, bool read) =>
      _call(code, () async => _keep(await client.markRead(code, n, read: read)));

  Future<void> assign(String code, int n, String name) =>
      _call(code, () async => _keep(await client.assign(code, n, name)));

  Future<void> removeParticipant(String code, String id) =>
      _call(code, () async => _keep(await client.removeParticipant(code, id)));

  Future<void> edit(String code, {String? title, String? Function()? finishDate}) =>
      _call(code, () async => _keep(await client.edit(code, title: title, finishDate: finishDate)));

  Future<void> leave(String code) async {
    await _call(code, () => client.leave(code));
    await forget(code);
  }

  Future<void> delete(String code) async {
    await _call(code, () => client.delete(code));
    await forget(code);
  }

  /// Reports a name, hidden on this device at once, or the whole khatma, which leaves the list
  /// (FR-061).
  Future<void> report(String code, {String? participant}) async {
    final k = _kept[code];
    if (participant != null && k != null) {
      _kept[code] = k.copyWith(hidden: {...k.hidden, participant});
      await repository.save(_kept[code]!);
      notifyListeners();
    }
    await _call(code, () => client.report(code, participant: participant));
    if (participant == null) await forget(code);
  }

  /// Removes a khatma from this device's list.
  Future<void> forget(String code) async {
    _kept.remove(code);
    _gone.remove(code);
    _notYours.remove(code);
    _parts.removeWhere((k, _) => k.$1 == code);
    unwatch(code);
    await repository.remove(code);
    notifyListeners();
  }

  // --- Readings (research R22) --------------------------------------------------------------

  ({int firstAyah, int lastAyah, int firstPage, int lastPage}) _rangeOf(Snapshot s, int n) {
    final index = khatma.index;
    final r = partRange(
      division: s.division,
      n: n,
      juzStarts: index.juzStarts,
      quarterStarts: index.quarterStarts,
      ayahCount: index.ayahCount,
    );
    return (
      firstAyah: r.firstAyah,
      lastAyah: r.lastAyah,
      firstPage: index.pageOf(r.firstAyah),
      lastPage: index.pageOf(r.lastAyah),
    );
  }

  /// A part's range, for the screens.
  ({int firstAyah, int lastAyah, int firstPage, int lastPage}) rangeOf(String code, int n) =>
      _rangeOf(_kept[code]!.snapshot, n);

  static String readingKey(String code, int n) => 'group:$code:$n';

  /// The parts the reader holds and has not read, as readings.
  @override
  List<Reading> get groupReadings => [
        for (final k in _kept.values)
          if (!_gone.contains(k.code))
            for (final p in shown(k.code).mine)
              if (p.state == PartState.taken)
                () {
                  final r = _rangeOf(k.snapshot, p.n);
                  return Reading(
                    key: readingKey(k.code, p.n),
                    kind: ReadingKind.groupPart,
                    firstAyah: r.firstAyah,
                    lastAyah: r.lastAyah,
                    firstPage: r.firstPage,
                    lastPage: r.lastPage,
                    place: _parts[(k.code, p.n)]?.placePage ?? r.firstPage,
                    title: k.snapshot.title,
                    partNumber: p.n,
                  );
                }(),
      ];

  /// The unread parts the reader holds, for the reminder: (title, division, part number).
  List<({String title, int division, int n})> get heldUnread => [
        for (final k in _kept.values)
          if (!_gone.contains(k.code))
            for (final p in shown(k.code).mine)
              if (p.state == PartState.taken) (title: k.snapshot.title, division: k.snapshot.division, n: p.n),
      ];

  @override
  void moveGroupPlace(String key, int page) {
    final parts = key.split(':');
    if (parts.length != 3) return;
    final id = (parts[1], int.parse(parts[2]));
    final p = _parts[id];
    if (p == null) return;
    final moved = HeldPart(code: p.code, number: p.number, placePage: page, pending: p.pending);
    _parts[id] = moved;
    unawaited(repository.savePart(moved));
  }

  @override
  Future<void> markGroupPartRead(String key) async {
    final parts = key.split(':');
    if (parts.length == 3) await markRead(parts[1], int.parse(parts[2]));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _retry?.cancel();
    if (_loaded) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Provides the [GroupController] to the widget tree.
class GroupScope extends InheritedNotifier<GroupController> {
  const GroupScope({super.key, required GroupController controller, required super.child})
      : super(notifier: controller);

  static GroupController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GroupScope>()?.notifier;

  static GroupController of(BuildContext context) => maybeOf(context)!;

  static GroupController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GroupScope>()?.notifier;
}
