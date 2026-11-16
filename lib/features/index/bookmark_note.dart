import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../data/models.dart';
import '../../shared/reader_state.dart';

/// Opens the note editor for [bookmark] and saves what the reader keeps. Saving an empty note
/// removes it.
Future<void> editBookmarkNote(
    BuildContext context, ReaderController reader, Bookmark bookmark) async {
  final note = await showDialog<String>(
    context: context,
    builder: (_) => _BookmarkNoteDialog(initial: bookmark.note ?? ''),
  );
  if (note != null) await reader.user.setBookmarkNote(bookmark.id, note);
}

class _BookmarkNoteDialog extends StatefulWidget {
  const _BookmarkNoteDialog({required this.initial});
  final String initial;

  @override
  State<_BookmarkNoteDialog> createState() => _BookmarkNoteDialogState();
}

class _BookmarkNoteDialogState extends State<_BookmarkNoteDialog> {
  late final _field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.initial.isEmpty ? l10n.bookmarkNoteAdd : l10n.bookmarkNoteEdit),
      content: TextField(
        controller: _field,
        autofocus: true,
        minLines: 3,
        maxLines: 6,
        maxLength: Bookmark.maxNoteLength,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: l10n.bookmarkNoteHint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.khatmaCancel)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_field.text),
          child: Text(l10n.groupSave),
        ),
      ],
    );
  }
}
