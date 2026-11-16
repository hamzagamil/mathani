import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/numerals.dart';
import 'khatma_controller.dart';
import 'khatma_models.dart';

/// The pages on the reading screen: one page, or the two facing pages of specs/012.
typedef PagesOnScreen = (int first, int last);

/// " · {n} pages left" for the reader header's second line while the page on screen is inside a
/// reading (FR-011); empty otherwise.
String pagesLeftSuffix(BuildContext context, int firstOnScreen) {
  final left = KhatmaScope.maybeOf(context)?.pagesLeft(firstOnScreen);
  if (left == null) return '';
  final l10n = AppLocalizations.of(context);
  return ' · ${l10n.khatmaPagesLeft(left, formatNumber(left, Localizations.localeOf(context)))}';
}

/// One row for each reading whose last page is on screen: what ends here, and Done (FR-012). Two
/// readings ending on the same page give two named rows. Nothing during memorization.
class ReaderKhatmaRows extends StatelessWidget {
  const ReaderKhatmaRows({super.key, required this.pages});

  final PagesOnScreen pages;

  /// Whether any row shows for [pages].
  static bool showsFor(BuildContext context, PagesOnScreen pages) =>
      KhatmaScope.maybeOf(context)?.readingsEndingOn(pages.$1, pages.$2).isNotEmpty ?? false;

  @override
  Widget build(BuildContext context) {
    final khatma = KhatmaScope.maybeOf(context);
    final readings = khatma?.readingsEndingOn(pages.$1, pages.$2) ?? const <Reading>[];
    if (khatma == null || readings.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    return Material(
      color: colors.surfaceRaised,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in readings)
            DecoratedBox(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.line))),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(Space.s4, Space.s1, Space.s2, Space.s1),
                child: Row(
                  children: [
                    Icon(MathaniIcons.wirdEnd, size: 18, color: colors.khatmaMark),
                    const SizedBox(width: Space.s2),
                    Expanded(
                      child: Text(
                        r.kind == ReadingKind.wird
                            ? l10n.khatmaEndsHere
                            : l10n.khatmaPartEndsHere(r.title ?? ''),
                        style: TypeScale.body.copyWith(color: colors.ink),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => khatma.markReadingRead(r),
                      child: Text(l10n.khatmaDone),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
