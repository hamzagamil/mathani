import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/reader_state.dart';
import 'khatma_complete_screen.dart';
import 'khatma_controller.dart';
import 'khatma_format.dart';
import 'khatma_models.dart';
import 'group/group_section.dart';
import 'khatma_repository.dart';
import 'plan_sheet.dart';
import 'reminder_section.dart';
import 'wird_list_screen.dart';

/// The Khatma screen (contracts/khatma-ui-and-reminders.md › Screens): the personal khatma, the
/// reminder, group khatmas and the record. One tap from the reading toolbar (FR-009).
class KhatmaScreen extends StatelessWidget {
  const KhatmaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final khatma = KhatmaScope.of(context);
    return KhatmaEventListener(
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(title: Text(l10n.khatmaTitle)),
        body: !khatma.loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, Space.s8),
                children: [
                  if (khatma.khatma == null)
                    const _NoKhatma()
                  else ...[
                    const _WirdCard(),
                    const SizedBox(height: Space.s4),
                    const _Progress(),
                    const SizedBox(height: Space.s2),
                    const _Actions(),
                  ],
                  const ReminderSection(),
                  const GroupSection(),
                  if (khatma.record.isNotEmpty) ...[
                    const SizedBox(height: Space.s6),
                    const _Record(),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Starts a khatma through the plan sheet, with [initial] selected (FR-036).
Future<void> startKhatma(BuildContext context, {KhatmaPlan? initial}) async {
  final controller = KhatmaScope.read(context)!;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  if (controller.khatma != null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.khatmaAlreadyInProgress)));
    return;
  }
  final reader = ReaderScope.maybeOf(context);
  final choice = await showPlanSheet(context,
      controller: controller, initial: initial, currentPage: reader?.page);
  if (choice == null) return;
  try {
    await controller.start(choice.plan, startAyah: choice.startAyah, startDate: choice.startDate);
  } on KhatmaInProgress {
    messenger.showSnackBar(SnackBar(content: Text(l10n.khatmaAlreadyInProgress)));
  }
}

/// Pops back to the reading screen and opens [r] at its place (FR-008).
void openReadingFrom(BuildContext context, Reading r) {
  final controller = KhatmaScope.read(context)!;
  Navigator.of(context).popUntil((route) => route.isFirst);
  controller.openReading(r);
}

/// Shows "Today's wird is done" with Undo, or the completion screen, on the screen that is in
/// front when a wird is marked as read (FR-016, FR-034).
class KhatmaEventListener extends StatefulWidget {
  const KhatmaEventListener({super.key, required this.child});
  final Widget child;

  @override
  State<KhatmaEventListener> createState() => _KhatmaEventListenerState();
}

