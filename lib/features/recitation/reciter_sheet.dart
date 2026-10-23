// Choosing the reciter (specs/004-ayah-recitations/contracts/recitation-ui.md › Reciter sheet).
import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/reader_state.dart';
import 'recitation_controller.dart';

/// Whether [reciter] has the given surah downloaded, for the sheet's marker (User Story 4).
typedef DownloadedSurah = bool Function(String reciter, int surah);

/// Shows the reciter list. Picking one saves it and, during a recitation, restarts the current
/// ayah in the new voice (FR-004). [downloaded] marks reciters whose current surah is saved.
Future<void> showReciterSheet(BuildContext context, {DownloadedSurah? downloaded}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ReciterSheet(downloaded: downloaded),
    );

class _ReciterSheet extends StatelessWidget {
  const _ReciterSheet({this.downloaded});

  final DownloadedSurah? downloaded;

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    final recitation = RecitationScope.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final current = recitation?.session?.reciter.id ?? reader.preferences.reciter;
    final surah = recitation?.session?.item.surah ?? reader.pageHead.surah;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s2),
            child: Text(l10n.chooseReciter,
                style: TypeScale.titleSm.copyWith(color: colors.accentInk)),
          ),
          for (final r in reader.quran.reciters)
            ListTile(
              selected: r.id == current,
              title: Text(r.name(arabic: arabic)),
              // The Arabic name is always shown (contract): under the English one.
              subtitle: Text(arabic ? l10n.murattal : '${r.nameAr} · ${l10n.murattal}'),
              leading: downloaded?.call(r.id, surah) ?? false
                  ? Icon(MathaniIcons.downloaded, color: colors.secondary, semanticLabel: l10n.downloaded)
                  : const SizedBox(width: 24),
              trailing: r.id == current ? Icon(MathaniIcons.check, color: colors.accentInk) : null,
              onTap: () {
                Navigator.of(context).pop();
                _choose(reader, recitation, r);
              },
            ),
          const SizedBox(height: Space.s2),
        ],
      ),
    );
  }

  static void _choose(ReaderController reader, RecitationController? recitation, Reciter r) {
    if (recitation != null) {
      recitation.setReciter(r.id);
    } else {
      reader.updatePreferences(reader.preferences.copyWith(reciter: r.id));
    }
  }
}
