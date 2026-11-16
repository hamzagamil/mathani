import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../platform/share.dart';
import '../khatma_format.dart';
import '../khatma_models.dart';
import 'group_client.dart';
import 'group_code.dart';
import 'group_controller.dart';
import 'group_models.dart';
import 'group_terms.dart';

/// Shares a group khatma's link with a short text that names it and Mathani (FR-045), or copies
/// it where there is no share sheet.
Future<void> shareGroupKhatma(BuildContext context, Snapshot s) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final text = l10n.groupShareText(s.title, GroupCode.linkOf(s.code));
  if (!canShareText) {
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text(l10n.groupCopied)));
    return;
  }
  await shareText(text);
}

/// Starts a group khatma (contracts/group-ui.md › Start sheet): terms first, then the title,
/// the reader's name, the division and an optional finish date. Returns the new snapshot.
Future<Snapshot?> startGroupKhatma(BuildContext context, GroupController groups) async {
  if (!await ensureGroupTerms(context, groups)) return null;
  if (!context.mounted) return null;
  final started = await showModalBottomSheet<Snapshot>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => GroupStartSheet(groups: groups),
  );
  if (started == null || !context.mounted) return started;
  // Before the first share: anyone who has the link can see the names and take parts.
  final l10n = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      content: Text(l10n.groupLinkWarning),
      actions: [
        FilledButton(onPressed: () => Navigator.of(dialog).pop(), child: Text(l10n.groupShare)),
      ],
    ),
  );
  if (context.mounted) await shareGroupKhatma(context, started);
  return started;
}

class GroupStartSheet extends StatefulWidget {
  const GroupStartSheet({super.key, required this.groups});
  final GroupController groups;

  @override
  State<GroupStartSheet> createState() => _GroupStartSheetState();
}

class _GroupStartSheetState extends State<GroupStartSheet> {
  final _title = TextEditingController();
  late final _name = TextEditingController(text: widget.groups.lastName ?? '');
  int _division = 30;
  CalendarDay? _finish;
  bool _busy = false;
  String? _titleError, _nameError, _error;

  @override
  void dispose() {
    _title.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _titleError = quickCheck(l10n, _title.text, 60);
      _nameError = quickCheck(l10n, _name.text, 30);
      _error = null;
    });
    if (_titleError != null || _nameError != null) return;
    setState(() => _busy = true);
    try {
      final s = await widget.groups.start(
        title: _title.text.trim(),
        name: _name.text.trim(),
        division: _division,
        finishDate: _finish?.toString(),
      );
      if (mounted) Navigator.of(context).pop(s);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        final text = groupFailureText(l10n, e);
        final field = e is GroupFailure ? e.problem?.field : null;
        if (field == 'title') {
          _titleError = text;
        } else if (field == 'name') {
          _nameError = text;
        } else {
          _error = text;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final f = KhatmaFormat.of(context, widget.groups.khatma.quran);
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, MediaQuery.viewInsetsOf(context).bottom + Space.s4),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.groupStart, style: TypeScale.titleLg.copyWith(color: colors.ink)),
            const SizedBox(height: Space.s3),
            TextField(
              controller: _title,
              maxLength: 60,
              decoration: InputDecoration(labelText: l10n.groupTitleField, errorText: _titleError),
            ),
            TextField(
              controller: _name,
              maxLength: 30,
              decoration: InputDecoration(
                labelText: l10n.groupYourName,
                helperText: l10n.groupNameWarning,
                helperMaxLines: 2,
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: Space.s3),
            Text(l10n.groupDivision, style: TypeScale.titleSm.copyWith(color: colors.accentInk)),
            const SizedBox(height: Space.s1),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 30, label: Text(l10n.groupThirty)),
                ButtonSegment(value: 60, label: Text(l10n.groupSixty)),
              ],
              selected: {_division},
              onSelectionChanged: (s) => setState(() => _division = s.first),
            ),
            const SizedBox(height: Space.s3),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.groupFinishDate),
              subtitle: _finish == null ? null : Text(f.date(_finish!)),
              trailing: _finish == null
                  ? null
                  : IconButton(
                      tooltip: l10n.groupNoDate,
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _finish = null),
                    ),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: now.add(const Duration(days: 7)),
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _finish = CalendarDay.of(picked));
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: Space.s2),
                child: Text(_error!, style: TypeScale.body.copyWith(color: colors.mistake)),
              ),
            const SizedBox(height: Space.s3),
            FilledButton(
              onPressed: _busy ? null : _start,
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.groupCreate),
            ),
          ],
        ),
      ),
    );
  }
}
