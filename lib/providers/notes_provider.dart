import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/enums.dart';
import '../data/models/attachment.dart';
import '../data/models/checklist_item.dart';
import '../data/models/note.dart';
import '../data/repositories/note_repository.dart';
import '../data/services/file_storage_service.dart';
import '../data/services/notification_service.dart';

/// The single source of truth for notes in the UI layer. All mutations flow
/// through here so the database and in-memory list never drift apart (Spec §5).
class NotesProvider extends ChangeNotifier {
  NotesProvider(this._repo);

  final NoteRepository _repo;
  static const Uuid _uuid = Uuid();

  List<Note> _notes = <Note>[];
  Map<String, int> _progress = <String, int>{}; // done*1000 + total
  Map<String, List<Attachment>> _attachments = <String, List<Attachment>>{};
  Map<String, List<String>> _noteLabels = <String, List<String>>{};
  List<String> _searchHistory = <String>[];
  bool _loading = true;

  bool get isLoading => _loading;
  List<String> get searchHistory => List<String>.unmodifiable(_searchHistory);

  // --- Loading ----------------------------------------------------------------

  Future<void> init() async {
    await refresh();
    // Re-arm reminders after a cold start / reboot (Spec §6).
    final List<Note> withReminders =
        _notes.where((Note n) => n.hasReminder && !n.isTrashed).toList();
    await NotificationService.instance.rescheduleAll(withReminders);
    for (final Note n in withReminders) {
      await _repo.updateNote(n);
    }
    _searchHistory = await _repo.getSearchHistory();
    _loading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    _notes = await _repo.getAllNotes();
    final List<String> ids = _notes.map((Note n) => n.id).toList();
    _progress = await _repo.checklistProgressForNotes(ids);
    _attachments = await _repo.getAttachmentsForNotes(ids);
    _noteLabels = await _repo.getLabelIdsForNotes(ids);
    notifyListeners();
  }

  // --- Views ------------------------------------------------------------------

