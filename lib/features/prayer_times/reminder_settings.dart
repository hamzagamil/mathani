import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import '../../app/l10n/app_localizations.dart';
import 'prayer_controller.dart';
import 'prayer_copy.dart';
import 'prayer_models.dart';
import 'prayer_reminder_scheduler.dart';
import 'prayer_time_zones.dart';

Future<void> showPrayerReminders(
  BuildContext context,
  PrayerController controller,
) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).prayerReminderSettings,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: AppLocalizations.of(context).prayerCancel,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(child: ReminderSettings(controller: controller)),
          ],
        ),
      ),
    ).whenComplete(() async {
      if (controller.previewingAthan) await controller.stopAthan();
    });

/// Saved choices are visible even when the effective delivery state is blocked.
class ReminderSettings extends StatelessWidget {
  const ReminderSettings({super.key, required this.controller});
  final PrayerController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller, l = AppLocalizations.of(context);
      final preferences = c.state.reminders, status = c.reminderStatus;
      final place = c.state.activeLocation;
      final editable = c.initialized && !c.busy;
      String modeName(AthanMode mode) =>
          mode == AthanMode.full ? l.prayerAthanFull : l.prayerAthanOpening;
      String time(DateTime value) {
        final date = place == null
            ? value.toUtc()
            : tz.TZDateTime.from(value, prayerTimeZone(place.timezoneId));
        return '${DateFormat.yMd(Localizations.localeOf(context).languageCode).add_jm().format(date)} ${place?.timezoneId ?? 'UTC'}';
      }

