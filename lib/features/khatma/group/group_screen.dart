import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../shared/mathani_icons.dart';
import '../../analytics/usage.dart';
import '../khatma_controller.dart';
import '../khatma_format.dart';
import '../khatma_models.dart';
import '../khatma_screen.dart';
import 'group_client.dart';
import 'group_controller.dart';
import 'group_models.dart';
import 'group_start_sheet.dart';
import 'group_terms.dart';

/// One group khatma (contracts/group-ui.md › Group khatma): its header, the reader's parts, all
/// parts, and the actions. Read every 20 seconds while on screen (FR-054).
class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key, required this.code});
  final String code;

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> with ScreenTracking<GroupScreen> {
  @override
  UsageScreen get usageScreen => UsageScreen.groupKhatma;

  GroupController? _groups;
  bool _offline = false;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_groups != null) return;
    final groups = _groups = GroupScope.read(context);
    if (groups == null) return;
    groups.watch(widget.code);
    _refresh(first: true);
  }

  Future<void> _refresh({bool first = false}) async {
    final groups = _groups!;
    try {
      if (first) {
        await groups.open(widget.code);
      } else {
        await groups.refresh(widget.code);
      }
      if (mounted) setState(() => _offline = false);
    } on GroupFailure catch (f) {
      if (mounted) setState(() => _offline = f.kind == GroupFailureKind.offline);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _groups?.unwatch(widget.code);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final groups = GroupScope.of(context);
    final kept = groups.keptOf(widget.code);
    final gone = groups.isGone(widget.code);
    Widget body;
    if (gone) {
      body = _Message(text: l10n.groupGone, action: l10n.groupRemoveFromList, onAction: () async {
        await groups.forget(widget.code);
        if (context.mounted) Navigator.of(context).pop();
      });
    } else if (kept == null) {
      body = _loading
          ? const Center(child: CircularProgressIndicator())
          : _Message(text: l10n.groupNeedsConnection, action: l10n.groupRetry, onAction: _refresh);
    } else {
      body = _GroupBody(code: widget.code, offline: _offline, onRefresh: _refresh);
    }
    final s = kept == null ? null : groups.shown(widget.code);
    return KhatmaEventListener(
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          title: Text(s?.title ?? l10n.groupSection, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            if (s != null && !gone) ...[
              IconButton(
                icon: const Icon(MathaniIcons.share),
                tooltip: l10n.groupShare,
                onPressed: () => shareGroupKhatma(context, s),
              ),
              IconButton(
                icon: const Icon(MathaniIcons.refresh),
                tooltip: l10n.groupRefresh,
                onPressed: _refresh,
              ),
              _Menu(snapshot: s),
            ],
          ],
        ),
        body: body,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.action, required this.onAction});
  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = MathaniColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.s6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(text, textAlign: TextAlign.center, style: TypeScale.body.copyWith(color: colors.ink)),
          const SizedBox(height: Space.s3),
          FilledButton(onPressed: onAction, child: Text(action)),
        ]),
      ),
    );
  }
}

