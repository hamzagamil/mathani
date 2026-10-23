// The docked recitation player (specs/004-ayah-recitations/contracts/recitation-ui.md ›
// Recitation bar). Shown while a session exists, as the reader's bottom bar, so it never covers
// Quran text.
import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/numerals.dart';
import 'ayah_fetcher.dart';
import 'recitation_controller.dart';
import 'recited_item.dart';

/// Height of the bar's main row.
const barHeight = 56.0;

/// Height of the second row ("Back to recitation", or an error with Retry).
const barSecondRowHeight = 36.0;

class RecitationBar extends StatelessWidget {
  const RecitationBar({super.key, this.onChooseReciter, this.onDownload});

  /// Opens the reciter sheet (User Story 2); the chip is a plain label without it.
  final VoidCallback? onChooseReciter;

  /// Offered with the offline error for a surah that is not downloaded (User Story 4).
  final void Function(String reciter, int surah)? onDownload;

  /// The item as the bar and the lock screen name it: «سورة الملك · ١٢» / "Al-Mulk · 67:12".
  static String itemText(AppLocalizations l10n, RecitationController c, RecitedItem item,
      {required bool arabic}) {
    final surah = c.quran.surahList[item.surah - 1];
    final name = arabic ? surah.nameAr : surah.nameTranslit;
    if (item.isBasmala) return l10n.recitedBasmala(name);
    return l10n.recitedAyah(
        name, arabic ? toEasternArabic(item.ayah) : '${item.surah}:${item.ayah}');
  }

  @override
  Widget build(BuildContext context) {
    final recitation = RecitationScope.of(context);
    final s = recitation.session;
    if (s == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';

    final notice = recitation.notice;
    if (notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (recitation.takeNotice() == null || !context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(l10n.reciterNotDownloaded(notice.reciter.name(arabic: arabic))),
          ));
      });
    }

    final ended = s.status == RecitationStatus.ended;
    final playing = s.status == RecitationStatus.playing;
    final loading = s.status == RecitationStatus.loading;
    final itemText = ended ? l10n.recitationEnded : RecitationBar.itemText(l10n, recitation, s.item, arabic: arabic);

    final transport = Directionality(
      // Media controls keep the player order in both languages (brand guide).
      textDirection: TextDirection.ltr,
      child: IconTheme(
        data: IconThemeData(color: colors.ink),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(MathaniIcons.previous),
            tooltip: l10n.previousAyah,
            onPressed: ended ? null : recitation.previous,
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: loading
                ? IconButton(
                    tooltip: l10n.pauseRecitation,
                    onPressed: recitation.pause,
                    icon: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: colors.accent),
                    ),
                  )
                : IconButton(
                    icon: Icon(playing ? MathaniIcons.pause : MathaniIcons.play),
                    tooltip: playing ? l10n.pauseRecitation : l10n.playRecitation,
                    onPressed: ended ? null : (playing ? recitation.pause : recitation.resume),
                  ),
          ),
          IconButton(
            icon: const Icon(MathaniIcons.next),
            tooltip: l10n.nextAyah,
            onPressed: ended ? null : recitation.next,
          ),
        ]),
      ),
    );

    final mainRow = SizedBox(
      height: barHeight,
      child: Row(children: [
        transport,
        Expanded(
          child: InkWell(
            onTap: ended ? null : recitation.returnToRecitation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s2),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  itemText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.titleSm.copyWith(fontFamily: TypeScale.uiFamily, color: colors.ink),
                ),
              ),
            ),
          ),
        ),
        _ReciterChip(
          label: s.reciter.shortName(arabic: arabic),
          tooltip: l10n.chooseReciter,
          onTap: onChooseReciter,
        ),
        IconButton(
          icon: const Icon(MathaniIcons.close),
          color: colors.ink,
          tooltip: l10n.closePlayer,
          onPressed: recitation.stop,
        ),
      ]),
    );

    Widget? secondRow;
    if (s.status == RecitationStatus.error) {
      final offline = s.error == FetchError.offline;
      final download = onDownload;
      secondRow = Row(children: [
        Expanded(
          child: Text(
            offline ? l10n.recitationOffline : l10n.recitationFetchFailed,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypeScale.caption.copyWith(fontFamily: TypeScale.uiFamily, color: colors.inkMuted),
          ),
        ),
        TextButton(onPressed: recitation.retry, child: Text(l10n.retry)),
        if (offline && download != null)
          TextButton(
            onPressed: () => download(s.reciter.id, s.item.surah),
            child: Text(l10n.download),
          ),
      ]);
    } else if (!s.following && !ended) {
      secondRow = Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: recitation.returnToRecitation,
          icon: const Icon(MathaniIcons.back, size: 18),
          label: Text(l10n.backToRecitation),
        ),
      );
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.recitationPlayer,
      child: Material(
        color: colors.surfaceRaised,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.line))),
          child: SafeArea(
            top: false,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.bottomCenter,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                mainRow,
                if (secondRow != null)
                  SizedBox(
                    height: barSecondRowHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.s3),
                      child: secondRow,
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReciterChip extends StatelessWidget {
  const _ReciterChip({required this.label, required this.tooltip, this.onTap});

  final String label;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MathaniColors.of(context);
    final chip = Container(
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: Space.s2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s1),
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          label,
          style: TypeScale.caption.copyWith(fontFamily: TypeScale.uiFamily, color: colors.ink),
        ),
      ),
    );
    if (onTap == null) return chip;
    return Tooltip(message: tooltip, child: InkWell(onTap: onTap, child: chip));
  }
}
