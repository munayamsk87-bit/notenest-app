import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/enums.dart';
import '../core/l10n/context_ext.dart';
import '../data/models/attachment.dart';
import '../data/models/label.dart';
import '../data/models/note.dart';
import '../providers/labels_provider.dart';
import '../providers/notes_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/note_actions_sheet.dart';
import '../widgets/note_card.dart';

/// Archived notes (Spec §13 screen 12). Restore or delete from here.
class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final NotesProvider notes = context.watch<NotesProvider>();
    final LabelsProvider labels = context.watch<LabelsProvider>();
    final List<Note> archived = notes.archived(NoteSort.updatedDesc);

    return Scaffold(
      appBar: AppBar(title: Text(context.t('archive'))),
      body: archived.isEmpty
          ? EmptyState(
              icon: Icons.archive_outlined,
              title: context.t('emptyArchiveTitle'),
              body: context.t('emptyArchiveBody'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: archived.length,
              itemBuilder: (BuildContext context, int index) {
                final Note note = archived[index];
                final (int done, int total) = notes.checklistProgress(note.id);
                final List<Label> noteLabels = notes
                    .labelIdsFor(note.id)
                    .map((String id) => labels.byId(id))
                    .whereType<Label>()
                    .toList();
                final List<Attachment> attachments = notes.attachmentsFor(note.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NoteCard(
                    note: note,
                    done: done,
                    total: total,
                    attachments: attachments,
                    labels: noteLabels,
                    isGrid: false,
                    onTap: () => showNoteActionsSheet(context, note),
                    onLongPress: () => showNoteActionsSheet(context, note),
                  ),
                );
              },
            ),
    );
  }
}