/// The khatma's menu: report, leave, and the organiser's edit and delete (FR-061, FR-062, FR-072).
class _Menu extends StatelessWidget {
  const _Menu({required this.snapshot});
  final Snapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = GroupScope.of(context);
    final s = snapshot;
    return PopupMenuButton<String>(
      tooltip: l10n.groupReport,
      onSelected: (choice) async {
        switch (choice) {
          case 'reportName':
            await _reportName(context, groups, s);
          case 'reportKhatma':
            if (await confirmKhatma(context, l10n.groupReportKhatmaConfirm, l10n.groupReport)) {
              if (!context.mounted) return;
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final ok = await runGroupAction(context, () => groups.report(s.code));
              if (ok) {
                navigator.pop();
                messenger.showSnackBar(SnackBar(content: Text(l10n.groupReportSent)));
              }
            }
          case 'leave':
            if (await confirmKhatma(context, l10n.groupLeaveConfirm, l10n.groupLeave)) {
              if (!context.mounted) return;
              final navigator = Navigator.of(context);
              if (await runGroupAction(context, () => groups.leave(s.code))) navigator.pop();
            }
          case 'edit':
            await _edit(context, groups, s);
          case 'delete':
            if (await confirmKhatma(context, l10n.groupDeleteConfirm(s.title), l10n.groupDelete)) {
              if (!context.mounted) return;
              final navigator = Navigator.of(context);
              if (await runGroupAction(context, () => groups.delete(s.code))) navigator.pop();
            }
        }
      },
      itemBuilder: (_) => [
        if (s.participants.any((p) => p.id != s.you))
          PopupMenuItem(value: 'reportName', child: Text(l10n.groupReportName)),
        PopupMenuItem(value: 'reportKhatma', child: Text(l10n.groupReportKhatma)),
        if (s.isOrganiser) ...[
          PopupMenuItem(value: 'edit', child: Text(l10n.groupEdit)),
          PopupMenuItem(value: 'delete', child: Text(l10n.groupDelete)),
        ] else if (s.you != null)
          PopupMenuItem(value: 'leave', child: Text(l10n.groupLeave)),
      ],
    );
  }

  Future<void> _reportName(BuildContext context, GroupController groups, Snapshot s) async {
    final l10n = AppLocalizations.of(context);
    final hidden = groups.keptOf(s.code)?.hidden ?? const {};
    final who = await showModalBottomSheet<Participant>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final p in s.participants)
            if (p.id != s.you && !hidden.contains(p.id))
              ListTile(title: Text(p.name), onTap: () => Navigator.of(sheet).pop(p)),
        ]),
      ),
    );
    if (who == null || !context.mounted) return;
    if (!await confirmKhatma(context, l10n.groupReportConfirm(who.name), l10n.groupReport)) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (await runGroupAction(context, () => groups.report(s.code, participant: who.id))) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.groupReportSent)));
    }
  }

  Future<void> _edit(BuildContext context, GroupController groups, Snapshot s) async {
    final result = await showDialog<({String title, String? finish})>(
      context: context,
      builder: (_) => _EditDialog(snapshot: s),
    );
    if (result == null || !context.mounted) return;
    await runGroupAction(
        context, () => groups.edit(s.code, title: result.title, finishDate: () => result.finish));
  }
}

class _GroupBody extends StatelessWidget {
  const _GroupBody({required this.code, required this.offline, required this.onRefresh});
  final String code;
  final bool offline;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final groups = GroupScope.of(context);
    final khatma = KhatmaScope.of(context);
    final kept = groups.keptOf(code)!;
    final s = groups.shown(code);
    final f = KhatmaFormat.of(context, khatma.quran);
    final today = CalendarDay.of(DateTime.now());
    final finish = CalendarDay.tryParse(s.finishDate);
    final total = s.parts.length;
    final read = s.count(PartState.read);
    final mine = s.mine;
    final header = <Widget>[
      if (offline)
        Text(l10n.groupLastUpdated(DateFormat.jm(f.locale.toLanguageTag())
                .format(DateTime.fromMillisecondsSinceEpoch(kept.seenAt))),
            style: TypeScale.caption.copyWith(color: colors.mistake)),
      if (groups.lostPart(code))
        Row(children: [
          Expanded(child: Text(l10n.groupNoLongerYours, style: TypeScale.body.copyWith(color: colors.mistake))),
          IconButton(
            icon: const Icon(MathaniIcons.close),
            tooltip: l10n.khatmaClose,
            onPressed: () => groups.dismissLostPart(code),
          ),
        ]),
      if (s.completedAt != null)
        Text(l10n.groupCompleteOn(f.date(CalendarDay.of(DateTime.fromMillisecondsSinceEpoch(s.completedAt!)))),
            style: TypeScale.titleSm.copyWith(color: colors.accentInk))
      else if (finish != null)
        Text(finish.isBefore(today) ? l10n.groupFinishPassed(f.date(finish)) : l10n.groupFinishBy(f.date(finish)),
            style: TypeScale.body.copyWith(color: colors.inkMuted)),
      Text(
        l10n.groupCounts(f.number(s.count(PartState.free)), f.number(s.count(PartState.taken)), f.number(read)),
        style: TypeScale.body.copyWith(color: colors.ink),
      ),
      const SizedBox(height: Space.s2),
      LinearProgressIndicator(
        value: total == 0 ? 0 : read / total,
        color: colors.accent,
        backgroundColor: colors.surfaceSunken,
        minHeight: 6,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
    ];
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, Space.s8),
        itemCount: 3 + mine.length + total,
        itemBuilder: (context, i) {
          if (i == 0) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: header);
          if (i == 1) {
            return mine.isEmpty
                ? const SizedBox(height: Space.s4)
                : _Heading(l10n.groupMyParts);
          }
          if (i < 2 + mine.length) return _MyPart(code: code, part: mine[i - 2]);
          if (i == 2 + mine.length) return _Heading(l10n.groupAllParts);
          return _PartRow(code: code, part: s.parts[i - 3 - mine.length]);
        },
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Space.s6, bottom: Space.s1),
        child: Semantics(
          header: true,
          child: Text(text, style: TypeScale.titleSm.copyWith(color: MathaniColors.of(context).accentInk)),
        ),
      );
}

