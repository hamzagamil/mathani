import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../shared/mathani_icons.dart';
import '../analytics/usage.dart';
import 'khatma_controller.dart';
import 'khatma_format.dart';

/// Every wird of the khatma (FR-033): its range, pages, and whether and when it was read. Built
/// lazily, so 604 rows scroll smoothly (SC-008). A tap opens the wird's first page and does not
/// move the khatma place.
class WirdListScreen extends StatelessWidget {
  const WirdListScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      TrackedScreen(UsageScreen.wirdList, child: Builder(builder: _content));

  Widget _content(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final c = KhatmaScope.of(context);
    final f = KhatmaFormat.of(context, c.quran);
    final wirds = c.wirds;
    final current = c.currentWird?.number;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: Text(l10n.khatmaAllWirds)),
      body: ListView.builder(
        itemCount: wirds.length,
        itemExtent: 88,
        itemBuilder: (context, i) {
          final w = wirds[i];
          final isCurrent = w.number == current;
          final status = w.readOn != null
              ? l10n.khatmaReadOn(f.date(w.readOn!))
              : isCurrent
                  ? l10n.khatmaCurrent
                  : l10n.khatmaNotRead;
          return ListTile(
            selected: isCurrent,
            selectedTileColor: colors.rowSelected,
            leading: Icon(
              w.isRead ? MathaniIcons.downloaded : MathaniIcons.circle,
              color: w.isRead ? colors.accentInk : colors.inkMuted,
            ),
            title: Text(
              '${f.name(c.nameOf(w))} · ${f.range(w.firstAyah, w.lastAyah)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${f.pageRange(c.firstPageOf(w), c.lastPageOf(w))} · ${f.pages(c.pagesOf(w))} · $status',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              c.openWird(w);
            },
          );
        },
      ),
    );
  }
}
