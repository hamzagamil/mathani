// Per-surah downloads for offline listening (specs/004-ayah-recitations/contracts/
// audio-storage.md › Downloads; data-model › Surah Download). State comes from the files on disk:
// there is no download table. A surah is complete when every ayah, and its basmala when it has
// one, is saved with its catalogue size (FR-031).
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../data/models.dart';
import '../../data/quran_repository.dart';
import '../../shared/device_channel.dart';
import '../../shared/numerals.dart';
import 'ayah_fetcher.dart';

/// Requests at once across the whole queue (research R6, R7). The fetcher's gate enforces it,
/// with a recitation's prefetch first.
const downloadConcurrency = maxConcurrentRequests;

/// Free space a download must leave on the device (FR-028).
const storageHeadroomBytes = 50 * 1024 * 1024;

/// Progress is published at most this often.
const progressUpdatesPerSecond = 4;

enum DownloadState { absent, queued, downloading, stopped, complete }

enum StopReason { noConnection, noStorage, fetchFailed }

@immutable
class SurahDownload {
  const SurahDownload({
    required this.reciter,
    required this.surah,
    required this.savedBytes,
    required this.totalBytes,
    required this.state,
    this.stopReason,
    this.basmalaBytes = 0,
  });

  final String reciter;
  final int surah;
  final int savedBytes;
  final int totalBytes;
  final DownloadState state;
  final StopReason? stopReason;

  /// The reciter's shared basmala.mp3, when counted in [savedBytes] (once per reciter in totals).
  final int basmalaBytes;

  double get progress => totalBytes == 0 ? 0 : savedBytes / totalBytes;

  SurahDownload copyWith({int? savedBytes, DownloadState? state, StopReason? stopReason}) =>
      SurahDownload(
        reciter: reciter,
        surah: surah,
        savedBytes: savedBytes ?? this.savedBytes,
        totalBytes: totalBytes,
        state: state ?? this.state,
        stopReason: stopReason,
        basmalaBytes: basmalaBytes,
      );
}

typedef DownloadKey = (String reciter, int surah);

class DownloadQueue with WidgetsBindingObserver {
  DownloadQueue({
    required this.quran,
    required this.fetcher,
    this.device = const DeviceChannel(),
    Reciter? Function(String id)? reciter,
  }) : _reciter = reciter ?? quran.reciter {
    _damage = fetcher.onDamaged.listen((d) => unawaited(_rescan(d.$1, d.$2)));
    WidgetsBinding.instance.addObserver(this);
  }

  final QuranRepository quran;
  final AyahFetcher fetcher;
  final DeviceChannel device;

  /// Where a reciter's files come from (tests point it at a local server).
  final Reciter? Function(String id) _reciter;

  /// Every surah with any saved file, queued or downloading. Absent surahs are not listed.
  final states = ValueNotifier<Map<DownloadKey, SurahDownload>>(const {});

  /// False until the first disk scan finishes: screens show placeholders meanwhile and are
  /// never blocked by it (Principle III).
  final scanned = ValueNotifier<bool>(false);

  final _queue = <DownloadKey>[];
  DownloadKey? _active;
  int _generation = 0;
  Future<void>? _scan;
  late final StreamSubscription<(String, int)> _damage;
  Timer? _publish;
  bool _dirty = false;
  bool _appInBackground = false;
  bool _stoppedInBackground = false;

  SurahDownload? stateOf(String reciter, int surah) => states.value[(reciter, surah)];

  bool isComplete(String reciter, int surah) =>
      stateOf(reciter, surah)?.state == DownloadState.complete;

  /// Bytes saved for [reciter], or for every reciter. The shared basmala counts once per reciter.
  int savedBytes([String? reciter]) {
    var total = 0;
    final basmala = <String, int>{};
    for (final d in states.value.values) {
      if (reciter != null && d.reciter != reciter) continue;
      total += d.savedBytes - d.basmalaBytes;
      if (d.basmalaBytes > 0) basmala[d.reciter] = d.basmalaBytes;
    }
    return total + basmala.values.fold(0, (a, b) => a + b);
  }

