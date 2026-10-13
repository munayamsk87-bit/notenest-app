import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/enums.dart';
import '../core/l10n/context_ext.dart';
import '../data/models/attachment.dart';
import '../data/models/note.dart';
import '../data/services/file_storage_service.dart';
import '../data/services/ocr_service.dart';
import '../providers/notes_provider.dart';
import '../widgets/note_actions_sheet.dart';

/// Image note: attach photos, preview/remove them and extract text via OCR
/// (Spec §4C, §7).
class ImageNoteScreen extends StatefulWidget {
  const ImageNoteScreen({super.key, required this.noteId});

  final String noteId;

  @override
  State<ImageNoteScreen> createState() => _ImageNoteScreenState();
}

class _ImageNoteScreenState extends State<ImageNoteScreen> {
  static const Uuid _uuid = Uuid();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  Timer? _debounce;
  bool _hydrated = false;
  String? _ocrBusyId;

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _scheduleSave(Note note) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      note.title = _titleController.text;
      note.body = _bodyController.text;
      await context.read<NotesProvider>().update(note);
    });
  }

  Future<void> _pick(Note note, ImageSource source) async {
    try {
      final XFile? picked =
          await ImagePicker().pickImage(source: source, imageQuality: 90);
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

  Future<void> _runOcr(Note note, Attachment attachment) async {
    setState(() => _ocrBusyId = attachment.id);
    try {
      final String text = await OcrService.instance.extractText(attachment.path);
      if (!mounted) return;
      setState(() => _ocrBusyId = null);
      if (text.isEmpty) {
        context.showSnack(context.t('ocrNoText'));
        return;
      }
      await _showOcrResult(note, text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocrBusyId = null);
      context.showSnack('$e', error: true);
    }
  }

  Future<void> _showOcrResult(Note note, String text) async {
    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(ctx.t('ocrExtract')),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('copy'),
            child: Text(ctx.t('copyText')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('append'),
            child: Text(ctx.t('confirm')),
          ),
        ],
      ),
    );
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) context.showSnack(context.t('copied'));
    } else if (action == 'append') {
      _bodyController.text =
          '${_bodyController.text}\n\n$text'.trim();
      _scheduleSave(note);
    }
  }

  @override
  Widget build(BuildContext context) {
    final NotesProvider notes = context.watch<NotesProvider>();
    final Note? note = notes.byId(widget.noteId);
    if (note == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_hydrated) {
      _titleController.text = note.title;
      _bodyController.text = note.body;
      _hydrated = true;
    }
    final List<Attachment> images = notes
        .attachmentsFor(note.id)
        .where((Attachment a) => a.type == AttachmentType.image)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('image')),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
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
            onChanged: (_) => _scheduleSave(note),
          ),
          TextField(
            controller: _bodyController,
            minLines: 2,
            maxLines: null,
            decoration: InputDecoration(
              hintText: context.t('bodyHint'),
              border: InputBorder.none,
              filled: false,
            ),
            onChanged: (_) => _scheduleSave(note),
          ),
          const SizedBox(height: 16),
          if (images.isEmpty)
            _emptyImages(context)
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: images.length,
              itemBuilder: (BuildContext context, int index) {
                final Attachment a = images[index];
                return Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(File(a.path), fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: _iconBadge(
                        icon: Icons.close_rounded,
                        onTap: () async {
                          await notes.removeAttachment(a.id);
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: _ocrBusyId == a.id
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _iconBadge(
                              icon: Icons.text_fields_rounded,
                              onTap: () => _runOcr(note, a),
                            ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOptions(note),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(context.t('attachImage')),
      ),
    );
  }

  Widget _emptyImages(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: <Widget>[
          Icon(Icons.image_outlined, size: 44, color: context.scheme.primary),
          const SizedBox(height: 12),
          Text(context.t('attachImage'),
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _iconBadge({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _showAddOptions(Note note) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(ctx.t('fromGallery')),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(ctx.t('fromCamera')),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pick(note, source);
  }
}
