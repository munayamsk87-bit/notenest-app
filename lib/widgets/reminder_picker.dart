import 'package:flutter/material.dart';

import '../core/l10n/context_ext.dart';
import '../data/models/note.dart';

/// Result of the reminder flow: a date/time plus an optional repeat.
typedef ReminderChoice = ({DateTime when, ReminderRecurrence recurrence});

/// Guides the user through picking a date, a time and (optionally) a repeat.
Future<ReminderChoice?> pickReminder(
  BuildContext context, {
  DateTime? initial,
  ReminderRecurrence initialRecurrence = ReminderRecurrence.none,
}) async {
  final DateTime now = DateTime.now();
  final DateTime base = initial ?? now.add(const Duration(hours: 1));

  final DateTime? date = await showDatePicker(
    context: context,
    initialDate: base,
    firstDate: DateTime(now.year - 1),
    lastDate: DateTime(now.year + 5),
  );
  if (date == null || !context.mounted) return null;

  final TimeOfDay? time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(base),
  );
  if (time == null || !context.mounted) return null;

  final DateTime when =
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  final ReminderRecurrence recurrence = await _pickRecurrence(
    context,
    initialRecurrence,
  );

  return (when: when, recurrence: recurrence);
}

Future<ReminderRecurrence> _pickRecurrence(
  BuildContext context,
  ReminderRecurrence current,
) async {
  final ReminderRecurrence? choice = await showModalBottomSheet<ReminderRecurrence>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext ctx) {
      Widget tile(ReminderRecurrence value, IconData icon, String label) {
        return RadioListTile<ReminderRecurrence>(
          value: value,
          groupValue: current,
          onChanged: (ReminderRecurrence? v) => Navigator.of(ctx).pop(v),
          title: Text(label),
          secondary: Icon(icon),
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            tile(ReminderRecurrence.none, Icons.looks_one_rounded,
                ctx.t('reminderOneTime')),
            tile(ReminderRecurrence.daily, Icons.today_rounded,
                ctx.t('reminderDaily')),
            tile(ReminderRecurrence.weekly, Icons.date_range_rounded,
                ctx.t('reminderWeekly')),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
  return choice ?? current;
}
