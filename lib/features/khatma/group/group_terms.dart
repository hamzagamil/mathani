import 'package:flutter/material.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import 'group_client.dart';
import 'group_controller.dart';

/// The address at which to reach Mathani (FR-068), shown in About and in the terms. The owner
/// chooses it before release B (research R26 step 5); mail to any @mthani.app address reaches
/// the owner through Email Routing.
const mathaniContact = 'support@mthani.app';

/// Shows the terms before the first start or take on this device, and records "I agree"
/// (FR-059). True when the reader may go on.
Future<bool> ensureGroupTerms(BuildContext context, GroupController groups) async {
  if (groups.termsAccepted) return true;
  final agreed = await showDialog<bool>(
    context: context,
    builder: (context) => const GroupTermsDialog(),
  );
  if (agreed != true) return false;
  await groups.acceptTerms();
  return true;
}

class GroupTermsDialog extends StatelessWidget {
  const GroupTermsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    Widget point(String text) => Padding(
          padding: const EdgeInsets.only(bottom: Space.s2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('•  ', style: TypeScale.body.copyWith(color: colors.accentInk)),
            Expanded(child: Text(text, style: TypeScale.body.copyWith(color: colors.ink))),
          ]),
        );
    return AlertDialog(
      title: Text(l10n.groupTermsTitle),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          point(l10n.groupTerms1),
          point(l10n.groupTerms2),
          point(l10n.groupTerms3),
          point(l10n.groupTerms4(mathaniContact)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.khatmaCancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.groupAgree)),
      ],
    );
  }
}

/// One line for a failed group action (contracts/group-ui.md › User-visible states).
String groupFailureText(AppLocalizations l10n, Object error) {
  if (error is! GroupFailure) return l10n.groupError;
  return switch (error.kind) {
    GroupFailureKind.offline => l10n.groupNeedsConnection,
    GroupFailureKind.taken => l10n.groupJustTaken,
    GroupFailureKind.notYours => l10n.groupNoLongerYours,
    GroupFailureKind.gone => l10n.groupGone,
    GroupFailureKind.blocked => l10n.groupBlocked(mathaniContact),
    GroupFailureKind.terms => l10n.groupUpdateNeeded,
    GroupFailureKind.limit => switch (error.which) {
        'organised' => l10n.groupLimitOrganised,
        'started' => l10n.groupLimitStarted,
        'busy' => l10n.groupLimitBusy,
        _ => l10n.groupLimitReports,
      },
    GroupFailureKind.invalid => problemText(l10n, error.problem?.kind),
    _ => l10n.groupError,
  };
}

String problemText(AppLocalizations l10n, String? kind) => switch (kind) {
      'empty' => l10n.groupProblemEmpty,
      'long' => l10n.groupProblemLong,
      'characters' => l10n.groupProblemCharacters,
      'link' => l10n.groupProblemLink,
      'word' => l10n.groupProblemWord,
      _ => l10n.groupError,
    };

/// The same quick checks the server makes on length and links, for an answer before sending
/// (research R19). Null when the text may be sent.
String? quickCheck(AppLocalizations l10n, String text, int max) {
  final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty) return l10n.groupProblemEmpty;
  if (t.runes.length > max) return l10n.groupProblemLong;
  if (RegExp(r'://|www\.|@|\p{L}\.\p{L}{2,}', unicode: true, caseSensitive: false).hasMatch(t)) {
    return l10n.groupProblemLink;
  }
  return null;
}

/// Runs a group action and shows its failure as one line (FR-053, FR-067).
Future<bool> runGroupAction(BuildContext context, Future<void> Function() action) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  try {
    await action();
    return true;
  } on Object catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(groupFailureText(l10n, e))));
    return false;
  }
}

/// A dialog with one text field that owns its controller, so the field outlives the closing
/// animation. Returns the trimmed text, or null.
class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.title,
    required this.confirm,
    this.initial = '',
    this.hint,
    this.helper,
    this.maxLength,
    required this.check,
  });

  final String title;
  final String confirm;
  final String initial;
  final String? hint;
  final String? helper;
  final int? maxLength;

  /// The error for [text], or null when it may be returned.
  final String? Function(String text) check;

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final _field = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    final error = widget.check(_field.text);
    if (error != null) return setState(() => _error = error);
    Navigator.of(context).pop(_field.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _field,
        autofocus: true,
        maxLength: widget.maxLength,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: widget.hint,
          helperText: widget.helper,
          helperMaxLines: 3,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.khatmaCancel)),
        FilledButton(onPressed: _submit, child: Text(widget.confirm)),
      ],
    );
  }
}
