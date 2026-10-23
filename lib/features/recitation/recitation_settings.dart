// Settings › Recitations (specs/004-ayah-recitations/contracts/recitation-ui.md).
import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/reader_state.dart';
import 'download_queue.dart';
import 'downloads_screen.dart';
import 'recitation_controller.dart';
import 'reciter_sheet.dart';

/// The Recitations section: reciter, downloads and the recent-recitations cache. Shown only when
/// the database has a recitation catalogue.
class RecitationSettings extends StatelessWidget {
  const RecitationSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    final quran = reader.quran;
    if (quran.reciters.isEmpty) return const SizedBox.shrink();
    final recitation = RecitationScope.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final reciter = quran.reciterOrDefault(reader.preferences.reciter)!;
    TextStyle caption() => TypeScale.caption.copyWith(color: colors.inkMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, 0),
          child: Text(l10n.recitations, style: TypeScale.titleSm.copyWith(color: colors.ink)),
        ),
        ListTile(
          leading: const Icon(MathaniIcons.recitation),
          title: Text(l10n.reciter),
          subtitle: Text(reciter.name(arabic: arabic), style: caption()),
          onTap: () => showReciterSheet(
            context,
            downloaded: recitation?.downloads.isComplete,
          ),
        ),
        if (recitation != null) ...[
          _DownloadsRow(queue: recitation.downloads),
          const _ClearRecentRow(),
        ],
      ],
    );
  }
}

class _DownloadsRow extends StatefulWidget {
  const _DownloadsRow({required this.queue});
  final DownloadQueue queue;

  @override
  State<_DownloadsRow> createState() => _DownloadsRowState();
}

class _DownloadsRowState extends State<_DownloadsRow> {
  @override
  void initState() {
    super.initState();
    widget.queue.ensureScanned(); // the total shows «…» until the scan finishes
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final locale = Localizations.localeOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([widget.queue.scanned, widget.queue.states]),
      builder: (context, _) => ListTile(
        leading: const Icon(MathaniIcons.download),
        title: Text(l10n.downloads),
        subtitle: Text(
          widget.queue.scanned.value ? formatSize(l10n, locale, widget.queue.savedBytes()) : '…',
          style: TypeScale.caption.copyWith(color: colors.inkMuted),
        ),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const DownloadsScreen())),
      ),
    );
  }
}

/// Clears the recent-recitations cache (FR-021). Never touches downloads (FR-034).
class _ClearRecentRow extends StatefulWidget {
  const _ClearRecentRow();

  @override
  State<_ClearRecentRow> createState() => _ClearRecentRowState();
}

class _ClearRecentRowState extends State<_ClearRecentRow> {
  int? _bytes;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final bytes = await RecitationScope.read(context)!.fetcher.cacheBytes();
    if (mounted) setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final locale = Localizations.localeOf(context);
    final bytes = _bytes;
    return ListTile(
      leading: const Icon(MathaniIcons.delete),
      title: Text(l10n.clearRecent),
      subtitle: Text(bytes == null ? '…' : formatSize(l10n, locale, bytes),
          style: TypeScale.caption.copyWith(color: colors.inkMuted)),
      enabled: bytes != null && bytes > 0,
      onTap: () async {
        final fetcher = RecitationScope.read(context)!.fetcher;
        final messenger = ScaffoldMessenger.of(context);
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            content: Text(l10n.clearRecentConfirm(formatSize(l10n, locale, bytes ?? 0))),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.clearRecent),
              ),
            ],
          ),
        );
        if (ok != true) return;
        final freed = await fetcher.clearCache();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.spaceFreed(formatSize(l10n, locale, freed)))));
        await _refresh();
      },
    );
  }
}
