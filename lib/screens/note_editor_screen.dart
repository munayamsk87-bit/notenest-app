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
import '../data/models/label.dart';
import '../data/models/note.dart';
import '../data/services/ai_service.dart';
import '../data/services/file_storage_service.dart';
import '../providers/labels_provider.dart';
import '../providers/notes_provider.dart';
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

  Future<void> _runAi(Note note, String action) async {
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
    final String source = '${_titleController.text}\n${_bodyController.text}'.trim();
    if (source.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      String result;
      switch (action) {
        case 'summarize':
          result = await ai.summarize(source);
          break;
        case 'rewrite':
          result = await ai.rewrite(source);
          break;
        default:
          final List<String> items = await ai.generateChecklist(source);
          result = items.map((String i) => '• $i').join('\n');
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      await _showAiResult(note, result);
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

  Future<void> _showAiResult(Note note, String result) async {
    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(ctx.t('aiTools')),
        content: SingleChildScrollView(child: Text(result)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('replace'),
            child: Text(ctx.t('replace')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('append'),
            child: Text(ctx.t('confirm')),
          ),
        ],
      ),
    );
    if (choice == null) return;
    final String existing = _bodyController.text;
    _bodyController.text =
        choice == 'replace' ? result : '$existing\n\n$result';
    await _save(note);
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
                case 'share':
                case 'copy':
                case 'export':
                case 'delete':
                  await showNoteActionsSheet(context, note);
                  break;
                case 'summarize':
                case 'rewrite':
                case 'checklist':
                  await _runAi(note, value);
                  break;
              }
            },
            itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'summarize', child: Text(ctx.t('summarize'))),
              PopupMenuItem<String>(value: 'rewrite', child: Text(ctx.t('rewrite'))),
              PopupMenuItem<String>(
                  value: 'checklist', child: Text(ctx.t('generateChecklist'))),
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
