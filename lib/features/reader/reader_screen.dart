import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/numerals.dart';
import '../../shared/reader_state.dart';
import '../index/index_screen.dart';
import 'mushaf_view.dart';

/// Home screen: the Mushaf with a header showing the current surah, juz and page (FR-008).
/// Toolbar actions appear only for features that exist (FR-028).
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = MathaniColors.of(context);
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: const _ReaderHeader(),
      body: const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Space.s2),
          child: MushafView(),
        ),
      ),
    );
  }
}

class _ReaderHeader extends StatelessWidget implements PreferredSizeWidget {
  const _ReaderHeader();

  @override
  Size get preferredSize => const Size.fromHeight(Sizes.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final head = reader.pageHead;
    final surah = reader.quran.surahList[head.surah - 1];
    final locale = Localizations.localeOf(context);
    final english = locale.languageCode == 'en';
    final theme = Theme.of(context);

    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(MathaniIcons.index),
        tooltip: l10n.openIndex,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const IndexScreen()),
        ),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            english ? '${surah.nameTranslit} · ${surah.nameAr}' : 'سورة ${surah.nameAr}',
            style: theme.appBarTheme.titleTextStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Interface numbers follow the language (contracts/ui-screens.md › Direction rules).
          Text(
            '${l10n.juzLabel(formatNumber(head.juz, locale))} · '
            '${l10n.pageLabel(formatNumber(reader.page, locale))}',
            style: TypeScale.caption.copyWith(
              fontFamily: TypeScale.uiFamily,
              color: colors.inkOnBar.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