      final fallback = status.requiredAcknowledgement;
      return Column(
        children: [
          if (c.previewingAthan)
            Padding(
              padding: const EdgeInsets.all(8),
              child: FilledButton.icon(
                onPressed: c.stopAthan,
                icon: const Icon(Icons.stop),
                label: Text(l.prayerAthanStop),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (c.busy) const LinearProgressIndicator(),
                if (place == null)
                  Text(l.prayerNoActiveLocation)
                else
                  Text(
                    '${l.prayerActiveLocation}: ${place.label}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                const SizedBox(height: 12),
                if (c.reminderTarget == PrayerReminderTarget.ios) ...[
                  Text(l.prayerIosFullLimit),
                  const SizedBox(height: 8),
                  Text(l.prayerIosSystemSoundLimit),
                ],
                if (c.reminderTarget == PrayerReminderTarget.android) ...[
                  Text(l.prayerExactAlarmLimit),
                  Text(l.prayerSystemSoundLimit),
                  if (status.events.any(
                    (event) => event.deliveryMechanism.startsWith('inexact'),
                  ))
                    Text(l.prayerApproximateDelivery),
                ],
                if (c.reminderTarget == PrayerReminderTarget.web) ...[
                  Text(l.prayerWebLimit),
                  TextButton(
                    onPressed: () => launchUrl(Uri.parse('https://mthani.app')),
                    child: Text(l.prayerMobileApps),
                  ),
                ],
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(switch (status.status) {
                    PrayerScheduleStatus.disabled => l.prayerNoReminders,
                    PrayerScheduleStatus.blocked => l.prayerRemindersBlocked,
                    PrayerScheduleStatus.partial => l.prayerRemindersPartial,
                    PrayerScheduleStatus.scheduled => l.prayerScheduledThrough(
                      time(status.scheduledThroughUtc!),
                    ),
                  }),
                ),
                if (status.failure != null)
                  Text(prayerFailureMessage(l, status.failure!)),
                if (status.appMustReopenByUtc != null)
                  Text(l.prayerReopenBy(time(status.appMustReopenByUtc!))),
                if (c.failure != null)
                  Text(prayerFailureMessage(l, c.failure!)),
                for (final prayer in dailyPrayers)
                  SwitchListTile(
                    key: ValueKey('reminder-${prayer.name}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(prayerName(l, prayer)),
                    subtitle:
                        c.reminderCapability.restrictedPrayers.contains(prayer)
                        ? Text(l.prayerNotificationsDenied)
                        : null,
                    value: preferences.enabledPrayers.contains(prayer),
                    onChanged: editable && place != null
                        ? (value) => c.setDailyReminder(prayer, value)
                        : null,
                  ),
                const Divider(),
                SwitchListTile(
                  key: const ValueKey('reminder-qiyam'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.prayerQiyam),
                  subtitle: Text(l.prayerQiyamTone),
                  value: preferences.qiyamEnabled,
                  onChanged: editable && place != null
                      ? (value) => c.setQiyamReminder(value)
                      : null,
                ),
                Text(
                  c.nextQiyam == null
                      ? l.prayerQiyamUnavailable
                      : l.prayerQiyamUpcoming(time(c.nextQiyam!)),
                ),
                Text(l.prayerQiyamExplanation),
                if (c.reminderCapability.restrictedPrayers.contains(
                  PrayerKind.qiyam,
                ))
                  Text(l.prayerNotificationsDenied),
                const Divider(),
                Text(
                  l.prayerAthanRecording,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (c.recordings.isEmpty)
                  Text(l.prayerAthanNotCleared)
                else ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey(preferences.selectedAthanId),
                    isExpanded: true,
                    initialValue: c.selectedAthan?.id,
                    decoration: InputDecoration(
                      labelText: l.prayerAthanRecording,
                    ),
                    items: [
                      for (final recording in c.recordings)
                        DropdownMenuItem(
                          value: recording.id,
                          child: Text(
                            Localizations.localeOf(context).languageCode == 'ar'
                                ? recording.titleAr
                                : recording.titleEn,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: editable
                        ? (id) {
                            if (id != null) c.selectAthan(id);
                          }
                        : null,
                  ),
                  if (c.selectedAthan != null) ...[
                    Text(
                      l.prayerRecordingCredit(
                        c.selectedAthan!.creditedRecorder,
                      ),
                    ),
                    Text(c.selectedAthan!.licenseId),
                    Text(c.selectedAthan!.changeNotice),
                    Text(
                      c.reminderAudioReadiness.fullReady
                          ? l.prayerAudioVerified
                          : l.prayerAudioAbsent,
                    ),
                    TextButton.icon(
                      onPressed:
                          editable &&
                              c.reminderAudio != null &&
                              c.reminderAudioReadiness.fullReady
                          ? () => c.previewAthan(c.selectedAthan!)
                          : null,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l.prayerAthanPreview),
                    ),
                  ],
                ],
                DropdownButtonFormField<AthanMode>(
                  key: ValueKey('mode-${preferences.requestedMode.name}'),
                  initialValue: preferences.requestedMode,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l.prayerRequestedMode(
                      modeName(preferences.requestedMode),
                    ),
                  ),
                  items: [
                    for (final mode in AthanMode.values)
                      DropdownMenuItem(
                        value: mode,
                        child: Text(modeName(mode)),
                      ),
                  ],
                  onChanged: editable
                      ? (mode) {
                          if (mode != null) c.setAthanMode(mode);
                        }
                      : null,
                ),
                if (status.effectiveMode != null)
                  Text(
                    l.prayerEffectiveMode(
                      status.events.any(
                            (event) => event.audioId == 'system_default',
                          )
                          ? l.prayerSystemSound
                          : preferences.enabledPrayers.isEmpty &&
                                preferences.qiyamEnabled
                          ? l.prayerQiyamTone
                          : modeName(status.effectiveMode!),
                    ),
                  ),
                if (fallback != null) ...[
                  Text(switch (fallback) {
                    'ios_background_full' => l.prayerIosFullLimit,
                    'android_exact_alarm' => l.prayerExactAlarmLimit,
                    'web_audio_unavailable' => l.prayerWebLimit,
                    'full_audio_unavailable' => l.prayerAudioAbsent,
                    'system_notification' => l.prayerSystemSoundDisclosure,
                    _ => l.prayerRemindersBlocked,
                  }),
                  // Unproven Android full playback is not a user-acknowledgeable gate.
                  if (fallback != 'android_background_full')
                    TextButton(
                      onPressed: editable
                          ? () => c.acknowledgeReminderFallback(fallback)
                          : null,
                      child: Text(
                        fallback == 'system_notification'
                            ? l.prayerUseSystemSound
                            : l.prayerAcceptFallback,
                      ),
                    ),
                ],
                if (![
                  'unsupported',
                  'notRequired',
                  'granted',
                  'authorized',
                ].contains(c.reminderCapability.permissionStatus))
                  OutlinedButton(
                    onPressed: editable && place != null
                        ? c.requestReminderAuthorization
                        : null,
                    child: Text(l.prayerNotificationsPermission),
                  ),
                TextButton(
                  onPressed: editable ? c.refreshReminders : null,
                  child: Text(l.prayerReconcile),
                ),
                if (c.canOpenNotificationSettings)
                  TextButton(
                    onPressed: editable
                        ? () => c.openNotificationSettings()
                        : null,
                    child: Text(l.prayerNotificationsOpenSettings),
                  ),
                if (c.canOpenNotificationSettings &&
                    c.reminderTarget == PrayerReminderTarget.android &&
                    !c.reminderCapability.exactAlarmAccess)
                  TextButton(
                    onPressed: editable
                        ? () => c.openNotificationSettings(exactAlarm: true)
                        : null,
                    child: Text(l.prayerExactAlarmAccess),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
