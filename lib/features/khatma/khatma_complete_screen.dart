import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../analytics/usage.dart';
import 'khatma_controller.dart';
import 'khatma_format.dart';
import 'khatma_models.dart';

/// The completion screen's answer: start a new khatma with [plan] selected.
class StartNewKhatma {
  const StartNewKhatma(this.plan);
  final KhatmaPlan? plan;
}

/// The khatma is complete (FR-034): its start date, end date and number of days, with Start a
/// new khatma (FR-036), Undo (FR-016) and Close.
class KhatmaCompleteScreen extends StatelessWidget {
  const KhatmaCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      TrackedScreen(UsageScreen.khatmaComplete, child: Builder(builder: _content));

  Widget _content(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final c = KhatmaScope.of(context);
    final f = KhatmaFormat.of(context, c.quran);
    final done = c.record.firstOrNull;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(l10n.khatmaTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.s6),
          children: [
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                l10n.khatmaComplete,
                textAlign: TextAlign.center,
                style: TypeScale.display.copyWith(color: colors.accentInk),
              ),
            ),
            const SizedBox(height: Space.s4),
            if (done != null)
              Text(
                '${l10n.khatmaDateRange(f.date(done.startDate), f.date(done.finishedOn ?? done.startDate))}'
                ' · ${f.days(done.days ?? 1)}',
                textAlign: TextAlign.center,
                style: TypeScale.body.copyWith(color: colors.ink),
              ),
            const SizedBox(height: Space.s8),
            // The plan sheet opens over the screen that showed this one.
            FilledButton(
              onPressed: () => Navigator.of(context).pop(StartNewKhatma(done?.plan)),
              child: Text(l10n.khatmaStartNew),
            ),
            const SizedBox(height: Space.s2),
            if (c.canUndo)
              OutlinedButton(
                onPressed: () async {
                  await c.undo();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Text(l10n.khatmaUndo),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.khatmaClose),
            ),
          ],
        ),
      ),
    );
  }
}
