import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../shared/numerals.dart';
import '../../shared/reader_state.dart';

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
