import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/enums.dart';
import '../core/l10n/context_ext.dart';
import '../core/utils/date_utils.dart';
import '../data/models/note.dart';
import '../providers/notes_provider.dart';
import '../widgets/empty_state.dart';

/// Upcoming reminders, sorted by time (Spec §6, §13 screen 11).
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  Future<void> _open(BuildContext context, Note note) async {
    switch (note.type) {
      case NoteType.checklist:
        await Navigator.of(context).pushNamed('/checklist', arguments: note.id);
        break;
      case NoteType.image:
        await Navigator.of(context).pushNamed('/image', arguments: note.id);
        break;
      case NoteType.voice:
        await Navigator.of(context).pushNamed('/voice', arguments: note.id);
        break;
      case NoteType.drawing:
        await Navigator.of(context).pushNamed('/drawing', arguments: note.id);
        break;
      case NoteType.text:
      case NoteType.link:
        await Navigator.of(context).pushNamed('/note', arguments: note.id);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final NotesProvider notes = context.watch<NotesProvider>();
    final List<Note> reminders = notes.upcomingReminders;

    return Scaffold(
      appBar: AppBar(title: Text(context.t('reminders'))),
      body: reminders.isEmpty
          ? EmptyState(
              icon: Icons.alarm_off_rounded,
              title: context.t('emptyRemindersTitle'),
              body: context.t('emptyRemindersBody'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reminders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final Note note = reminders[index];
                final DateTime when = note.reminderAt!;
                final bool overdue = when.isBefore(DateTime.now());
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: context.scheme.primary.withOpacity(0.15),
                      child: Icon(
                        overdue ? Icons.alarm_on_rounded : Icons.alarm_rounded,
                        color: context.scheme.primary,
                      ),
                    ),
                    title: Text(note.displayTitle),
                    subtitle: Text(
                      '${AppDateUtils.dateTime(when)} · '
                      '${overdue ? context.t('overdue') : AppDateUtils.until(when)}',
                    ),
                    trailing: IconButton(
                      tooltip: context.t('removeReminder'),
                      icon: const Icon(Icons.alarm_off_rounded),
                      onPressed: () => notes.clearReminder(note),
                    ),
                    onTap: () => _open(context, note),
                  ),
                );
              },
            ),
    );
  }
}
