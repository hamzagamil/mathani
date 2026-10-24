import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/numerals.dart';
import '../../shared/reader_state.dart';
import '../memorization/memorization_controller.dart';
import '../memorization/range_sheet.dart';
import '../recitation/recitation_controller.dart';

/// Text for copying or sharing an ayah, exactly as in contracts/ui-screens.md (FR-021):
///
///     ﴿<Uthmani text without the ayah-end marker>﴾
///     سورة <name_ar>: <ayah in Eastern Arabic numerals>      (Arabic interface)
///     Surah <name_translit> <surah>:<ayah>                    (English interface)
String formatAyahForShare(List<Word> words, Surah surah, int ayah, {required bool arabic}) {
  final text = [for (final w in words) if (!w.isAyahEnd) w.text].join(' ');
  final reference = arabic
      ? 'سورة ${surah.nameAr}: ${toEasternArabic(ayah)}'
      : 'Surah ${surah.nameTranslit} ${surah.number}:$ayah';
  return '﴿$text﴾\n$reference';
}

/// Long-press actions for an ayah: play from it (specs/004), memorize from it (specs/006), copy,
/// share and bookmark (FR-020). The ayah stays
/// highlighted while the sheet is open.
Future<void> showAyahActions(BuildContext context, AyahRef ref) async {
  final reader = ReaderScope.read(context);
  reader.select(ref);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _AyahActionsSheet(ayah: ref, screen: context),
  );
  reader.select(null);
}

class _AyahActionsSheet extends StatelessWidget {
  const _AyahActionsSheet({required this.ayah, required this.screen});
  final AyahRef ayah;

  /// The reading screen, which outlives this sheet.
  final BuildContext screen;

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.read(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final arabic = locale.languageCode == 'ar';
    final surah = reader.quran.surahList[ayah.surah - 1];
    final colors = MathaniColors.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final recitation = RecitationScope.read(context);
    final memorization = MemorizationScope.read(context);

    Future<String> text() async => formatAyahForShare(
          await reader.quran.wordsOf(ayah),
          surah,
          ayah.ayah,
          arabic: arabic,
        );

    void done(String message) {
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s2),
            child: Text(
              l10n.bookmarkTitle(arabic ? surah.nameAr : surah.nameTranslit,
                  formatNumber(ayah.ayah, locale)),
              style: TypeScale.titleSm.copyWith(color: colors.accentInk),
            ),
          ),
          if (recitation != null)
            ListTile(
              leading: const Icon(MathaniIcons.play),
              title: Text(l10n.playFromAyah),
              onTap: () {
                Navigator.of(context).pop();
                recitation.playFrom(ayah);
              },
            ),
          if (memorization != null && !memorization.active)
            ListTile(
              leading: const Icon(MathaniIcons.memorize),
              title: Text(l10n.memorizeFromAyah),
              onTap: () {
                Navigator.of(context).pop();
                showMemorizeSheet(screen, from: ayah);
              },
            ),
          ListTile(
            leading: const Icon(MathaniIcons.copy),
            title: Text(l10n.copyAyah),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: await text()));
              done(l10n.ayahCopied);
            },
          ),
          ListTile(
            leading: const Icon(MathaniIcons.share),
            title: Text(l10n.shareAyah),
            onTap: () async {
              final t = await text();
              if (context.mounted) Navigator.of(context).pop();
              await SharePlus.instance.share(ShareParams(text: t));
            },
          ),
          ListTile(
            leading: const Icon(MathaniIcons.bookmark),
            title: Text(l10n.bookmarkAyah),
            onTap: () async {
              await reader.user.addBookmark(ayah, reader.quran.pageOf(ayah));
              done(l10n.bookmarkAdded);
            },
          ),
          const SizedBox(height: Space.s2),
        ],
      ),
    );
  }
}
