import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/enums.dart';
import '../core/l10n/context_ext.dart';
import '../data/models/attachment.dart';
import '../data/models/label.dart';
import '../data/models/note.dart';
import '../providers/labels_provider.dart';
import '../providers/notes_provider.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/note_actions_sheet.dart';
import '../widgets/note_card.dart';

/// Trash: restore or permanently delete notes (Spec §5, §13 screen 13).
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final NotesProvider notes = context.watch<NotesProvider>();
    final LabelsProvider labels = context.watch<LabelsProvider>();
    final List<Note> trashed = notes.trashed();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('trash')),
        actions: <Widget>[
          if (trashed.isNotEmpty)
            IconButton(
              tooltip: context.t('deleteForever'),
              icon: const Icon(Icons.delete_forever_rounded),
              onPressed: () async {
                final bool ok = await showConfirmDialog(
                  context,
                  title: context.t('confirmDeleteForeverTitle'),
                  body: context.t('confirmDeleteForeverBody'),
                  confirmLabel: context.t('deleteForever'),
                  cancelLabel: context.t('cancel'),
                  destructive: true,
                );
                if (ok) {
                  await notes.bulkDeleteForever(
                      trashed.map((Note n) => n.id).toList());
                }
              },
            ),
        ],
      ),
      body: trashed.isEmpty
          ? EmptyState(
              icon: Icons.delete_outline_rounded,
              title: context.t('emptyTrashTitle'),
              body: context.t('emptyTrashBody'),
            )
          : Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    context.t('emptyTrashBody'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: trashed.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Note note = trashed[index];
                      final (int done, int total) =
                          notes.checklistProgress(note.id);
                      final List<Label> noteLabels = notes
                          .labelIdsFor(note.id)
                          .map((String id) => labels.byId(id))
                          .whereType<Label>()
                          .toList();
                      final List<Attachment> attachments =
                          notes.attachmentsFor(note.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: NoteCard(
                          note: note,
                          done: done,
                          total: total,
                          attachments: attachments,
                          labels: noteLabels,
                          isGrid: false,
                          showReminder: false,
                          onTap: () => showNoteActionsSheet(context, note,
                              fromTrash: true),
                          onLongPress: () => showNoteActionsSheet(context, note,
                              fromTrash: true),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