  // --- Disk scan -----------------------------------------------------------------------------

  /// Scans the downloads directory once; later calls return the same scan.
  Future<void> ensureScanned() => _scan ??= () async {
        await fetcher.init();
        final root = await fetcher.downloadsRoot();
        final found = <DownloadKey, SurahDownload>{};
        if (await root.exists()) {
          await for (final reciterDir in root.list()) {
            if (reciterDir is! Directory) continue;
            final reciter = reciterDir.uri.pathSegments.where((s) => s.isNotEmpty).last;
            if (_reciter(reciter) == null) continue;
            await for (final surahDir in reciterDir.list()) {
              if (surahDir is! Directory) continue;
              final surah = int.tryParse(surahDir.uri.pathSegments.where((s) => s.isNotEmpty).last);
              if (surah == null || surah < 1 || surah > 114) continue;
              final d = await _measure(reciter, surah);
              if (d.savedBytes > 0) found[(reciter, surah)] = d;
            }
          }
        }
        states.value = {...found, ...states.value}; // keep anything queued meanwhile
        scanned.value = true;
      }();

  /// The saved state of one surah, from its files.
  Future<SurahDownload> _measure(String reciter, int surah) async {
    final sizes = await quran.recordingBytes(reciter, surah);
    var saved = 0, valid = 0;
    for (var a = 1; a <= sizes.length; a++) {
      final f = await fetcher.downloadFile(reciter, surah, a);
      if (await AyahFetcher.isValid(f, sizes[a - 1])) {
        saved += sizes[a - 1];
        valid++;
      }
    }
    var basmalaOk = true;
    var basmalaBytes = 0;
    if (QuranRepository.hasBasmalaItem(surah)) {
      final bytes = (await quran.recordingBytes(reciter, 1)).first;
      basmalaOk = await AyahFetcher.isValid(await fetcher.basmalaFile(reciter), bytes);
      if (basmalaOk && valid > 0) {
        saved += bytes;
        basmalaBytes = bytes;
      }
    }
    final complete = valid == sizes.length && basmalaOk;
    return SurahDownload(
      reciter: reciter,
      surah: surah,
      savedBytes: valid == 0 ? 0 : saved,
      totalBytes: await quran.surahDownloadBytes(reciter, surah),
      state: complete
          ? DownloadState.complete
          : (valid == 0 ? DownloadState.absent : DownloadState.stopped),
      basmalaBytes: basmalaBytes,
    );
  }

  Future<void> _rescan(String reciter, int surah) async {
    final d = await _measure(reciter, surah);
    _set(d.savedBytes == 0 && d.state == DownloadState.absent ? null : d, (reciter, surah));
  }

  // --- Sizes ---------------------------------------------------------------------------------

  /// Bytes still to download for [surah] (FR-028). No network.
  Future<int> sizeOf(String reciter, int surah) async {
    final d = await _measure(reciter, surah);
    if (d.state == DownloadState.complete) return 0;
    var remaining = d.totalBytes - d.savedBytes;
    // A saved basmala counts only alongside saved ayat in _measure; subtract it here too.
    if (d.savedBytes == 0 && QuranRepository.hasBasmalaItem(surah)) {
      final bytes = (await quran.recordingBytes(reciter, 1)).first;
      if (await AyahFetcher.isValid(await fetcher.basmalaFile(reciter), bytes)) remaining -= bytes;
    }
    return remaining;
  }

  // --- Queue ---------------------------------------------------------------------------------

