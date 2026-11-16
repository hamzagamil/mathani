import 'package:flutter/material.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../shared/mathani_icons.dart';
import '../khatma_controller.dart';
import '../khatma_format.dart';
import '../khatma_screen.dart';
import 'group_code.dart';
import 'group_controller.dart';
import 'group_models.dart';
import 'group_screen.dart';
import 'group_terms.dart';
import 'group_start_sheet.dart';

/// Opens the screen of the group khatma [code].
Future<void> openGroupKhatma(BuildContext context, String code) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => GroupScreen(code: code)));

/// Group khatmas on the Khatma screen (contracts/group-ui.md › Khatma screen › Group khatmas):
/// each kept one with its progress and the reader's unread parts, Start, and Open a link or
/// code. Shown from the device's copies at once, then refreshed (FR-057).
class GroupSection extends StatefulWidget {
  const GroupSection({super.key});

  @override
  State<GroupSection> createState() => _GroupSectionState();
}

class _GroupSectionState extends State<GroupSection> {
  bool _refreshed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final groups = GroupScope.read(context);
    if (groups == null || _refreshed) return;
    _refreshed = true;
    // One read for each kept khatma when the Khatma screen opens; none when there is none.
    groups.load().then((_) {
      if (groups.kept.isNotEmpty) groups.refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = GroupScope.maybeOf(context);
    final khatma = KhatmaScope.maybeOf(context);
    if (groups == null || khatma == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final f = KhatmaFormat.of(context, khatma.quran);
    return Padding(
      padding: const EdgeInsets.only(top: Space.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.groupSection, style: TypeScale.titleSm.copyWith(color: colors.accentInk)),
          ),
          for (final k in groups.kept) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(MathaniIcons.group),
              title: Text(k.snapshot.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(groups.isGone(k.code)
                  ? l10n.groupGone
                  : l10n.groupProgress(f.number(groups.shown(k.code).count(PartState.read)),
                      f.number(k.snapshot.division))),
              onTap: () => openGroupKhatma(context, k.code),
            ),
            for (final r in khatma.readings.where((r) => r.key.startsWith('group:${k.code}:')))
              Padding(
                padding: const EdgeInsetsDirectional.only(start: Space.s8),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      '${partName(l10n, f, k.snapshot.division, r.partNumber!)} · '
                      '${f.pageRange(r.firstPage, r.lastPage)}',
                      style: TypeScale.body.copyWith(color: colors.ink),
                    ),
                  ),
                  TextButton(
                    onPressed: () => openReadingFrom(context, r),
                    child: Text(r.place > r.firstPage ? l10n.khatmaContinue : l10n.khatmaRead),
                  ),
                ]),
              ),
          ],
          const SizedBox(height: Space.s2),
          Wrap(spacing: Space.s2, runSpacing: Space.s2, children: [
            OutlinedButton.icon(
              icon: const Icon(MathaniIcons.group),
              label: Text(l10n.groupStart),
              onPressed: () async {
                final s = await startGroupKhatma(context, groups);
                if (s != null && context.mounted) await openGroupKhatma(context, s.code);
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(MathaniIcons.link),
              label: Text(l10n.groupOpenLink),
              onPressed: () => _openLink(context),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _openLink(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final text = await showDialog<String>(
      context: context,
      builder: (_) => TextPromptDialog(
        title: l10n.groupOpenLink,
        confirm: l10n.groupOpen,
        hint: l10n.groupCodeHint,
        check: (text) => GroupCode.parse(text) == null ? l10n.groupCodeInvalid : null,
      ),
    );
    final code = text == null ? null : GroupCode.parse(text);
    if (code != null && context.mounted) await openGroupKhatma(context, code);
  }
}
