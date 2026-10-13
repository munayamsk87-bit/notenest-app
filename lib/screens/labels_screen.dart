import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/context_ext.dart';
import '../core/theme/app_colors.dart';
import '../data/models/label.dart';
import '../providers/labels_provider.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/note_color_picker.dart';

/// Create, rename, recolour and delete labels (Spec §5, §13 screen 10).
class LabelsScreen extends StatelessWidget {
  const LabelsScreen({super.key});

  Future<void> _edit(BuildContext context, {Label? label}) async {
    final LabelsProvider provider = context.read<LabelsProvider>();
    final TextEditingController controller =
        TextEditingController(text: label?.name ?? '');
    int color = label?.color ?? 0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                top: 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    ctx.t(label == null ? 'addLabel' : 'editLabel'),
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(hintText: ctx.t('labelName')),
                  ),
                  const SizedBox(height: 12),
                  Text(ctx.t('labelColor'),
                      style: Theme.of(ctx).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  NoteColorPicker(
                    selected: color,
                    onSelected: (int v) => setState(() => color = v),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      final String name = controller.text.trim();
                      if (name.isEmpty) return;
                      if (label == null) {
                        await provider.create(name, color: color);
                      } else {
                        await provider.rename(label.id, name);
                        await provider.setColor(label.id, color);
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: Text(ctx.t('save')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final LabelsProvider labels = context.watch<LabelsProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(context.t('labels'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.t('addLabel')),
      ),
      body: labels.items.isEmpty
          ? EmptyState(
              icon: Icons.label_outline_rounded,
              title: context.t('emptyLabelsTitle'),
              body: context.t('emptyLabelsBody'),
              actionLabel: context.t('addLabel'),
              onAction: () => _edit(context),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: labels.items.length,
              itemBuilder: (BuildContext context, int index) {
                final Label label = labels.items[index];
                final Color color =
                    NoteColors.byValue(label.color).light;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color,
                    child: Icon(Icons.label_rounded,
                        size: 18, color: AppColors.textMain),
                  ),
                  title: Text(label.name),
                  subtitle: Text(context.t('noteCount',
                      <String, Object>{'n': labels.countFor(label.id)})),
                  trailing: PopupMenuButton<String>(
                    onSelected: (String value) async {
                      if (value == 'edit') {
                        await _edit(context, label: label);
                      } else if (value == 'delete') {
                        final bool ok = await showConfirmDialog(
                          context,
                          title: context.t('deleteLabel'),
                          body: context.t('confirmDeleteBody'),
                          confirmLabel: context.t('delete'),
                          cancelLabel: context.t('cancel'),
                          destructive: true,
                        );
                        if (ok) await labels.delete(label.id);
                      }
                    },
                    itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                          value: 'edit', child: Text(ctx.t('editLabel'))),
                      PopupMenuItem<String>(
                          value: 'delete', child: Text(ctx.t('deleteLabel'))),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