  /// Adds [surah] to the queue. Already complete or queued: nothing happens.
  Future<void> enqueue(String reciter, int surah) async {
    await ensureScanned();
    final key = (reciter, surah);
    final current = states.value[key];
    if (current?.state == DownloadState.complete || _queue.contains(key) || _active == key) return;
    final d = current ?? await _measure(reciter, surah);
    if (d.state == DownloadState.complete) {
      _set(d, key);
      return;
    }
    _queue.add(key);
    _set(d.copyWith(state: DownloadState.queued), key);
    unawaited(_pump());
  }

  /// Stops [surah] (or takes it out of the queue). Saved files are kept: it shows as stopped.
  Future<void> cancel(String reciter, int surah) async {
    final key = (reciter, surah);
    _queue.remove(key);
    if (_active == key) {
      _generation++;
      _active = null;
    }
    final d = await _measure(reciter, surah);
    _set(d.savedBytes == 0 ? null : d, key);
    unawaited(_pump());
  }

  /// Deletes [surah]'s files; the state updates at once (FR-033, SC-012).
  Future<void> delete(String reciter, int surah) async {
    final key = (reciter, surah);
    _queue.remove(key);
    if (_active == key) {
      _generation++;
      _active = null;
    }
    _set(null, key);
    final dir = Directory(await fetcher.downloadDir(reciter, surah));
    if (await dir.exists()) await dir.delete(recursive: true);
    unawaited(_pump());
  }

  /// Deletes every download of [reciter], including its basmala.
  Future<void> deleteAll(String reciter) async {
    _queue.removeWhere((k) => k.$1 == reciter);
    if (_active?.$1 == reciter) {
      _generation++;
      _active = null;
    }
    states.value = {
      for (final e in states.value.entries)
        if (e.key.$1 != reciter) e.key: e.value,
    };
    final dir = await fetcher.reciterDownloads(reciter);
    if (await dir.exists()) await dir.delete(recursive: true);
    unawaited(_pump());
  }

  /// Downloads queued surahs one after another.
  Future<void> _pump() async {
    if (_active != null || _queue.isEmpty) return;
    final key = _active = _queue.removeAt(0);
    final generation = ++_generation;
    final (reciterId, surah) = key;
    final reciter = _reciter(reciterId);
    if (reciter == null) {
      _active = null;
      return;
    }
    var d = await _measure(reciterId, surah);
    _set(d.copyWith(state: DownloadState.downloading), key);

    // Basmala first, then the ayat in order (contract › Downloads › Order).
    final tasks = <(int, int, File, int)>[]; // (surah, ayah, target, bytes)
    if (QuranRepository.hasBasmalaItem(surah)) {
      final bytes = (await quran.recordingBytes(reciterId, 1)).first;
      final f = await fetcher.basmalaFile(reciterId);
      if (!await AyahFetcher.isValid(f, bytes)) tasks.add((1, 1, f, bytes));
    }
    final sizes = await quran.recordingBytes(reciterId, surah);
    for (var a = 1; a <= sizes.length; a++) {
      final f = await fetcher.downloadFile(reciterId, surah, a);
      if (!await AyahFetcher.isValid(f, sizes[a - 1])) tasks.add((surah, a, f, sizes[a - 1]));
    }

    StopReason? stop;
    var next = 0;
    Future<void> worker() async {
      while (stop == null && generation == _generation && next < tasks.length) {
        final (s, a, target, bytes) = tasks[next++];
        try {
          final cached = await fetcher.cacheFile(reciterId, s, a);
          if (await AyahFetcher.isValid(cached, bytes)) {
            await target.parent.create(recursive: true);
            await cached.copy('${target.path}.part');
            await File('${target.path}.part').rename(target.path);
          } else {
            await fetcher.fetch(reciter, s, a, target, bytes: bytes);
          }
        } on FetchException catch (e) {
          stop ??= e.error == FetchError.offline ? StopReason.noConnection : StopReason.fetchFailed;
          return;
        } on FileSystemException catch (e) {
          final code = e.osError?.errorCode;
          stop ??= code == 28 || code == 112 ? StopReason.noStorage : StopReason.fetchFailed;
          return;
        }
        if (generation != _generation) return;
        final current = states.value[key];
        if (current != null) {
          _set(current.copyWith(savedBytes: current.savedBytes + bytes, state: DownloadState.downloading),
              key, throttle: true);
        }
      }
    }

    await Future.wait([for (var i = 0; i < downloadConcurrency; i++) worker()]);
    if (generation != _generation) return; // cancelled or deleted
    _active = null;
    d = await _measure(reciterId, surah);
    if (stop != null) {
      _set(d.copyWith(state: DownloadState.stopped, stopReason: stop), key);
      // The queue stops until the reader resumes it (contract › Downloads › Interruptions).
      for (final k in _queue) {
        final q = states.value[k];
        if (q != null) _set(q.copyWith(state: DownloadState.stopped, stopReason: stop), k);
      }
      _queue.clear();
      if (_appInBackground) _stoppedInBackground = true;
      return;
    }
    _set(d, key);
    unawaited(_pump());
  }

