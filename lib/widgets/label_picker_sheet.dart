import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/context_ext.dart';
import '../data/models/label.dart';
import '../data/models/note.dart';
import '../providers/labels_provider.dart';
import '../providers/notes_provider.dart';

/// Modal sheet to attach/detach labels on a note (Spec §5).
Future<void> showLabelPicker(BuildContext context, Note note) async {
  final NotesProvider notes = context.read<NotesProvider>();
  final LabelsProvider labelsProvider = context.read<LabelsProvider>();
  final List<String> selected = List<String>.of(notes.labelIdsFor(note.id));

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) {
      return StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSheetState) {
          final List<Label> labels = labelsProvider.items;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      ctx.t('labels'),
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (labels.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        ctx.t('emptyLabelsBody'),
                        style: Theme.of(ctx).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: labels.length,
                        itemBuilder: (BuildContext ctx, int index) {
                          final Label label = labels[index];
                          final bool checked = selected.contains(label.id);
                          return CheckboxListTile(
                            value: checked,
                            onChanged: (bool? v) {
                              setSheetState(() {
                                if (v == true) {
                                  selected.add(label.id);
                                } else {
                                  selected.remove(label.id);
                                }
                              });
                            },
                            title: Text(label.name),
                            secondary: const Icon(Icons.label_outline_rounded),
                          );
                        },
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _createLabel(ctx, labelsProvider),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(ctx.t('addLabel')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              await notes.setLabels(note, selected);
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            },
                            child: Text(ctx.t('save')),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _createLabel(BuildContext context, LabelsProvider provider) async {
  final TextEditingController controller = TextEditingController();
  final String? name = await showDialog<String>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: Text(ctx.t('addLabel')),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: ctx.t('labelName')),
        onSubmitted: (String v) => Navigator.of(ctx).pop(v.trim()),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(ctx.t('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: Text(ctx.t('save')),
        ),
      ],
    ),
  );
  if (name != null && name.isNotEmpty) {
    await provider.create(name);
  }
}