class _KhatmaEventListenerState extends State<KhatmaEventListener> {
  KhatmaController? _controller;
  int _handled = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = KhatmaScope.read(context);
    if (c == _controller) return;
    _controller?.events.removeListener(_onEvent);
    _controller = c?..events.addListener(_onEvent);
    _handled = c?.events.value?.serial ?? 0;
  }

  @override
  void dispose() {
    _controller?.events.removeListener(_onEvent);
    super.dispose();
  }

  void _onEvent() {
    final c = _controller;
    final e = c?.events.value;
    if (c == null || e == null || e.serial == _handled || !mounted) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    _handled = e.serial;
    if (e.kind == KhatmaEventKind.finished) {
      Navigator.of(context)
          .push(MaterialPageRoute<StartNewKhatma>(builder: (_) => const KhatmaCompleteScreen()))
          .then((answer) {
        if (answer != null && mounted) startKhatma(context, initial: answer.plan);
      });
      return;
    }
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.khatmaTodayDone),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(label: l10n.khatmaUndo, onPressed: c.undo),
      ));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _NoKhatma extends StatelessWidget {
  const _NoKhatma();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final record = KhatmaScope.of(context).record;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.khatmaIntro, style: TypeScale.body.copyWith(color: colors.ink)),
        const SizedBox(height: Space.s4),
        FilledButton(
          onPressed: () =>
              startKhatma(context, initial: record.isEmpty ? null : record.first.plan),
          child: Text(record.isEmpty ? l10n.khatmaStart : l10n.khatmaStartNew),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = MathaniColors.of(context);
    return Material(
      color: colors.surfaceRaised,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Padding(
        padding: const EdgeInsets.all(Space.s4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }
}

/// The current wird: where it starts and ends, its pages, Read or Continue, and Done (FR-007).
class _WirdCard extends StatelessWidget {
  const _WirdCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final c = KhatmaScope.of(context);
    final k = c.khatma!;
    final f = KhatmaFormat.of(context, c.quran);
    final w = c.currentWird;
    final status = c.isPaused && k.pausedOn != null
        ? l10n.khatmaPausedSince(f.date(k.pausedOn!))
        : c.notStarted
            ? l10n.khatmaStartsOn(f.date(k.startDate))
            : null;
    final reading = c.readings.where((r) => r.kind == ReadingKind.wird).firstOrNull;
    final begun = w != null && k.placePage > c.firstPageOf(w);
    return _Card(children: [
      if (status != null) ...[
        Text(status, style: TypeScale.body.copyWith(color: colors.inkMuted)),
        const SizedBox(height: Space.s2),
      ],
      if (c.todayRead) ...[
        Semantics(
          liveRegion: true,
          child: Text(l10n.khatmaTodayDone,
              style: TypeScale.titleSm.copyWith(color: colors.accentInk)),
        ),
        const SizedBox(height: Space.s2),
      ] else
        Semantics(
          header: true,
          child: Text(l10n.khatmaTodaysWird,
              style: TypeScale.titleSm.copyWith(color: colors.accentInk)),
        ),
      if (w != null) ...[
        Text(
          c.todayRead
              ? l10n.khatmaNext(f.name(c.nameOf(w)))
              : '${f.name(c.nameOf(w))} · ${l10n.khatmaWirdOf(f.number(w.number), f.number(c.wirds.length))}',
          style: TypeScale.titleLg.copyWith(color: colors.ink),
        ),
        const SizedBox(height: Space.s1),
        Text(f.range(w.firstAyah, w.lastAyah), style: TypeScale.body.copyWith(color: colors.ink)),
        Text(
          '${f.pageRange(c.firstPageOf(w), c.lastPageOf(w))} · ${f.pages(c.pagesOf(w))}',
          style: TypeScale.body.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: Space.s3),
        Wrap(
          spacing: Space.s2,
          runSpacing: Space.s2,
          children: [
            if (reading != null)
              FilledButton(
                onPressed: () => openReadingFrom(context, reading),
                child: Text(c.todayRead
                    ? l10n.khatmaReadNow
                    : begun
                        ? l10n.khatmaContinue
                        : l10n.khatmaRead),
              ),
            if (c.isPaused)
              FilledButton(onPressed: c.resume, child: Text(l10n.khatmaResume)),
            OutlinedButton(onPressed: c.markRead, child: Text(l10n.khatmaDone)),
          ],
        ),
      ],
    ]);
  }
}

/// Wirds and pages read, the percentage and the dates (FR-027). Dates and amounts only (FR-029).
class _Progress extends StatelessWidget {
  const _Progress();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final c = KhatmaScope.of(context);
    final k = c.khatma!;
    final f = KhatmaFormat.of(context, c.quran);
    final total = c.pagesTotal;
    final read = c.pagesRead;
    final share = total == 0 ? 0.0 : read / total;
    final expected = c.expectedFinishDate;
    final late = expected == null ? 0 : expected.daysSince(k.plannedFinish);
    final style = TypeScale.body.copyWith(color: colors.ink);
    return _Card(children: [
      Text(l10n.khatmaProgressWirds(f.number(c.wirdsRead), f.number(c.wirds.length)),
          style: style),
      Text(l10n.khatmaProgressPages(f.number(read), f.number(total - read)), style: style),
      const SizedBox(height: Space.s2),
      Semantics(
        label: l10n.khatmaPercent(
            NumberFormat.percentPattern(f.locale.toLanguageTag()).format(share)),
        child: ExcludeSemantics(
          child: Row(children: [
            Expanded(
              child: LinearProgressIndicator(
                value: share,
                color: colors.accent,
                backgroundColor: colors.surfaceSunken,
                minHeight: 6,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
            const SizedBox(width: Space.s2),
            Text(NumberFormat.percentPattern(f.locale.toLanguageTag()).format(share),
                style: TypeScale.caption.copyWith(color: colors.inkMuted)),
          ]),
        ),
      ),
      const SizedBox(height: Space.s2),
      Text(l10n.khatmaStarted(f.date(k.startDate)), style: style),
      Text(l10n.khatmaPlannedFinish(f.date(k.plannedFinish)), style: style),
      if (expected != null && late != 0 && !c.isPaused)
        Text(
          late > 0
              ? l10n.khatmaExpectedLate(f.date(expected), f.days(late))
              : l10n.khatmaExpectedEarly(f.date(expected), f.days(-late)),
          style: style,
        ),
    ]);
  }
}

class _Actions extends StatelessWidget {
  const _Actions();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = KhatmaScope.of(context);
    return Column(children: [
      ListTile(
        leading: const Icon(MathaniIcons.wirdList),
        title: Text(l10n.khatmaAllWirds),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const WirdListScreen())),
      ),
      if (c.currentWird != null)
        ListTile(
          leading: const Icon(MathaniIcons.changePlan),
          title: Text(l10n.khatmaChangePlan),
          onTap: () async {
            final choice =
                await showPlanSheet(context, controller: c, initial: c.khatma!.plan, changing: true);
            if (choice != null) await c.changePlan(choice.plan);
          },
        ),
      ListTile(
        leading: Icon(c.isPaused ? MathaniIcons.resumeKhatma : MathaniIcons.pauseKhatma),
        title: Text(c.isPaused ? l10n.khatmaResume : l10n.khatmaPause),
        onTap: c.isPaused ? c.resume : c.pause,
      ),
      ListTile(
        leading: const Icon(MathaniIcons.endSession),
        title: Text(l10n.khatmaEnd),
        onTap: () async {
          final ok = await confirmKhatma(context, l10n.khatmaEndConfirm, l10n.khatmaEnd);
          if (ok) await c.end();
        },
      ),
    ]);
  }
}