  void _set(SurahDownload? d, DownloadKey key, {bool throttle = false}) {
    final next = {...states.value};
    if (d == null) {
      next.remove(key);
    } else {
      next[key] = d;
    }
    if (!throttle) {
      _publish?.cancel();
      _publish = null;
      _dirty = false;
      states.value = next;
      return;
    }
    _pending = next;
    _dirty = true;
    _publish ??= Timer(const Duration(milliseconds: 1000 ~/ progressUpdatesPerSecond), () {
      _publish = null;
      if (_dirty) {
        _dirty = false;
        states.value = _pending!;
      }
    });
  }

  Map<DownloadKey, SurahDownload>? _pending;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInBackground = state != AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed && _stoppedInBackground) {
      // Stopped only because the system suspended the app: carry on (contract › Interruptions).
      _stoppedInBackground = false;
      for (final e in states.value.entries) {
        if (e.value.state == DownloadState.stopped && e.value.stopReason == StopReason.noConnection) {
          unawaited(enqueue(e.key.$1, e.key.$2));
        }
      }
    }
  }

  void dispose() {
    _generation++;
    _publish?.cancel();
    unawaited(_damage.cancel());
    WidgetsBinding.instance.removeObserver(this);
    states.dispose();
    scanned.dispose();
  }
}

/// A size in the interface language: one decimal in MB, or KB under 1 MB.
String formatSize(AppLocalizations l10n, Locale locale, int bytes) {
  String number(double v) {
    final s = v.toStringAsFixed(1);
    if (locale.languageCode != 'ar') return s;
    final whole = s.split('.');
    return '${toEasternArabic(int.parse(whole[0]))}٫${toEasternArabic(int.parse(whole[1]))}';
  }

  const mb = 1024 * 1024;
  return bytes >= mb ? l10n.sizeMb(number(bytes / mb)) : l10n.sizeKb(number(bytes / 1024));
}

/// Starts downloading [surah] for [reciter] after the checks in contracts/audio-storage.md ›
/// Preconditions: no connection, not enough storage, then confirmation on mobile data.
Future<void> startSurahDownload(
    BuildContext context, DownloadQueue queue, String reciter, int surah) async {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context);
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  final network = await queue.device.networkState();
  if (network == NetworkState.none) {
    say(l10n.noInternet);
    return;
  }
  final size = await queue.sizeOf(reciter, surah);
  if (size == 0) {
    await queue.enqueue(reciter, surah); // already complete: just records it
    return;
  }
  final free = await queue.device.freeBytes();
  final sizeText = formatSize(l10n, locale, size);
  if (free < size + storageHeadroomBytes) {
    say(l10n.notEnoughStorage(formatSize(l10n, locale, size + storageHeadroomBytes)));
    return;
  }
  if (network == NetworkState.metered) {
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.downloadOnMobileData(sizeText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.download),
          ),
        ],
      ),
    );
    if (ok != true) return;
  }
  await queue.enqueue(reciter, surah);
}
