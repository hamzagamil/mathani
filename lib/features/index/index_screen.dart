import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../shared/mathani_icons.dart';
import 'ajza_tab.dart';
import 'goto_sheet.dart';
import 'surahs_tab.dart';

/// A tab of the index: a label and the page it shows.
typedef IndexTab = ({String label, Widget body});

/// Index with brand chip tabs (Surahs · Ajza', plus Bookmarks once built) and a go-to action.
class IndexScreen extends StatefulWidget {
  const IndexScreen({super.key, this.extraTabs = const []});

  /// Tabs added by later features (Bookmarks, FR-009).
  final List<IndexTab Function(BuildContext)> extraTabs;

  @override
  State<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends State<IndexScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final tabs = <IndexTab>[
      (label: l10n.tabSurahs, body: const SurahsTab()),
      (label: l10n.tabAjza, body: const AjzaTab()),
      for (final t in widget.extraTabs) t(context),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(MathaniIcons.back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.indexTitle),
        actions: [
          IconButton(
            icon: const Icon(MathaniIcons.goTo),
            tooltip: l10n.goTo,
            onPressed: () async {
              final went = await showGoToSheet(context);
              if (went == true && context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Brand ChipTabs: a pill track on surface-sunken under the app bar.
          Padding(
            padding: const EdgeInsets.all(Space.s3),
            child: Container(
              padding: const EdgeInsets.all(Space.s1),
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Expanded(
                      child: Semantics(
                        selected: i == _tab,
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(Radii.pill),
                          onTap: () => setState(() => _tab = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            constraints: BoxConstraints(minHeight: minTouchTarget - Space.s2),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: i == _tab ? colors.selected : null,
                              borderRadius: BorderRadius.circular(Radii.pill),
                            ),
                            child: Text(
                              tabs[i].label,
                              style: TypeScale.titleSm.copyWith(
                                fontSize: 14,
                                color: i == _tab ? colors.ink : colors.inkMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: tabs[_tab].body),
        ],
      ),
    );
  }
}
