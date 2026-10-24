// Settings › Downloads (specs/004-ayah-recitations/contracts/recitation-ui.md › Downloads screen).
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/numerals.dart';
import '../../shared/reader_state.dart';
import '../memorization/asr_model.dart';
import '../memorization/memorization_controller.dart';
import 'download_queue.dart';
import 'recitation_controller.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  late final DownloadQueue _queue = RecitationScope.read(context)!.downloads;

  @override
  void initState() {
    super.initState();
    _queue.ensureScanned(); // never awaited: the screen renders at once (Principle III)
    MemorizationScope.read(context)?.model.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final locale = Localizations.localeOf(context);
    final arabic = locale.languageCode == 'ar';
    final quran = ReaderScope.of(context).quran;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(MathaniIcons.back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.downloads),
      ),
      body: Column(children: [
        const _MemorizationModelRow(),
        Expanded(child: ValueListenableBuilder<bool>(
        valueListenable: _queue.scanned,
        builder: (context, scanned, _) {
          if (!scanned) return _Skeleton(reciters: quran.reciters.length);
          return ValueListenableBuilder<Map<DownloadKey, SurahDownload>>(
            valueListenable: _queue.states,
            builder: (context, states, _) {
              if (states.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.s6),
                    child: Text(
                      l10n.downloadsEmpty,
                      textAlign: TextAlign.center,
                      style: TypeScale.body.copyWith(color: colors.inkMuted),
                    ),
                  ),
                );
              }
              return ListView(
                children: [
                  for (final r in quran.reciters)
                    if (states.keys.any((k) => k.$1 == r.id)) ...[
                      _ReciterHeader(
                        name: r.name(arabic: arabic),
                        size: formatSize(l10n, locale, _queue.savedBytes(r.id)),
                        onDeleteAll: () => _confirmDeleteAll(r.id, r.name(arabic: arabic)),
                      ),
                      for (final d in (states.values.where((d) => d.reciter == r.id).toList()
                        ..sort((a, b) => a.surah.compareTo(b.surah))))
                        _DownloadRow(
                          download: d,
                          name: arabic
                              ? 'سورة ${quran.surahList[d.surah - 1].nameAr}'
                              : quran.surahList[d.surah - 1].nameTranslit,
                          number: formatNumber(d.surah, locale),
                          queue: _queue,
                        ),
                    ],
                ],
              );
            },
          );
        },
      )),
      ]),
    );
  }

  Future<void> _confirmDeleteAll(String reciter, String name) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.deleteAllConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.deleteAll),
          ),
        ],
      ),
    );
    if (ok == true) await _queue.deleteAll(reciter);
  }
}

class _ReciterHeader extends StatelessWidget {
  const _ReciterHeader({required this.name, required this.size, required this.onDeleteAll});