  List<Note> _sorted(Iterable<Note> input, NoteSort sort) {
    final List<Note> list = input.toList();
    switch (sort) {
      case NoteSort.updatedDesc:
        list.sort((Note a, Note b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case NoteSort.createdDesc:
        list.sort((Note a, Note b) => b.createdAt.compareTo(a.createdAt));
        break;
      case NoteSort.titleAsc:
        list.sort((Note a, Note b) =>
            a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()));
        break;
    }
    return list;
  }

  List<Note> get _active =>
      _notes.where((Note n) => !n.isTrashed && !n.isArchived).toList();

  List<Note> pinned(NoteSort sort) =>
      _sorted(_active.where((Note n) => n.isPinned), sort);

  List<Note> unpinned(NoteSort sort) =>
      _sorted(_active.where((Note n) => !n.isPinned), sort);

  List<Note> get favorites =>
      _sorted(_notes.where((Note n) => n.isFavorite && !n.isTrashed), NoteSort.updatedDesc);

  List<Note> archived(NoteSort sort) =>
      _sorted(_notes.where((Note n) => n.isArchived && !n.isTrashed), sort);

  List<Note> trashed() =>
      _sorted(_notes.where((Note n) => n.isTrashed), NoteSort.updatedDesc);

  List<Note> byType(NoteType? type, {bool archived = false}) {
    final Iterable<Note> base = archived
        ? _notes.where((Note n) => n.isArchived && !n.isTrashed)
        : _active;
    if (type == null) return _sorted(base, NoteSort.updatedDesc);
    return _sorted(base.where((Note n) => n.type == type), NoteSort.updatedDesc);
  }

  List<Note> byLabel(String labelId, NoteSort sort) => _sorted(
        _active.where((Note n) =>
            (_noteLabels[n.id] ?? const <String>[]).contains(labelId)),
        sort,
      );

  List<Note> get upcomingReminders {
    return _sorted(
      _notes.where((Note n) =>
          n.hasReminder && !n.isTrashed && !n.isArchived),
      NoteSort.updatedDesc,
    )..sort((Note a, Note b) => a.reminderAt!.compareTo(b.reminderAt!));
  }

  Note? byId(String id) {
    for (final Note n in _notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  int get activeCount => _active.length;
  int get archivedCount => _notes.where((Note n) => n.isArchived && !n.isTrashed).length;
  int get trashCount => _notes.where((Note n) => n.isTrashed).length;

  /// (done, total) for a checklist note.
  (int, int) checklistProgress(String noteId) {
    final int value = _progress[noteId] ?? 0;
    return (value ~/ 1000, value % 1000);
  }

  List<Attachment> attachmentsFor(String noteId) =>
      _attachments[noteId] ?? const <Attachment>[];

  List<String> labelIdsFor(String noteId) =>
      _noteLabels[noteId] ?? const <String>[];

  // --- Create / update --------------------------------------------------------

  Future<Note> create({NoteType type = NoteType.text, int color = 0}) async {
    final Note note = Note(id: _uuid.v4(), type: type, color: color);
    await _repo.insertNote(note);
    _notes.insert(0, note);
    notifyListeners();
    return note;
  }

  /// Persists [note]. Set [touch] false for metadata-only changes.
  Future<void> update(Note note, {bool touch = true}) async {
    if (touch) note.updatedAt = DateTime.now();
    await _repo.updateNote(note);
    final int idx = _notes.indexWhere((Note n) => n.id == note.id);
    if (idx >= 0) {
      _notes[idx] = note;
    } else {
      _notes.insert(0, note);
    }
    notifyListeners();
  }

  Future<void> togglePin(Note note) async {
    note.isPinned = !note.isPinned;
    await update(note);
  }

  Future<void> toggleFavorite(Note note) async {
    note.isFavorite = !note.isFavorite;
    await update(note);
  }

  Future<void> toggleArchive(Note note) async {
    note.isArchived = !note.isArchived;
    if (note.isArchived) note.isTrashed = false;
    await update(note);
  }

  Future<void> setColor(Note note, int color) async {
    note.color = color;
    await update(note);
  }

  Future<void> setLabels(Note note, List<String> labelIds) async {
    await _repo.setLabelsForNote(note.id, labelIds);
    _noteLabels[note.id] = labelIds;
    notifyListeners();
  }

  Future<void> moveToTrash(Note note) async {
    note.isTrashed = true;
    note.trashedAt = DateTime.now();
    note.isPinned = false;
    await NotificationService.instance.cancelForNote(note);
    await update(note);
  }

  Future<void> restore(Note note) async {
    note.isTrashed = false;
    note.trashedAt = null;
    await update(note);
  }

  Future<void> deleteForever(Note note) async {
    // Clean up any attachment files that no other note references.
    final List<Attachment> files = attachmentsFor(note.id);
    await _repo.deleteNote(note.id);
    for (final Attachment a in files) {
      await _deleteFileIfUnreferenced(a.path);
    }
    _notes.removeWhere((Note n) => n.id == note.id);
    _attachments.remove(note.id);
    _progress.remove(note.id);
    _noteLabels.remove(note.id);
    await NotificationService.instance.cancelForNote(note);
    notifyListeners();
  }

  Future<Note> duplicate(Note note) async {
    final Note copy = Note(
      id: _uuid.v4(),
      title: note.title.isEmpty ? '' : '${note.title} (copy)',
      body: note.body,
      type: note.type,
      color: note.color,
      linkUrl: note.linkUrl,
    );
    await _repo.insertNote(copy);
    // Copy checklist items.
    if (note.type == NoteType.checklist) {
      final List<ChecklistItem> items = await _repo.getChecklistItems(note.id);
      final List<ChecklistItem> cloned = items
          .map((ChecklistItem i) => ChecklistItem(
                id: _uuid.v4(),
                noteId: copy.id,
                text: i.text,
                isDone: i.isDone,
                position: i.position,
              ))
          .toList();
      await _repo.replaceChecklistItems(copy.id, cloned);
    }
    // Copy label links.
    final List<String> labels = labelIdsFor(note.id);
    if (labels.isNotEmpty) await _repo.setLabelsForNote(copy.id, labels);
    await refresh();
    return copy;
  }

  // --- Checklist --------------------------------------------------------------

  Future<List<ChecklistItem>> loadChecklist(String noteId) =>
      _repo.getChecklistItems(noteId);

  /// Persists the checklist and keeps the in-memory progress badge in sync.
  Future<void> saveChecklist(
      String noteId, List<ChecklistItem> items) async {
    await _repo.replaceChecklistItems(noteId, items);
    final int done = items.where((ChecklistItem i) => i.isDone).length;
    _progress[noteId] = done * 1000 + items.length;
    final Note? note = byId(noteId);
    if (note != null) note.updatedAt = DateTime.now();
    notifyListeners();
  }

  // --- Reminders --------------------------------------------------------------

  Future<void> setReminder(
    Note note,
    DateTime when, {
    ReminderRecurrence recurrence = ReminderRecurrence.none,
  }) async {
    note.reminderAt = when;
    note.recurrence = recurrence;
    final int? id = await NotificationService.instance.schedule(note);
    note.notificationId = id;
    await update(note, touch: false);
  }

  Future<void> clearReminder(Note note) async {
    await NotificationService.instance.cancelForNote(note);
    note.reminderAt = null;
    note.recurrence = ReminderRecurrence.none;
    note.notificationId = null;
    await update(note, touch: false);
  }

  // --- Bulk operations --------------------------------------------------------

  Future<void> bulkTrash(List<String> ids) async {
    for (final String id in ids) {
      final Note? n = byId(id);
      if (n != null) await moveToTrash(n);
    }
  }

  Future<void> bulkArchive(List<String> ids) async {
    for (final String id in ids) {
      final Note? n = byId(id);
      if (n != null) await toggleArchive(n);
    }
  }

  Future<void> bulkRestore(List<String> ids) async {
    for (final String id in ids) {
      final Note? n = byId(id);
      if (n != null) await restore(n);
    }
  }

  Future<void> bulkDeleteForever(List<String> ids) async {
    for (final String id in ids) {
      final Note? n = byId(id);
      if (n != null) await deleteForever(n);
    }
  }

  // --- Search -----------------------------------------------------------------

  Future<List<Note>> search(String query) async {
    final String q = query.trim();
    if (q.isEmpty) return <Note>[];
    final List<Note> results = await _repo.search(q);
    await _repo.addSearchTerm(q);
    _searchHistory = await _repo.getSearchHistory();
    notifyListeners();
    return results;
  }

  Future<void> clearSearchHistory() async {
    await _repo.clearSearchHistory();
    _searchHistory = <String>[];
    notifyListeners();
  }

  // --- Maintenance ------------------------------------------------------------

  Future<void> purgeTrash({int days = 30}) async {
    final List<String> removed = await _repo.purgeTrashOlderThan(days);
    if (removed.isNotEmpty) await refresh();
  }

  Future<int> attachmentCount() => _repo.attachmentCount();

  /// Cached count of loaded attachments (for the settings storage row).
  int get attachmentCountSnapshot {
    int count = 0;
    for (final List<Attachment> list in _attachments.values) {
      count += list.length;
    }
    return count;
  }

  Future<void> addAttachment(Attachment attachment) async {
    await _repo.addAttachment(attachment);
    _attachments
        .putIfAbsent(attachment.noteId, () => <Attachment>[])
        .add(attachment);
    notifyListeners();
  }

  Future<void> removeAttachment(String attachmentId) async {
    String? noteId;
    String? path;
    for (final MapEntry<String, List<Attachment>> entry in _attachments.entries) {
      for (final Attachment a in entry.value) {
        if (a.id == attachmentId) {
          noteId = entry.key;
          path = a.path;
          break;
        }
      }
    }
    if (noteId == null) return;
    await _repo.removeAttachment(attachmentId);
    _attachments[noteId]?.removeWhere((Attachment a) => a.id == attachmentId);
    notifyListeners();
    if (path != null) await _deleteFileIfUnreferenced(path);
  }

  Future<void> _deleteFileIfUnreferenced(String path) async {
    for (final List<Attachment> list in _attachments.values) {
      for (final Attachment a in list) {
        if (a.path == path) return; // still referenced elsewhere
      }
    }
    if (path.isNotEmpty && File(path).existsSync()) {
      await FileStorageService.instance.delete(path);
    }
  }
}
