import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../core/l10n/context_ext.dart';
import '../data/models/checklist_item.dart';
import '../data/models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/note_actions_sheet.dart';

/// Checklist editor: add, edit, reorder, complete and delete items (Spec §4B).
class ChecklistEditorScreen extends StatefulWidget {
  const ChecklistEditorScreen({super.key, required this.noteId});

  final String noteId;

  @override
  State<ChecklistEditorScreen> createState() => _ChecklistEditorScreenState();
}

class _ChecklistEditorScreenState extends State<ChecklistEditorScreen> {
  static const Uuid _uuid = Uuid();

  final TextEditingController _titleController = TextEditingController();
  final List<_Row> _rows = <_Row>[];

  Timer? _debounce;
  bool _loading = true;
  bool _hydratedTitle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    for (final _Row row in _rows) {
      row.controller.dispose();
      row.focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final NotesProvider notes = context.read<NotesProvider>();
    final List<ChecklistItem> items = await notes.loadChecklist(widget.noteId);
    if (!mounted) return;
    setState(() {
      for (final ChecklistItem item in items) {
        _rows.add(_Row(
          item: item,
          controller: TextEditingController(text: item.text),
          focusNode: FocusNode(),
        ));
      }
      _loading = false;
    });
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _save);
  }

  Future<void> _save() async {
    final NotesProvider notes = context.read<NotesProvider>();
    final Note? note = notes.byId(widget.noteId);
    if (note == null) return;
    note.title = _titleController.text;
    final List<ChecklistItem> items = <ChecklistItem>[];
    for (int i = 0; i < _rows.length; i++) {
      final _Row row = _rows[i];
      row.item.text = row.controller.text;
      row.item.position = i;
      items.add(row.item);
    }
    await notes.update(note);
    await notes.saveChecklist(widget.noteId, items);
  }

  void _addItem({String text = ''}) {
    final _Row row = _Row(
      item: ChecklistItem(
        id: _uuid.v4(),
        noteId: widget.noteId,
        text: text,
        position: _rows.length,
      ),
      controller: TextEditingController(text: text),
      focusNode: FocusNode(),
    );
    setState(() => _rows.add(row));
    _scheduleSave();
    WidgetsBinding.instance.addPostFrameCallback((_) => row.focusNode.requestFocus());
  }

  void _removeAt(int index) {
    setState(() {
      final _Row row = _rows.removeAt(index);
      row.controller.dispose();
      row.focusNode.dispose();
    });
    _scheduleSave();
  }

  void _toggle(_Row row) {
    setState(() {
      row.item.isDone = !row.item.isDone;
      final bool moveBottom =
          context.read<SettingsProvider>().moveCompletedToBottom;
      if (moveBottom) {
        _rows.sort((_Row a, _Row b) {
          if (a.item.isDone == b.item.isDone) return 0;
          return a.item.isDone ? 1 : -1;
        });
      }
    });
    _scheduleSave();
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final _Row row = _rows.removeAt(oldIndex);
      _rows.insert(newIndex, row);
    });
    _scheduleSave();
  }

  @override
  Widget build(BuildContext context) {
    final NotesProvider notes = context.watch<NotesProvider>();
    final Note? note = notes.byId(widget.noteId);
    if (note == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_hydratedTitle) {
      _titleController.text = note.title;
      _hydratedTitle = true;
    }

    final int done = _rows.where((_Row r) => r.item.isDone).length;
    final int total = _rows.length;
    final double fraction = total == 0 ? 0 : done / total;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('checklist')),
        actions: <Widget>[
          IconButton(
            tooltip: context.t(note.isPinned ? 'unpin' : 'pin'),
            icon: Icon(note.isPinned
                ? Icons.push_pin_rounded
                : Icons.push_pin_outlined),
            onPressed: () async {
              await notes.togglePin(note);
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => showNoteActionsSheet(context, note),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextField(
                        controller: _titleController,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          hintText: context.t('titleHint'),
                          border: InputBorder.none,
                          filled: false,
                        ),
                        onChanged: (_) => _scheduleSave(),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 7,
                          backgroundColor: Colors.black.withOpacity(0.08),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.t('completedOf',
                            <String, Object>{'done': done, 'total': total}),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                    buildDefaultDragHandles: true,
                    itemCount: _rows.length,
                    onReorder: _reorder,
                    itemBuilder: (BuildContext context, int index) {
                      final _Row row = _rows[index];
                      return Padding(
                        key: ValueKey<String>(row.item.id),
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: <Widget>[
                            Checkbox(
                              value: row.item.isDone,
                              onChanged: (_) => _toggle(row),
                            ),
                            Expanded(
                              child: TextField(
                                controller: row.controller,
                                focusNode: row.focusNode,
                                style: TextStyle(
                                  decoration: row.item.isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: row.item.isDone
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.5)
                                      : null,
                                ),
                                decoration: InputDecoration(
                                  hintText: context.t('itemHint'),
                                  border: InputBorder.none,
                                  filled: false,
                                ),
                                onChanged: (_) => _scheduleSave(),
                                onSubmitted: (_) => _addItem(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () => _removeAt(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addItem(),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.t('addItem')),
      ),
    );
  }
}

class _Row {
  _Row({required this.item, required this.controller, required this.focusNode});
  final ChecklistItem item;
  final TextEditingController controller;
  final FocusNode focusNode;
}
