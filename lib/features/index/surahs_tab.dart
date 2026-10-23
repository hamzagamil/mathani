import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../shared/numerals.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/reader_state.dart';
import '../recitation/download_queue.dart';
import '../recitation/recitation_controller.dart';

/// All 114 surahs in Mushaf order (FR-010). A tap opens the surah and closes the index.
class SurahsTab extends StatelessWidget {
  const SurahsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.read(context);
    final surahs = reader.quran.surahList;
    final current = reader.pageHead.surah;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final english = locale.languageCode == 'en';
    final colors = MathaniColors.of(context);
    // Recitation downloads (specs/004 US4): a mark on surahs downloaded for the chosen reciter, and
    // a menu to download, stop or delete. The list never waits for the disk scan.
    final recitation = RecitationScope.maybeOf(context);
    final queue = recitation?.downloads;
    queue?.ensureScanned();
    final reciter = reader.quran.reciterOrDefault(reader.preferences.reciter)?.id;

    return ListView.builder(
      itemCount: surahs.length,
      itemExtent: 64,
      itemBuilder: (context, i) {
        final s = surahs[i];
        final meta = '${l10n.ayahCount(s.ayahCount, formatNumber(s.ayahCount, locale))} · '
            '${s.revelation == Revelation.makki ? l10n.makki : l10n.madani} · '
            '${l10n.pageLabel(formatNumber(s.startPage, locale))}';
        return Semantics(
          button: true,
          label: l10n.surahRowSemantics(
            english ? s.nameTranslit : s.nameAr,
            formatNumber(s.ayahCount, locale),
            formatNumber(s.startPage, locale),
          ),
          excludeSemantics: true,
          child: ListTile(
            selected: s.number == current,
            trailing: queue == null || reciter == null
                ? null
                : _DownloadControls(queue: queue, reciter: reciter, surah: s.number),
            onLongPress: queue == null || reciter == null
                ? null
                : () => showSurahDownloadMenu(context, queue, reciter, s.number),
            leading: _NumberBadge(formatNumber(s.number, locale)),
            title: Text(english ? '${s.nameTranslit} · ${s.nameAr}' : 'سورة ${s.nameAr}'),
            subtitle: Text(meta, style: TypeScale.caption.copyWith(color: colors.inkMuted)),
            onTap: () {
              reader.jumpTo(AyahRef(s.number, 1), highlight: false);
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }
}

/// Small rounded badge with a number, in `accent-ink` on `surface-sunken`.
class _NumberBadge extends StatelessWidget {
  const _NumberBadge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = MathaniColors.of(context);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(text, style: TypeScale.label.copyWith(color: colors.accentInk, fontSize: 13)),
    );
  }
}

/// The downloaded mark and the "⋯" menu of a surah row (contracts/recitation-ui.md › Index ›
/// Surahs). Rebuilds only itself as downloads progress.
class _DownloadControls extends StatelessWidget {
  const _DownloadControls({required this.queue, required this.reciter, required this.surah});

  final DownloadQueue queue;
  final String reciter;
  final int surah;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    return ValueListenableBuilder<Map<DownloadKey, SurahDownload>>(
      valueListenable: queue.states,
      builder: (context, states, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (states[(reciter, surah)]?.state == DownloadState.complete)
            Icon(MathaniIcons.downloaded, size: 18, color: colors.secondary,
                semanticLabel: l10n.downloaded),
          IconButton(
            icon: const Icon(MathaniIcons.more),
            tooltip: l10n.surahOptions,
            onPressed: () => showSurahDownloadMenu(context, queue, reciter, surah),
          ),
        ],
      ),
    );
  }
}

/// Download, stop or delete the recitation of [surah] for [reciter].
Future<void> showSurahDownloadMenu(
    BuildContext context, DownloadQueue queue, String reciter, int surah) async {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context);
  final d = queue.stateOf(reciter, surah);
  final state = d?.state ?? DownloadState.absent;
  final remaining = state == DownloadState.complete ? 0 : await queue.sizeOf(reciter, surah);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == DownloadState.queued || state == DownloadState.downloading)
            ListTile(
              leading: const Icon(MathaniIcons.close),
              title: Text(l10n.stopDownload),
              subtitle: d == null || state == DownloadState.queued
                  ? Text(l10n.waiting)
                  : LinearProgressIndicator(value: d.progress),
              onTap: () {
                Navigator.of(sheetContext).pop();
                queue.cancel(reciter, surah);
              },
            )
          else if (state != DownloadState.complete)
            ListTile(
              leading: const Icon(MathaniIcons.download),
              title: Text(l10n.downloadRecitation(formatSize(l10n, locale, remaining))),
              onTap: () {
                Navigator.of(sheetContext).pop();
                startSurahDownload(context, queue, reciter, surah);
              },
            ),
          if (state == DownloadState.complete || state == DownloadState.stopped)
            ListTile(
              leading: const Icon(MathaniIcons.delete),
              title: Text(l10n.deleteDownload),
              onTap: () {
                Navigator.of(sheetContext).pop();
                queue.delete(reciter, surah);
              },
            ),
          const SizedBox(height: Space.s2),
        ],
      ),
    ),
  );
}