String partName(AppLocalizations l10n, KhatmaFormat f, int division, int n) =>
    division == 30 ? l10n.juzLabel(f.number(n)) : l10n.khatmaHizb(f.number(n));

/// A part the reader holds: Read or Continue, Done, Give back, and "waiting to be sent".
class _MyPart extends StatelessWidget {
  const _MyPart({required this.code, required this.part});
  final String code;
  final GroupPart part;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final groups = GroupScope.of(context);
    final khatma = KhatmaScope.of(context);
    final f = KhatmaFormat.of(context, khatma.quran);
    final s = groups.shown(code);
    final r = groups.rangeOf(code, part.n);
    final reading = khatma.readings.where((x) => x.key == GroupController.readingKey(code, part.n)).firstOrNull;
    final pending = groups.isPending(code, part.n);
    final read = part.state == PartState.read;
    return Card(
      color: colors.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.all(Space.s3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(partName(l10n, f, s.division, part.n), style: TypeScale.titleSm.copyWith(color: colors.ink)),
          Text('${f.range(r.firstAyah, r.lastAyah)} · ${f.pageRange(r.firstPage, r.lastPage)}',
              style: TypeScale.body.copyWith(color: colors.inkMuted)),
          if (pending) Text(l10n.groupWaiting, style: TypeScale.caption.copyWith(color: colors.accentInk)),
          const SizedBox(height: Space.s2),
          Wrap(spacing: Space.s2, runSpacing: Space.s2, children: [
            if (!read && reading != null)
              FilledButton(
                onPressed: () => openReadingFrom(context, reading),
                child: Text(reading.place > reading.firstPage ? l10n.khatmaContinue : l10n.khatmaRead),
              ),
            if (!read)
              OutlinedButton(onPressed: () => groups.markRead(code, part.n), child: Text(l10n.groupDone)),
            if (read && (s.completedAt == null || s.isOrganiser))
              OutlinedButton(
                onPressed: () => runGroupAction(context, () => groups.undoRead(code, part.n)),
                child: Text(l10n.groupUndoRead),
              ),
            if (!read)
              TextButton(
                onPressed: () => runGroupAction(context, () => groups.release(code, part.n)),
                child: Text(l10n.groupGiveBack),
              ),
          ]),
        ]),
      ),
    );
  }
}

/// One part of the khatma: number, range and state; Take when free; the organiser's menu.
class _PartRow extends StatelessWidget {
  const _PartRow({required this.code, required this.part});
  final String code;
  final GroupPart part;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = GroupScope.of(context);
    final khatma = KhatmaScope.of(context);
    final f = KhatmaFormat.of(context, khatma.quran);
    final kept = groups.keptOf(code)!;
    final s = groups.shown(code);
    final r = groups.rangeOf(code, part.n);
    final holder = s.participant(part.holder);
    final hidden = holder != null && kept.hidden.contains(holder.id) && holder.id != s.you;
    final name = holder == null ? null : hidden ? l10n.groupHidden : holder.name;
    final mineToo = part.holder != null && part.holder == s.you;
    final state = switch (part.state) {
      PartState.free => l10n.groupFree,
      PartState.taken => '\u2068${name ?? ''}\u2069${mineToo ? ' (${l10n.groupYou})' : ''}',
      PartState.read => name == null ? l10n.groupRead : '\u2068$name\u2069 · ${l10n.groupRead}',
    };
    final spoken = switch (part.state) {
      PartState.free => l10n.groupFree,
      PartState.taken => l10n.groupTakenBy(name ?? ''),
      PartState.read => name == null ? l10n.groupRead : l10n.groupReadBy(name),
    };
    final title = partName(l10n, f, s.division, part.n);
    final range = f.range(r.firstAyah, r.lastAyah);
    return MergeSemantics(
      child: Semantics(
        label: l10n.groupPartSemantics(title, range, spoken),
        excludeSemantics: true,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: Text('$range\n$state', maxLines: 3, overflow: TextOverflow.ellipsis),
          isThreeLine: true,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (part.state == PartState.free && s.completedAt == null)
              FilledButton.tonal(
                onPressed: () => _take(context, groups, s),
                child: Text(l10n.groupTake),
              ),
            if (s.isOrganiser) _OrganiserPartMenu(code: code, part: part, holder: holder),
          ]),
        ),
      ),
    );
  }

  /// Terms first, then the name prompt the first time in this khatma (FR-049, FR-059).
  Future<void> _take(BuildContext context, GroupController groups, Snapshot s) async {
    if (!await ensureGroupTerms(context, groups)) return;
    if (!context.mounted) return;
    String? name;
    if (s.you == null) {
      name = await _askName(context, groups.lastName);
      if (name == null || !context.mounted) return;
    }
    await runGroupAction(context, () => groups.take(code, part.n, name: name));
  }
}