/// A confirmation dialog; true when the reader confirms with [action].
Future<bool> confirmKhatma(BuildContext context, String message, String action) async {
  final l10n = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.khatmaCancel)),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(action)),
      ],
    ),
  );
  return ok ?? false;
}

/// Finished khatmas, newest first, with how many there are (FR-035 to FR-037).
class _Record extends StatelessWidget {
  const _Record();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final c = KhatmaScope.of(context);
    final f = KhatmaFormat.of(context, c.quran);
    final record = c.record;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.khatmaRecordTitle,
              style: TypeScale.titleSm.copyWith(color: colors.accentInk)),
        ),
        Text(l10n.khatmaRecordCount(record.length, f.number(record.length)),
            style: TypeScale.body.copyWith(color: colors.inkMuted)),
        for (final k in record)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(f.plan(k.plan)),
            subtitle: Text([
              l10n.khatmaDateRange(f.date(k.startDate), f.date(k.finishedOn ?? k.startDate)),
              f.days(k.days ?? 1),
            ].join(' · ')),
            trailing: IconButton(
              icon: const Icon(MathaniIcons.delete),
              tooltip: l10n.khatmaDeleteRecord,
              onPressed: () async {
                final ok = await confirmKhatma(
                    context, l10n.khatmaDeleteRecordConfirm, l10n.khatmaDeleteRecord);
                if (ok) await c.deleteRecord(k.id);
              },
            ),
          ),
      ],
    );
  }
}
