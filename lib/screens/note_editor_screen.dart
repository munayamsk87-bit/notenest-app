import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/enums.dart';
import '../core/l10n/context_ext.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/validators.dart';
import '../data/models/attachment.dart';
import '../data/models/checklist_item.dart';
import '../data/models/label.dart';
import '../data/models/note.dart';
import '../data/services/ai_service.dart';
import '../data/services/file_storage_service.dart';
import '../providers/labels_provider.dart';
import '../providers/notes_provider.dart';
import '../widgets/ai_actions_sheet.dart';
import '../widgets/ai_result_sheet.dart';
import '../widgets/label_picker_sheet.dart';
import '../widgets/note_actions_sheet.dart';
import '../widgets/note_color_picker.dart';
import '../widgets/reminder_picker.dart';

/// Editor for text and link notes, with autosave and rich actions (Spec §4A/§4F).
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, required this.noteId});

  final String noteId;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  static const Uuid _uuid = Uuid();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  Timer? _debounce;
  bool _saving = false;
  bool _savedRecently = false;
  bool _loaded = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _hydrate(Note note) {
    if (_loaded) return;
    _titleController.text = note.title;
    _bodyController.text = note.body;
    _urlController.text = note.linkUrl ?? '';
    _loaded = true;
  }

  void _scheduleSave(Note note) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _save(note));
  }

  Future<void> _save(Note note) async {
    setState(() => _saving = true);
    note.title = _titleController.text;
    note.body = _bodyController.text;
    if (note.type == NoteType.link) {
      note.linkUrl = Validators.normaliseUrl(_urlController.text);
    }
    await context.read<NotesProvider>().update(note);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _savedRecently = true;
    });
    Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _savedRecently = false);
    });
  }

  Future<void> _addImage(Note note, ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? picked = await picker.pickImage(source: source, imageQuality: 90);
      if (picked == null) return;
      final String path = await FileStorageService.instance.persist(picked.path);
      await context.read<NotesProvider>().addAttachment(
            Attachment(
              id: _uuid.v4(),
              noteId: note.id,
              type: AttachmentType.image,
              path: path,
              mimeType: 'image/*',
            ),
          );
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) context.showSnack(context.t('permissionPhotos'), error: true);
    }
  }

  Future<void> _pickColor(Note note) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            NoteColorPicker(
              selected: note.color,
              onSelected: (int value) async {
                Navigator.of(ctx).pop();
                await context.read<NotesProvider>().setColor(note, value);
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _setReminder(Note note) async {
    if (note.hasReminder) {
      await context.read<NotesProvider>().clearReminder(note);
      if (mounted) setState(() {});
      return;
    }
    final ReminderChoice? choice =
        await pickReminder(context, initial: note.reminderAt);
    if (choice == null) return;
    await context.read<NotesProvider>().setReminder(note, choice.when,
        recurrence: choice.recurrence);
    if (mounted) setState(() {});
  }

  Future<void> _convertToChecklist(Note note) async {
    await _save(note);
    note.type = NoteType.checklist;
    await context.read<NotesProvider>().update(note);
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacementNamed('/checklist', arguments: note.id);
  }

  Future<void> _openAiTools(Note note) async {
    final AiService ai = AiService.instance;
    if (!await ai.isConfigured) {
      if (mounted) {
        context.showSnack(
          context.t('aiNotConfigured'),
          error: true,
          actionLabel: context.t('aiSettings'),
          onAction: () => Navigator.of(context).pushNamed('/ai'),
        );
      }
      return;
    }
    if (!mounted) return;
    final AiActionChoice? choice = await showAiActionsSheet(context);
    if (choice == null || !mounted) return;
    if (choice.kind == AiActionKind.ask) {
      await Navigator.of(context).pushNamed('/ai-ask', arguments: note.id);
      return;
    }
    await _runAiChoice(note, choice);
  }

  Future<void> _runAiChoice(Note note, AiActionChoice choice) async {
    final AiService ai = AiService.instance;
    final String source = '${_titleController.text}\n${_bodyController.text}'.trim();
    if (source.isEmpty) {
      context.showSnack(context.t('aiNoText'));
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      switch (choice.kind) {
        case AiActionKind.suggestTitle:
          final String title = await ai.suggestTitle(source);
          if (!mounted) return;
          Navigator.of(context).pop();
          await _applySuggestedTitle(note, title);
          return;
        case AiActionKind.labels:
          final List<String> existing = context
              .read<LabelsProvider>()
              .items
              .map((Label l) => l.name)
              .toList();
          final List<String> names = await ai.suggestLabels(source, existing);
          if (!mounted) return;
          Navigator.of(context).pop();
          await _applySuggestedLabels(note, names);
          return;
        case AiActionKind.checklist:
          final List<String> items = await ai.generateChecklist(source);
          if (!mounted) return;
          Navigator.of(context).pop();
          await _createChecklistFromResult(note, items.join('\n'));
          return;
        default:
          break;
      }

      final String result = await _produce(ai, choice, source);
      if (!mounted) return;
      Navigator.of(context).pop();
      await _showAiResult(note, result, choice);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      context.showSnack(
        '$e',
        error: true,
        actionLabel: context.t('aiSettings'),
        onAction: () => Navigator.of(context).pushNamed('/ai'),
      );
    }
  }

  Future<String> _produce(
      AiService ai, AiActionChoice choice, String source) async {
    switch (choice.kind) {
      case AiActionKind.summarize:
        return ai.summarize(source);
      case AiActionKind.keyPoints:
        return ai.keyPoints(source);
      case AiActionKind.continueWriting:
        return ai.continueWriting(source);
      case AiActionKind.fixGrammar:
        return ai.fixGrammar(source);
      case AiActionKind.shorten:
        return ai.shorten(source);
      case AiActionKind.expand:
        return ai.expand(source);
      case AiActionKind.tone:
        return ai.changeTone(source, choice.param ?? 'friendly');
      case AiActionKind.translate:
        return ai.translate(source, choice.param ?? 'English');
      default:
        return ai.summarize(source);
    }
  }

  String _aiTitleFor(AiActionChoice choice) {
    switch (choice.kind) {
      case AiActionKind.summarize:
        return context.t('summarize');
      case AiActionKind.keyPoints:
        return context.t('keyPoints');
      case AiActionKind.continueWriting:
        return context.t('continueWriting');
      case AiActionKind.fixGrammar:
        return context.t('fixGrammar');
      case AiActionKind.shorten:
        return context.t('shorten');
      case AiActionKind.expand:
        return context.t('expand');
      case AiActionKind.tone:
        return '${context.t('tone')}: ${choice.param}';
      case AiActionKind.translate:
        return '${context.t('translate')}: ${choice.param}';
      default:
        return context.t('aiTools');
    }
  }

  Future<void> _showAiResult(
      Note note, String result, AiActionChoice choice) async {
    final AiResultAction? action = await showAiResultSheet(
      context,
      title: _aiTitleFor(choice),
      result: result,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case AiResultAction.replace:
        _bodyController.text = result;
        await _save(note);
        break;
      case AiResultAction.append:
        _bodyController.text =
            '${_bodyController.text}\n\n$result'.trim();
        await _save(note);
        break;
      case AiResultAction.copy:
        await Clipboard.setData(ClipboardData(text: result));
        if (mounted) context.showSnack(context.t('copied'));
        break;
      case AiResultAction.checklist:
        await _createChecklistFromResult(note, result);
        break;
      case AiResultAction.newNote:
        await _createNoteFromResult(result);
        break;
    }
  }

  Future<void> _applySuggestedTitle(Note note, String title) async {
    final String clean = title.trim();
    if (clean.isEmpty) return;
    _titleController.text = clean;
    await _save(note);
    if (mounted) context.showSnack(context.t('aiTitleApplied'));
  }

  Future<void> _applySuggestedLabels(Note note, List<String> names) async {
    final List<String> cleaned = names
        .map((String n) => n.replaceFirst(RegExp(r'^[\-\*\d\.\)\s]+'), '').trim())
        .where((String n) => n.isNotEmpty)
        .toSet()
        .toList();
    if (cleaned.isEmpty) {
      if (mounted) context.showSnack(context.t('aiNoText'));
      return;
    }
    final Set<String> selected = cleaned.toSet();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setLocal) => AlertDialog(
          title: Text(ctx.t('suggestLabels')),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cleaned
                .map((String n) => FilterChip(
                      label: Text(n),
                      selected: selected.contains(n),
                      onSelected: (bool v) => setLocal(() {
                        if (v) {
                          selected.add(n);
                        } else {
                          selected.remove(n);
                        }
                      }),
                    ))
                .toList(),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(ctx.t('confirm')),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    final LabelsProvider labels = context.read<LabelsProvider>();
    final NotesProvider notes = context.read<NotesProvider>();
    final List<String> labelIds = List<String>.of(notes.labelIdsFor(note.id));
    for (final String name in selected) {
      Label? found;
      for (final Label l in labels.items) {
        if (l.name.toLowerCase() == name.toLowerCase()) {
          found = l;
          break;
        }
      }
      if (found != null) {
        if (!labelIds.contains(found.id)) labelIds.add(found.id);
      } else {
        final Label created = await labels.create(name);
        labelIds.add(created.id);
      }
    }
    await notes.setLabels(note, labelIds);
    if (mounted) {
      setState(() {});
      context.showSnack(context.t('aiLabelsApplied'));
    }
  }

  Future<void> _createChecklistFromResult(Note note, String result) async {
    final List<String> items = result
        .split('\n')
        .map((String s) =>
            s.replaceFirst(RegExp(r'^[\-\*\d\.\)\s•]+'), '').trim())
        .where((String s) => s.isNotEmpty)
        .toList();
    if (items.isEmpty) return;
    final NotesProvider notes = context.read<NotesProvider>();
    final Note created = await notes.create(type: NoteType.checklist, color: note.color);
    created.title = note.displayTitle;
    await notes.update(created);
    final List<ChecklistItem> rows = <ChecklistItem>[
      for (int i = 0; i < items.length; i++)
        ChecklistItem(id: _uuid.v4(), noteId: created.id, text: items[i], position: i),
    ];
    await notes.saveChecklist(created.id, rows);
    if (!mounted) return;
    Navigator.of(context).pushNamed('/checklist', arguments: created.id);
  }

  Future<void> _createNoteFromResult(String result) async {
    final NotesProvider notes = context.read<NotesProvider>();
    final Note created = await notes.create(color: 0);
    created.body = result;
    await notes.update(created);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/note', arguments: created.id);
  }

  Future<void> _openLink() async {
    final String? url = Validators.normaliseUrl(_urlController.text);
    if (url == null) {
      context.showSnack(context.t('invalidUrl'), error: true);
      return;
    }
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) context.showSnack(context.t('invalidUrl'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final NotesProvider notes = context.watch<NotesProvider>();
    final Note? note = notes.byId(widget.noteId);
    if (note == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _hydrate(note);

    final LabelsProvider labels = context.watch<LabelsProvider>();
    final List<Label> noteLabels = notes
        .labelIdsFor(note.id)
        .map((String id) => labels.byId(id))
        .whereType<Label>()
        .toList();
    final List<Attachment> attachments = notes.attachmentsFor(note.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          note.type == NoteType.link ? context.t('link') : context.t('textNote'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        actions: <Widget>[
          IconButton(
            tooltip: context.t('aiTools'),
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: () => _openAiTools(note),
          ),
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (String value) async {
              switch (value) {
                case 'ai':
                  await _openAiTools(note);
                  break;
                case 'share':
                case 'copy':
                case 'export':
                case 'delete':
                  await showNoteActionsSheet(context, note);
                  break;
              }
            },
            itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'ai', child: Text(ctx.t('aiTools'))),
              const PopupMenuDivider(),
              PopupMenuItem<String>(value: 'share', child: Text(ctx.t('share'))),
              PopupMenuItem<String>(value: 'copy', child: Text(ctx.t('copyText'))),
              PopupMenuItem<String>(value: 'export', child: Text(ctx.t('exportText'))),
              const PopupMenuDivider(),
              PopupMenuItem<String>(value: 'delete', child: Text(ctx.t('moveToTrash'))),
            ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (noteLabels.isNotEmpty || note.hasReminder)
            _chipsRow(context, note, noteLabels),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => _scheduleSave(note),
                ),
                if (note.type == NoteType.link) ...<Widget>[
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            hintText: context.t('urlHint'),
                            prefixIcon: const Icon(Icons.link_rounded),
                          ),
                          onChanged: (_) => _scheduleSave(note),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _openLink,
                        icon: const Icon(Icons.open_in_new_rounded),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: _bodyController,
                  minLines: 6,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: note.type == NoteType.link
                        ? context.t('descriptionHint')
                        : context.t('bodyHint'),
                    border: InputBorder.none,
                    filled: false,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => _scheduleSave(note),
                ),
                if (attachments.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _attachmentsStrip(context, note, attachments),
                ],
              ],
            ),
          ),
          _toolbar(context, note),
        ],
      ),
    );
  }

  Widget _chipsRow(BuildContext context, Note note, List<Label> labels) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          if (note.hasReminder)
            Chip(
              avatar: const Icon(Icons.alarm_rounded, size: 16),
              label: Text(
                context.t('reminderAt', <String, Object>{
                  'when': _shortDateTime(note.reminderAt!),
                }),
              ),
            ),
          for (final Label l in labels)
            Chip(
              avatar: const Icon(Icons.label_outline_rounded, size: 16),
              label: Text(l.name),
            ),
        ],
      ),
    );
  }

  Widget _attachmentsStrip(
      BuildContext context, Note note, List<Attachment> attachments) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final Attachment a = attachments[index];
          return Stack(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: a.type == AttachmentType.image
                    ? Image.file(File(a.path),
                        width: 96, height: 96, fit: BoxFit.cover)
                    : Container(
                        width: 96,
                        height: 96,
                        color: AppColors.lavender,
                        child: const Icon(Icons.attach_file_rounded),
                      ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  iconSize: 18,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await context.read<NotesProvider>().removeAttachment(a.id);
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _toolbar(BuildContext context, Note note) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Colors.black.withOpacity(0.06)),
          ),
        ),
        child: Row(
          children: <Widget>[
            IconButton(
              tooltip: context.t('attachImage'),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: () => _addImage(note, ImageSource.gallery),
            ),
            IconButton(
              tooltip: context.t('checklist'),
              icon: const Icon(Icons.checklist_rounded),
              onPressed: () => _convertToChecklist(note),
            ),
            IconButton(
              tooltip: context.t('labelColor'),
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => _pickColor(note),
            ),
            IconButton(
              tooltip: context.t('labels'),
              icon: const Icon(Icons.label_outline_rounded),
              onPressed: () async {
                await showLabelPicker(context, note);
                if (mounted) setState(() {});
              },
            ),
            IconButton(
              tooltip: context.t('setReminder'),
              icon: Icon(note.hasReminder
                  ? Icons.alarm_on_rounded
                  : Icons.alarm_add_rounded),
              onPressed: () => _setReminder(note),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                _saving
                    ? context.t('saving')
                    : (_savedRecently ? context.t('autoSaved') : ''),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortDateTime(DateTime dt) {
    final String hour = dt.hour.toString().padLeft(2, '0');
    final String minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month} $hour:$minute';
  }
}
