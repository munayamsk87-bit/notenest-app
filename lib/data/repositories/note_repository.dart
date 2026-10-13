import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../models/attachment.dart';
import '../models/checklist_item.dart';
import '../models/note.dart';

/// Data access for notes, checklist items, attachments, note↔label links and
/// search history. All writes go through here so the UI never touches SQL.
class NoteRepository {
  NoteRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  // --- Notes ------------------------------------------------------------------

  Future<List<Note>> getAllNotes() async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows =
        await db.query('notes', orderBy: 'updatedAt DESC');
    return rows.map(Note.fromMap).toList();
  }

  Future<Note?> getNote(String id) async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows =
        await db.query('notes', where: 'id = ?', whereArgs: <Object>[id], limit: 1);
    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  Future<void> insertNote(Note note) async {
    final Database db = await _db.database;
    await db.insert('notes', note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateNote(Note note) async {
    final Database db = await _db.database;
    await db.update('notes', note.toMap(), where: 'id = ?', whereArgs: <Object>[note.id]);
  }

  Future<void> deleteNote(String id) async {
    final Database db = await _db.database;
    await db.delete('notes', where: 'id = ?', whereArgs: <Object>[id]);
  }

  Future<void> deleteNotes(List<String> ids) async {
    if (ids.isEmpty) return;
    final Database db = await _db.database;
    final String placeholders = List<String>.filled(ids.length, '?').join(',');
    await db.delete('notes', where: 'id IN ($placeholders)', whereArgs: ids);
  }

  /// Removes trashed notes whose [Note.trashedAt] is older than [days].
  Future<List<String>> purgeTrashOlderThan(int days) async {
    final Database db = await _db.database;
    final int cutoff =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final List<Map<String, Object?>> rows = await db.query(
      'notes',
      columns: <String>['id'],
      where: 'isTrashed = 1 AND trashedAt IS NOT NULL AND trashedAt < ?',
      whereArgs: <Object>[cutoff],
    );
    final List<String> ids =
        rows.map((Map<String, Object?> r) => r['id'] as String).toList();
    if (ids.isNotEmpty) await deleteNotes(ids);
    return ids;
  }

  // --- Checklist --------------------------------------------------------------

  Future<List<ChecklistItem>> getChecklistItems(String noteId) async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows = await db.query(
      'checklist_items',
      where: 'noteId = ?',
      whereArgs: <Object>[noteId],
      orderBy: 'position ASC',
    );
    return rows.map(ChecklistItem.fromMap).toList();
  }

  /// Replaces the full checklist for a note inside a transaction so a partial
  /// failure can never leave inconsistent rows (Spec §5).
  Future<void> replaceChecklistItems(
      String noteId, List<ChecklistItem> items) async {
    final Database db = await _db.database;
    await db.transaction((Transaction txn) async {
      await txn.delete('checklist_items', where: 'noteId = ?', whereArgs: <Object>[noteId]);
      final Batch batch = txn.batch();
      for (int i = 0; i < items.length; i++) {
        batch.insert(
          'checklist_items',
          items[i].copyWith(position: i).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<Map<String, int>> checklistProgressForNotes(List<String> noteIds) async {
    if (noteIds.isEmpty) return <String, int>{};
    final Database db = await _db.database;
    final String placeholders = List<String>.filled(noteIds.length, '?').join(',');
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT noteId, COUNT(*) AS total, SUM(isDone) AS done '
      'FROM checklist_items WHERE noteId IN ($placeholders) GROUP BY noteId',
      noteIds,
    );
    final Map<String, int> result = <String, int>{};
    for (final Map<String, Object?> r in rows) {
      final int total = (r['total'] as int?) ?? 0;
      final int done = (r['done'] as int?) ?? 0;
      // Encode as done*1000 + total for a compact transfer.
      result[r['noteId'] as String] = done * 1000 + total;
    }
    return result;
  }

  // --- Attachments ------------------------------------------------------------

  Future<List<Attachment>> getAttachments(String noteId) async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows = await db.query(
      'attachments',
      where: 'noteId = ?',
      whereArgs: <Object>[noteId],
      orderBy: 'createdAt ASC',
    );
    return rows.map(Attachment.fromMap).toList();
  }

  Future<Map<String, List<Attachment>>> getAttachmentsForNotes(
      List<String> noteIds) async {
    if (noteIds.isEmpty) return <String, List<Attachment>>{};
    final Database db = await _db.database;
    final String placeholders = List<String>.filled(noteIds.length, '?').join(',');
    final List<Map<String, Object?>> rows = await db.query(
      'attachments',
      where: 'noteId IN ($placeholders)',
      whereArgs: noteIds,
      orderBy: 'createdAt ASC',
    );
    final Map<String, List<Attachment>> grouped = <String, List<Attachment>>{};
    for (final Map<String, Object?> r in rows) {
      final Attachment a = Attachment.fromMap(r);
      grouped.putIfAbsent(a.noteId, () => <Attachment>[]).add(a);
    }
    return grouped;
  }

  Future<void> addAttachment(Attachment attachment) async {
    final Database db = await _db.database;
    await db.insert('attachments', attachment.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeAttachment(String id) async {
    final Database db = await _db.database;
    await db.delete('attachments', where: 'id = ?', whereArgs: <Object>[id]);
  }

  Future<int> attachmentCount() async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows =
        await db.rawQuery('SELECT COUNT(*) AS c FROM attachments');
    return (rows.first['c'] as int?) ?? 0;
  }

  // --- Note ↔ label -----------------------------------------------------------

  Future<List<String>> getLabelIdsForNote(String noteId) async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows = await db.query(
      'note_labels',
      columns: <String>['labelId'],
      where: 'noteId = ?',
      whereArgs: <Object>[noteId],
    );
    return rows.map((Map<String, Object?> r) => r['labelId'] as String).toList();
  }

  Future<Map<String, List<String>>> getLabelIdsForNotes(List<String> noteIds) async {
    if (noteIds.isEmpty) return <String, List<String>>{};
    final Database db = await _db.database;
    final String placeholders = List<String>.filled(noteIds.length, '?').join(',');
    final List<Map<String, Object?>> rows = await db.query(
      'note_labels',
      where: 'noteId IN ($placeholders)',
      whereArgs: noteIds,
    );
    final Map<String, List<String>> grouped = <String, List<String>>{};
    for (final Map<String, Object?> r in rows) {
      grouped
          .putIfAbsent(r['noteId'] as String, () => <String>[])
          .add(r['labelId'] as String);
    }
    return grouped;
  }

  Future<void> setLabelsForNote(String noteId, List<String> labelIds) async {
    final Database db = await _db.database;
    await db.transaction((Transaction txn) async {
      await txn.delete('note_labels', where: 'noteId = ?', whereArgs: <Object>[noteId]);
      final Batch batch = txn.batch();
      for (final String labelId in labelIds.toSet()) {
        batch.insert('note_labels', <String, Object?>{
          'noteId': noteId,
          'labelId': labelId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<Map<String, int>> labelCounts() async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT l.id AS labelId, COUNT(nl.noteId) AS c '
      'FROM labels l LEFT JOIN note_labels nl ON nl.labelId = l.id '
      'LEFT JOIN notes n ON n.id = nl.noteId AND n.isTrashed = 0 '
      'GROUP BY l.id',
    );
    final Map<String, int> result = <String, int>{};
    for (final Map<String, Object?> r in rows) {
      result[r['labelId'] as String] = (r['c'] as int?) ?? 0;
    }
    return result;
  }

  // --- Search -----------------------------------------------------------------

  Future<List<Note>> search(String query) async {
    final String q = query.trim();
    if (q.isEmpty) return <Note>[];
    final Database db = await _db.database;
    final String like = '%${q.replaceAll('%', r'\%')}%';
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT DISTINCT n.* FROM notes n '
      'LEFT JOIN checklist_items c ON c.noteId = n.id '
      'LEFT JOIN note_labels nl ON nl.noteId = n.id '
      'LEFT JOIN labels l ON l.id = nl.labelId '
      'WHERE n.isTrashed = 0 AND n.isArchived = 0 AND ('
      '  n.title LIKE ? COLLATE NOCASE OR '
      '  n.body LIKE ? COLLATE NOCASE OR '
      '  c.text LIKE ? COLLATE NOCASE OR '
      '  l.name LIKE ? COLLATE NOCASE) '
      'ORDER BY n.updatedAt DESC',
      <Object>[like, like, like, like],
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<void> addSearchTerm(String term) async {
    final String t = term.trim();
    if (t.isEmpty) return;
    final Database db = await _db.database;
    await db.insert(
      'search_history',
      <String, Object?>{'term': t, 'createdAt': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<String>> getSearchHistory({int limit = 12}) async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows = await db.query(
      'search_history',
      columns: <String>['term'],
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return rows.map((Map<String, Object?> r) => r['term'] as String).toList();
  }

  Future<void> clearSearchHistory() async {
    final Database db = await _db.database;
    await db.delete('search_history');
  }

  // --- Bulk import (backup restore) ------------------------------------------

  Future<void> importNotes(List<Note> notes) async {
    final Database db = await _db.database;
    await db.transaction((Transaction txn) async {
      final Batch batch = txn.batch();
      for (final Note n in notes) {
        batch.insert('notes', n.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }
}
