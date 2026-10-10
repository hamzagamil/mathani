import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../shared/numerals.dart';
import '../../shared/reader_state.dart';

/// The 30 ajza' as section headers, each followed directly by its 8 hizb quarters (240 rows,
/// no expanding), so any juz or quarter is 3 taps away: Index → Ajza' → row (FR-011, SC-004).
class AjzaTab extends StatelessWidget {
  const AjzaTab({super.key});

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.read(context);
    final divisions = reader.quran.divisionList;
    final juzs = [for (final d in divisions) if (d.kind == DivisionKind.juz) d];
    final quarters = [for (final d in divisions) if (d.kind == DivisionKind.hizbQuarter) d];
    // Flat list: juz header followed by its quarters.
    final rows = <Division>[
      for (final j in juzs) ...[j, ...quarters.where((q) => q.juzOfQuarter == j.number)],
    ];
    final currentQuarter = reader.pageHead.hizbQuarter;

    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final d = rows[i];
        void open() {
          reader.jumpTo(d.start, highlight: d.kind == DivisionKind.hizbQuarter);
          Navigator.of(context).pop();
        }

        return d.kind == DivisionKind.juz
            ? _JuzHeader(division: d, onTap: open)
            : _QuarterRow(division: d, current: d.number == currentQuarter, onTap: open);
      },
    );
  }
}

class _JuzHeader extends StatelessWidget {
  const _JuzHeader({required this.division, required this.onTap});
  final Division division;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final colors = MathaniColors.of(context);
    return Material(
      color: colors.surfaceSunken,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.juzTitle(formatNumber(division.number, locale)),
                  style: TypeScale.titleSm.copyWith(color: colors.ink),
                ),
              ),
              Text(
                l10n.pageLabel(formatNumber(division.startPage, locale)),
                style: TypeScale.caption.copyWith(color: colors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuarterRow extends StatelessWidget {
  const _QuarterRow({required this.division, required this.current, required this.onTap});
  final Division division;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final colors = MathaniColors.of(context);
    final hizb = formatNumber(division.hizb, locale);
    final label = switch ((division.number - 1) % 4) {
      0 => l10n.hizbStart(hizb),
      1 => l10n.hizbQuarter(hizb),
      2 => l10n.hizbHalf(hizb),
      _ => l10n.hizbThreeQuarters(hizb),
    };
    return ListTile(
      selected: current,
      onTap: onTap,
      title: Text(
        division.openingWords,
        textDirection: TextDirection.rtl,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TypeScale.quranCard.copyWith(color: colors.ink, fontSize: 18, height: 2.2),
      ),
      subtitle: Text(
        '$label · ${l10n.pageLabel(formatNumber(division.startPage, locale))}',
        style: TypeScale.caption.copyWith(color: colors.inkMuted),
      ),
    );
  }
}
