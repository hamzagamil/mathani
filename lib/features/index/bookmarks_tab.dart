import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/numerals.dart';
import '../../shared/reader_state.dart';

/// Saved places, newest first (FR-015). Tap opens; swipe or the delete button removes.
class BookmarksTab extends StatelessWidget {
  const BookmarksTab({super.key});

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.read(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final english = locale.languageCode == 'en';
    final colors = MathaniColors.of(context);
    final dates = DateFormat.yMMMd(locale.toLanguageTag());

    return ListenableBuilder(
      listenable: reader.user,
      builder: (context, _) {
        final bookmarks = reader.user.bookmarks;
        if (bookmarks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(Space.s8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(MathaniIcons.bookmark, size: 48, color: colors.accentInk),
                const SizedBox(height: Space.s4),
                Text(
                  l10n.bookmarksEmpty,
                  textAlign: TextAlign.center,
                  style: TypeScale.body.copyWith(color: colors.inkMuted),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: bookmarks.length,
          itemBuilder: (context, i) {
            final b = bookmarks[i];
            final surah = reader.quran.surahList[b.ref.surah - 1];
            return Dismissible(
              key: ValueKey(b.id),
              background: ColoredBox(color: colors.rowSelected),
              onDismissed: (_) => reader.user.removeBookmark(b.id),
              child: ListTile(
                leading: Icon(MathaniIcons.bookmarked, color: colors.accentInk),
                title: Text(l10n.bookmarkTitle(
                  english ? surah.nameTranslit : surah.nameAr,
                  formatNumber(b.ref.ayah, locale),
                )),
                subtitle: Text(
                  '${l10n.pageLabel(formatNumber(b.page, locale))} · ${dates.format(b.createdAt)}',
                  style: TypeScale.caption.copyWith(color: colors.inkMuted),
                ),
                trailing: IconButton(
                  icon: const Icon(MathaniIcons.delete),
                  tooltip: l10n.deleteBookmark,
                  onPressed: () => reader.user.removeBookmark(b.id),
                ),
                onTap: () {
                  reader.jumpTo(b.ref);
                  Navigator.of(context).pop();
                },
              ),
            );
          },
        );
      },
    );
  }
}
