import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import 'location_setup_sheet.dart';
import 'prayer_controller.dart';
import 'prayer_copy.dart';
import 'prayer_models.dart';

Future<void> showPrayerLocations(
  BuildContext context,
  PrayerController controller,
) async {
  final add = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => LocationsSheet(controller: controller),
  );
  if (add == true && context.mounted) {
    await showPrayerLocationSetup(context, controller);
  }
}

Future<bool> confirmPrayerAction(
  BuildContext context,
  String title,
  String message,
  String action,
) async {
  final l = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(l.prayerCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
}

class LocationsSheet extends StatelessWidget {
  const LocationsSheet({super.key, required this.controller});
  final PrayerController controller;

  Future<void> _rename(BuildContext context, SavedLocation place) async {
    final label = await showDialog<String>(
      context: context,
      builder: (_) => _RenameLocationDialog(label: place.label),
    );
    if (label != null) await controller.renameLocation(place.id, label);
  }

  Future<void> _delete(BuildContext context, SavedLocation place) async {
    final l = AppLocalizations.of(context);
    if (place.id != controller.state.activeLocationId) {
      if (await confirmPrayerAction(
        context,
        l.prayerDeleteLocation,
        l.prayerDeleteInactiveConfirm,
        l.prayerDelete,
      )) {
        await controller.deleteLocation(place.id);
      }
      return;
    }
    final others = controller.state.locations
        .where((p) => p.id != place.id)
        .toList();
    String? replacement;
    final action = await showDialog<String>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l.prayerDeleteLocation),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.prayerDeleteActiveConfirm),
                if (others.isNotEmpty)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l.prayerReplacementLocation,
                    ),
                    items: [
                      for (final p in others)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(p.label, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => replacement = value),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(l.prayerCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, 'disable'),
              child: Text(l.prayerDeleteAndDisable),
            ),
            if (others.isNotEmpty)
              FilledButton(
                onPressed: replacement == null
                    ? null
                    : () => Navigator.pop(dialog, 'replace'),
                child: Text(l.prayerReplaceAndDelete),
              ),
          ],
        ),
      ),
    );
    if (action != null) {
      await controller.deleteLocation(
        place.id,
        replacementId: action == 'replace' ? replacement : null,
        disableReminders: action == 'disable',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), c = controller;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .85,
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.prayerSavedLocations,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l.prayerCancel,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (c.busy) const LinearProgressIndicator(),
            if (c.failure != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(prayerFailureMessage(l, c.failure!)),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: c.state.locations.length,
                itemBuilder: (context, index) {
                  final p = c.state.locations[index],
                      active = p.id == c.state.activeLocationId;
                  return ListTile(
                    title: Text(p.label),
                    subtitle: Text(
                      [
                        p.timezoneId,
                        if (active) l.prayerActiveLocation,
                        if (p.id == c.viewedLocationId && !active)
                          l.prayerViewedLocation,
                      ].join('\n'),
                    ),
                    isThreeLine: active || p.id == c.viewedLocationId,
                    selected: p.id == c.viewedLocationId,
                    onTap: c.busy
                        ? null
                        : () {
                            c.viewLocation(p.id);
                            Navigator.pop(context);
                          },
                    trailing: PopupMenuButton<String>(
                      enabled: !c.busy,
                      tooltip: l.prayerSavedLocations,
                      onSelected: (action) async {
                        if (action == 'rename') {
                          await _rename(context, p);
                          return;
                        }
                        if (action == 'delete') {
                          await _delete(context, p);
                          return;
                        }
                        if (action == 'activate' &&
                            await confirmPrayerAction(
                              context,
                              l.prayerUseForReminders,
                              l.prayerActivateConfirm,
                              l.prayerUseForReminders,
                            )) {
                          await c.activateLocation(p.id, confirmed: true);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text(l.prayerRename),
                        ),
                        if (!active)
                          PopupMenuItem(
                            value: 'activate',
                            child: Text(l.prayerUseForReminders),
                          ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(l.prayerDeleteLocation),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: c.busy
                        ? null
                        : () => Navigator.pop(context, true),
                    icon: const Icon(Icons.add),
                    label: Text(l.prayerNewLocation),
                  ),
                  TextButton(
                    onPressed: c.busy || c.state.locations.isEmpty
                        ? null
                        : () async {
                            if (await confirmPrayerAction(
                              context,
                              l.prayerClearData,
                              l.prayerClearDataConfirm,
                              l.prayerClearData,
                            )) {
                              await c.clearPrayerData(confirmed: true);
                              if (context.mounted && c.failure == null) {
                                Navigator.pop(context);
                              }
                            }
                          },
                    child: Text(l.prayerClearData),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RenameLocationDialog extends StatefulWidget {
  const _RenameLocationDialog({required this.label});
  final String label;
  @override
  State<_RenameLocationDialog> createState() => _RenameLocationDialogState();
}

class _RenameLocationDialogState extends State<_RenameLocationDialog> {
  final form = GlobalKey<FormState>();
  late final text = TextEditingController(text: widget.label);
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.prayerRename),
      content: Form(
        key: form,
        child: TextFormField(
          controller: text,
          autofocus: true,
          maxLength: 80,
          decoration: InputDecoration(labelText: l.prayerLocationLabel),
          validator: (value) => prayerLabelError(l, value),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.prayerCancel),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, text.text.trim());
            }
          },
          child: Text(l.prayerSave),
        ),
      ],
    );
  }
}
