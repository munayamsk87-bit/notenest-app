import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/enums.dart';
import '../core/l10n/context_ext.dart';
import '../data/models/checklist_item.dart';
import '../data/models/label.dart';
import '../data/models/note.dart';
import '../data/repositories/note_repository.dart';
import '../data/services/backup_service.dart';
import '../providers/labels_provider.dart';
import '../providers/notes_provider.dart';
import 'label_picker_sheet.dart';
import 'note_color_picker.dart';
import 'reminder_picker.dart';

/// Long-press action sheet for a single note (Spec §5).
Future<void> showNoteActionsSheet(
  BuildContext context,
  Note note, {
  bool fromTrash = false,
}) async {
  final NotesProvider notes = context.read<NotesProvider>();

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!fromTrash) ...<Widget>[
                _tile(ctx, note.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                    ctx.t(note.isPinned ? 'unpin' : 'pin'), () async {
                  Navigator.of(ctx).pop();
                  await notes.togglePin(note);
                }),
                _tile(
                  ctx,
                  note.isFavorite ? Icons.star_outline_rounded : Icons.star_rounded,
                  ctx.t(note.isFavorite ? 'unfavorite' : 'favorite'),
                  () async {
                    Navigator.of(ctx).pop();
                    await notes.toggleFavorite(note);
                  },
                ),
                _tile(ctx, Icons.palette_outlined, ctx.t('labelColor'), () async {
                  Navigator.of(ctx).pop();
                  await _pickColor(context, note);
                }),
                _tile(ctx, Icons.label_outline_rounded, ctx.t('labels'), () async {
                  Navigator.of(ctx).pop();
                  await showLabelPicker(context, note);
                }),
                _tile(
                  ctx,
                  note.hasReminder ? Icons.alarm_off_rounded : Icons.alarm_add_rounded,
                  ctx.t(note.hasReminder ? 'removeReminder' : 'setReminder'),
                  () async {
                    Navigator.of(ctx).pop();
                    await _pickReminder(context, note);
                  },
                ),
                _tile(ctx, Icons.copy_all_rounded, ctx.t('duplicate'), () async {
                  Navigator.of(ctx).pop();
                  await notes.duplicate(note);
                }),
              ],
              _tile(ctx, Icons.share_outlined, ctx.t('share'), () async {
                Navigator.of(ctx).pop();
                await _share(context, note);
              }),
              _tile(ctx, Icons.copy_rounded, ctx.t('copyText'), () async {
                Navigator.of(ctx).pop();
                final String text = await _asPlainText(context, note);
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) context.showSnack(context.t('copied'));
              }),
              _tile(ctx, Icons.file_download_outlined, ctx.t('exportText'), () async {
                Navigator.of(ctx).pop();
                await _exportFile(context, note);
              }),
              if (fromTrash) ...<Widget>[
                _tile(ctx, Icons.restore_rounded, ctx.t('restore'), () async {
                  Navigator.of(ctx).pop();
                  await notes.restore(note);
                }),
                _tile(ctx, Icons.delete_forever_rounded, ctx.t('deleteForever'),
                    () async {
                  Navigator.of(ctx).pop();
                  await notes.deleteForever(note);
                }, destructive: true),
              ] else ...<Widget>[
                _tile(
                  ctx,
                  note.isArchived ? Icons.unarchive_rounded : Icons.archive_outlined,
                  ctx.t(note.isArchived ? 'unarchiveAction' : 'archiveAction'),
                  () async {
                    Navigator.of(ctx).pop();
                    await notes.toggleArchive(note);
                  },
                ),
                _tile(ctx, Icons.delete_outline_rounded, ctx.t('moveToTrash'),
                    () async {
                  Navigator.of(ctx).pop();
                  await notes.moveToTrash(note);
                }, destructive: true),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

Widget _tile(
  BuildContext context,
  IconData icon,
  String label,
  VoidCallback onTap, {
  bool destructive = false,
}) {
  final Color color =
      destructive ? Theme.of(context).colorScheme.error : context.scheme.primary;
  return ListTile(
    leading: Icon(icon, color: color),
    title: Text(label),
    onTap: onTap,
  );
}

Future<void> _pickColor(BuildContext context, Note note) async {
  final NotesProvider notes = context.read<NotesProvider>();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(ctx.t('labelColor'),
                style: Theme.of(ctx).textTheme.titleMedium),
          ),
          NoteColorPicker(
            selected: note.color,
            onSelected: (int value) async {
              Navigator.of(ctx).pop();
              await notes.setColor(note, value);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

Future<void> _pickReminder(BuildContext context, Note note) async {
  final NotesProvider notes = context.read<NotesProvider>();
  if (note.hasReminder) {
    await notes.clearReminder(note);
    if (context.mounted) context.showSnack(context.t('removeReminder'));
    return;
  }
  final ReminderChoice? choice = await pickReminder(
    context,
    initial: note.reminderAt,
    initialRecurrence: note.recurrence,
  );
  if (choice == null) return;
  await notes.setReminder(note, choice.when, recurrence: choice.recurrence);
}

Future<String> _asPlainText(BuildContext context, Note note) async {
  final NoteRepository repo = NoteRepository();
  final List<ChecklistItem> items = note.type == NoteType.checklist
      ? await repo.getChecklistItems(note.id)
      : <ChecklistItem>[];
  final LabelsProvider labels = context.read<LabelsProvider>();
  final List<Label> noteLabels = context
      .read<NotesProvider>()
      .labelIdsFor(note.id)
      .map((String id) => labels.byId(id))
      .whereType<Label>()
      .toList();
  return BackupService.instance.noteAsText(note, items, noteLabels);
}

Future<void> _share(BuildContext context, Note note) async {
  final String text = await _asPlainText(context, note);
  await SharePlus.instance.share(ShareParams(text: text, subject: note.displayTitle));
}

Future<void> _exportFile(BuildContext context, Note note) async {
  final String text = await _asPlainText(context, note);
  final Directory dir = await getTemporaryDirectory();
  final String safeName = note.displayTitle
      .replaceAll(RegExp(r'[^\w\s-]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
  final String path = p.join(
      dir.path, '${safeName.isEmpty ? 'note' : safeName}.txt');
  final File file = File(path);
  await file.writeAsString(text);
  await SharePlus.instance.share(
    ShareParams(files: <XFile>[XFile(path)], subject: note.displayTitle),
  );
}