/// "Your name will be seen by everyone who has the link", the field, and Take (FR-049).
Future<String?> _askName(BuildContext context, String? last) {
  final l10n = AppLocalizations.of(context);
  return showDialog<String>(
    context: context,
    builder: (_) => TextPromptDialog(
      title: l10n.groupYourName,
      confirm: l10n.groupTake,
      initial: last ?? '',
      helper: l10n.groupNameWarning,
      maxLength: 30,
      check: (text) => quickCheck(l10n, text, 30),
    ),
  );
}

/// The organiser's menu on a part and its holder (FR-062, FR-070, FR-071).
class _OrganiserPartMenu extends StatelessWidget {
  const _OrganiserPartMenu({required this.code, required this.part, required this.holder});
  final String code;
  final GroupPart part;
  final Participant? holder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = GroupScope.of(context);
    final s = groups.shown(code);
    final h = holder;
    return PopupMenuButton<String>(
      icon: const Icon(MathaniIcons.more),
      onSelected: (choice) async {
        switch (choice) {
          case 'free':
            await runGroupAction(context, () => groups.release(code, part.n));
          case 'read':
            await runGroupAction(context, () => groups.setRead(code, part.n, true));
          case 'unread':
            await runGroupAction(context, () => groups.setRead(code, part.n, false));
          case 'give':
            final name = await _askName(context, null);
            if (name != null && context.mounted) {
              await runGroupAction(context, () => groups.assign(code, part.n, name));
            }
          case 'remove':
            if (h != null && await confirmKhatma(context, l10n.groupRemoveConfirm(h.name), l10n.groupRemoveParticipant)) {
              if (context.mounted) await runGroupAction(context, () => groups.removeParticipant(code, h.id));
            }
        }
      },
      itemBuilder: (_) => [
        if (part.state == PartState.free) PopupMenuItem(value: 'give', child: Text(l10n.groupGiveTo)),
        if (part.state == PartState.taken) ...[
          PopupMenuItem(value: 'read', child: Text(l10n.groupMarkRead)),
          PopupMenuItem(value: 'free', child: Text(l10n.groupFreeIt)),
        ],
        if (part.state == PartState.read) PopupMenuItem(value: 'unread', child: Text(l10n.groupMarkUnread)),
        if (h != null && h.id != s.organiser)
          PopupMenuItem(value: 'remove', child: Text(l10n.groupRemoveParticipant)),
      ],
    );
  }
}


/// The organiser edits the title or the finish date (FR-072). It owns its field.
class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.snapshot});
  final Snapshot snapshot;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final _title = TextEditingController(text: widget.snapshot.title);
  late String? _finish = widget.snapshot.finishDate;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.groupEdit),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _title,
          maxLength: 60,
          decoration: InputDecoration(labelText: l10n.groupTitleField, errorText: _error),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.groupFinishDate),
          subtitle: Text(_finish ?? l10n.groupNoDate),
          trailing: _finish == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: l10n.groupNoDate,
                  onPressed: () => setState(() => _finish = null),
                ),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
                context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 365)));
            if (picked != null) setState(() => _finish = CalendarDay.of(picked).toString());
          },
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.khatmaCancel)),
        FilledButton(
          onPressed: () {
            final problem = quickCheck(l10n, _title.text, 60);
            if (problem != null) return setState(() => _error = problem);
            Navigator.of(context).pop((title: _title.text.trim(), finish: _finish));
          },
          child: Text(l10n.groupSave),
        ),
      ],
    );
  }
}