  final String name;
  final String size;
  final VoidCallback onDeleteAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.s4, Space.s4, Space.s2, 0),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TypeScale.titleSm.copyWith(color: colors.ink)),
            Text(size, style: TypeScale.caption.copyWith(color: colors.inkMuted)),
          ]),
        ),
        TextButton(onPressed: onDeleteAll, child: Text(l10n.deleteAll)),
      ]),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({
    required this.download,
    required this.name,
    required this.number,
    required this.queue,
  });

  final SurahDownload download;
  final String name;
  final String number;
  final DownloadQueue queue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final locale = Localizations.localeOf(context);
    final d = download;
    final size = formatSize(l10n, locale, d.state == DownloadState.complete ? d.savedBytes : d.totalBytes);

    final String status;
    Widget? progress;
    switch (d.state) {
      case DownloadState.complete:
        status = size;
      case DownloadState.downloading:
        final percent = formatNumber((d.progress * 100).round(), locale);
        status = '$size · $percent%';
        progress = LinearProgressIndicator(value: d.progress, color: colors.accent);
      case DownloadState.queued:
        status = '$size · ${l10n.waiting}';
      case DownloadState.stopped || DownloadState.absent:
        final reason = switch (d.stopReason) {
          StopReason.noConnection => ' · ${l10n.stopReasonNoConnection}',
          StopReason.noStorage => ' · ${l10n.stopReasonNoStorage}',
          StopReason.fetchFailed => ' · ${l10n.stopReasonFailed}',
          null => '',
        };
        status = '${l10n.stoppedResume}$reason';
    }

    return Dismissible(
      key: ValueKey(('download', d.reciter, d.surah)),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: colors.surfaceSunken,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s4),
            child: Icon(MathaniIcons.delete, color: colors.ink),
          ),
        ),
      ),
      onDismissed: (_) => queue.delete(d.reciter, d.surah),
      child: ListTile(
        leading: d.state == DownloadState.complete
            ? Icon(MathaniIcons.downloaded, color: colors.secondary, semanticLabel: l10n.downloaded)
            : const Icon(MathaniIcons.download),
        title: Text('$number · $name'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(status, style: TypeScale.caption.copyWith(color: colors.inkMuted)),
            ?progress,
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(MathaniIcons.more),
          tooltip: l10n.surahOptions,
          onSelected: (action) async {
            switch (action) {
              case 'resume':
                await queue.enqueue(d.reciter, d.surah);
              case 'stop':
                await queue.cancel(d.reciter, d.surah);
              case 'delete':
                await queue.delete(d.reciter, d.surah);
              case 'corrupt':
                // Debug builds only: quickstart Q-20 (a damaged file is never played).
                final dir = await queue.fetcher.downloadDir(d.reciter, d.surah);
                final file = await queue.fetcher.downloadFile(d.reciter, d.surah, 1);
                if (file.path.startsWith(dir)) await file.writeAsBytes(const [0, 0, 0]);
            }
          },
          itemBuilder: (_) => [
            if (d.state == DownloadState.stopped)
              PopupMenuItem(value: 'resume', child: Text(l10n.resume)),
            if (d.state == DownloadState.queued || d.state == DownloadState.downloading)
              PopupMenuItem(value: 'stop', child: Text(l10n.stopDownload)),
            PopupMenuItem(value: 'delete', child: Text(l10n.deleteDownload)),
            if (kDebugMode && d.state == DownloadState.complete)
              const PopupMenuItem(value: 'corrupt', child: Text('Corrupt a file (debug)')),
          ],
        ),
      ),
    );
  }
}

/// Placeholder rows while the disk scan runs (Principle III: render at once).
class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.reciters});

  final int reciters;

  @override
  Widget build(BuildContext context) {
    final colors = MathaniColors.of(context);
    Widget bar(double width) => Container(
          width: width,
          height: 12,
          margin: const EdgeInsets.symmetric(vertical: Space.s1),
          decoration: BoxDecoration(
            color: colors.surfaceSunken,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
        );
    return ListView(
      key: const ValueKey('downloads-skeleton'),
      padding: const EdgeInsets.all(Space.s4),
      children: [
        for (var i = 0; i < reciters; i++) ...[
          Row(children: [bar(140), const Spacer(), const Text('…')]),
          const SizedBox(height: Space.s2),
          for (var j = 0; j < 3; j++) Align(alignment: AlignmentDirectional.centerStart, child: bar(220)),
          const SizedBox(height: Space.s4),
        ],
      ],
    );
  }
}

/// The memorization model (specs/006 contracts/memorization-ui.md › Settings), when any of it is
/// on the device: its size, and delete. Not offered while a session exists.
class _MemorizationModelRow extends StatelessWidget {
  const _MemorizationModelRow();

  @override
  Widget build(BuildContext context) {
    final memorization = MemorizationScope.maybeOf(context);
    if (memorization == null) return const SizedBox.shrink();
    final model = memorization.model;
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final locale = Localizations.localeOf(context);
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        if (model.state == AsrModelState.absent) return const SizedBox.shrink();
        return ListTile(
          leading: const Icon(MathaniIcons.memorize),
          title: Text(l10n.memorizationModel),
          subtitle: Text(formatSize(l10n, locale, model.downloadedBytes),
              style: TypeScale.caption.copyWith(color: colors.inkMuted)),
          trailing: IconButton(
            icon: const Icon(MathaniIcons.delete),
            tooltip: l10n.deleteMemorizationModel,
            onPressed: memorization.active ? null : model.delete,
          ),
        );
      },
    );
  }
}
