import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../shared/mathani_icons.dart';
import 'khatma_controller.dart';
import 'khatma_reminder_platform.dart';
import 'khatma_reminders.dart';

/// The daily reminder on the Khatma screen (contracts › Screens › Reminder section): a switch and
/// the time, with one status line. On the web: one line about the phone apps (FR-042).
class ReminderSection extends StatelessWidget {
  const ReminderSection({super.key});

  @override
  Widget build(BuildContext context) {
    final reminders = KhatmaRemindersScope.maybeOf(context);
    final khatma = KhatmaScope.maybeOf(context);
    if (reminders == null || khatma == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final status = reminders.status;
    final setting = khatma.reminder;
    final caption = TypeScale.caption.copyWith(color: colors.inkMuted);

    final children = <Widget>[
      Semantics(
        header: true,
        child: Text(l10n.khatmaReminder, style: TypeScale.titleSm.copyWith(color: colors.accentInk)),
      ),
    ];
    if (status?.permission == ReminderPermission.unsupported) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: Space.s1),
        child: Text(l10n.khatmaReminderWeb, style: TypeScale.body.copyWith(color: colors.ink)),
      ));
    } else {
      final time = TimeOfDay(hour: setting.hour, minute: setting.minute);
      children.addAll([
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(MathaniIcons.reminder),
          title: Text(l10n.khatmaReminderOn),
          subtitle: Text(l10n.khatmaReminderHint),
          value: setting.on,
          onChanged: (on) => on ? reminders.turnOn() : reminders.turnOff(),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: setting.on,
          leading: const Icon(MathaniIcons.calendar),
          title: Text(l10n.khatmaReminderTime),
          trailing: Text(time.format(context)),
          onTap: () async {
            final picked = await showTimePicker(context: context, initialTime: time);
            if (picked != null) await reminders.setTime(picked.hour, picked.minute);
          },
        ),
        if (setting.on && status?.permission == ReminderPermission.denied) ...[
          Text(l10n.khatmaReminderBlocked, style: TypeScale.body.copyWith(color: colors.mistake)),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(onPressed: reminders.openSettings, child: Text(l10n.openSettings)),
          ),
        ] else if (setting.on && status?.exactAlarms == false)
          Text(l10n.khatmaReminderLate, style: caption),
      ]);
    }
    return Padding(
      padding: const EdgeInsets.only(top: Space.s6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}
