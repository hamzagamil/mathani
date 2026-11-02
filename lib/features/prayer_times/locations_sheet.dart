import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import 'location_setup_sheet.dart';
import 'prayer_controller.dart';
import 'prayer_copy.dart';
import 'prayer_models.dart';

/// "My location" and saved places (Story 3). Tapping a row views it; alerts follow the current
/// place until "Use this place" (FR-010).
Future<void> showPrayerPlaces(
  BuildContext context,
  PrayerController controller,
) async {
  final add = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => PlacesSheet(controller: controller),
  );
  if (add == true && context.mounted) {
    await showPrayerSearch(context, controller);
  }
}

class PlacesSheet extends StatelessWidget {
  const PlacesSheet({super.key, required this.controller});
  final PrayerController controller;

  Future<void> _rename(BuildContext context, Place place) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(name: place.name),
    );
    if (name != null) await controller.renamePlace(place.id, name);
  }

  Future<void> _delete(BuildContext context, Place place) async {
    final l = AppLocalizations.of(context), c = controller;
    if (c.state.currentPlace?.id != place.id) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(l.prayerDeletePlace),
          content: Text(l.prayerDeleteConfirm(place.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(l.prayerCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(l.prayerDelete),
            ),
          ],
        ),
      );
      if (ok == true) await c.deletePlace(place.id);
      return;
    }
    final others = [
      ?c.state.myLocation,
      ...c.state.places,
    ].where((p) => p.id != place.id).toList();
    if (others.isEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(l.prayerDeletePlace),
          content: Text(l.prayerDeleteLastConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(l.prayerCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(l.prayerDelete),
            ),
          ],
        ),
      );
      if (ok == true) await c.deletePlace(place.id, alertsOff: true);
      return;
    }
    // The current place: pick a replacement for alerts, or turn alerts off (Story 3, scenario 4).
    final choice = await showDialog<String>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: Text(l.prayerDeleteCurrentTitle),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(l.prayerDeleteCurrentBody),
          ),
          for (final p in others)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialog, p.id),
              child: Text(l.prayerAlertsFollow(p.name)),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialog, ''),
            child: Text(l.prayerDeleteAlertsOff),
          ),
        ],
      ),
    );
    if (choice == null) return;
    await c.deletePlace(
      place.id,
      replacementId: choice.isEmpty ? null : choice,
      alertsOff: choice.isEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), c = controller;
    final language = Localizations.localeOf(context).languageCode;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .85,
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final s = c.state, my = s.myLocation;
          Widget row(Place p, {required bool isMy}) {
            final current = s.currentPlace?.id == p.id;
            return ListTile(
              key: ValueKey('place-${p.id}'),
              leading: Icon(isMy ? Icons.my_location : Icons.place_outlined),
              title: Text(isMy ? l.prayerMyLocation : p.name),
              subtitle: Text(
                [
                  if (isMy) p.name,
                  [
                    p.region,
                    p.countryCode,
                  ].where((v) => v.isNotEmpty).join(', '),
                  if (current) l.prayerCurrentPlace,
                ].where((v) => v.isNotEmpty).join(' · '),
              ),
              selected: p.id == c.viewedPlace?.id,
              onTap: () {
                c.viewPlace(p.id);
                Navigator.pop(context);
              },
              trailing: PopupMenuButton<String>(
                enabled: !c.busy,
                tooltip: l.prayerPlaceActions,
                onSelected: (action) async {
                  switch (action) {
                    case 'use':
                      await c.usePlace(p.id);
                    case 'refresh':
                      await c.useMyLocation(language);
                    case 'rename':
                      await _rename(context, p);
                    case 'delete':
                      await _delete(context, p);
                  }
                },
                itemBuilder: (_) => [
                  if (!current)
                    PopupMenuItem(
                      value: 'use',
                      child: Text(l.prayerUseThisPlace),
                    ),
                  if (isMy)
                    PopupMenuItem(
                      value: 'refresh',
                      child: Text(l.prayerRefreshLocation),
                    ),
                  if (!isMy)
                    PopupMenuItem(value: 'rename', child: Text(l.prayerRename)),
                  PopupMenuItem(value: 'delete', child: Text(l.prayerDelete)),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.prayerPlaces,
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(prayerFailureMessage(l, c.failure!)),
                  ),
                ),
              if (my != null)
                row(my, isMy: true)
              else
                ListTile(
                  leading: const Icon(Icons.my_location),
                  title: Text(l.prayerUseMyLocation),
                  onTap: c.busy ? null : () => c.useMyLocation(language),
                ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: s.places.length,
                  itemBuilder: (_, i) => row(s.places[i], isMy: false),
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
                      label: Text(l.prayerAddPlace),
                    ),
                    TextButton(
                      onPressed: c.busy
                          ? null
                          : () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (dialog) => AlertDialog(
                                  title: Text(l.prayerClearData),
                                  content: Text(l.prayerClearDataConfirm),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialog, false),
                                      child: Text(l.prayerCancel),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(dialog, true),
                                      child: Text(l.prayerClearData),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await c.deleteAllPrayerData();
                                if (context.mounted) Navigator.pop(context);
                              }
                            },
                      child: Text(l.prayerClearData),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.name});
  final String name;
  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  final form = GlobalKey<FormState>();
  late final text = TextEditingController(text: widget.name);
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
          decoration: InputDecoration(labelText: l.prayerPlaceName),
          validator: (v) => validPlaceName(v ?? '') ? null : l.prayerLabelError,
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
