import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/database_helper.dart';
import '../models/attachment.dart';
import '../models/checklist_item.dart';
import '../models/label.dart';
import '../models/note.dart';
import 'file_storage_service.dart';

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BackupSummary {
  BackupSummary({
    required this.notes,
    required this.labels,
    required this.attachments,
    required this.createdAt,
  });
  final int notes;
  final int labels;
  final int attachments;
  final DateTime createdAt;
}

/// Exports and imports a full archive of notes + attachments (Spec §10).
///
/// The archive is a plain zip: `manifest.json`, `data.json` and a `files/`
/// folder. Imports are validated before anything touches the database.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const String _manifestName = 'manifest.json';
  static const String _dataName = 'data.json';
  static const int _formatVersion = 1;

  final DatabaseHelper _db = DatabaseHelper.instance;

  // --- Export -----------------------------------------------------------------

  Future<BackupSummary> exportBackup() async {
    final File zip = await _buildArchive();

    final String? target = await FilePicker.platform.saveFile(
      dialogTitle: 'Save NoteNest backup',
      fileName: 'notenest-backup-${_stamp()}.zip',
      type: FileType.custom,
      allowedExtensions: <String>['zip'],
      bytes: await zip.readAsBytes(),
    );
    if (target == null) {
      throw BackupException('Backup cancelled');
    }
    final Map<String, dynamic> manifest =
        jsonDecode(utf8.decode(await _readZipEntry(zip, _manifestName)))
            as Map<String, dynamic>;
    return BackupSummary(
      notes: manifest['notes'] as int? ?? 0,
      labels: manifest['labels'] as int? ?? 0,
      attachments: manifest['attachments'] as int? ?? 0,
      createdAt: DateTime.parse(manifest['createdAt'] as String),
    );
  }

  /// Builds the archive in the temp directory and returns the file.
  Future<File> _buildArchive() async {
    final db = await _db.database;
    final List<Map<String, Object?>> notes = await db.query('notes');
    final List<Map<String, Object?>> checklist = await db.query('checklist_items');
    final List<Map<String, Object?>> labels = await db.query('labels');
    final List<Map<String, Object?>> noteLabels = await db.query('note_labels');
    final List<Map<String, Object?>> attachments = await db.query('attachments');

    final Map<String, dynamic> payload = <String, dynamic>{
      'notes': notes,
      'checklistItems': checklist,
      'labels': labels,
      'noteLabels': noteLabels,
      'attachments': attachments,
    };

    final Archive archive = Archive();
    final List<int> dataBytes = utf8.encode(jsonEncode(payload));
    archive.addFile(ArchiveFile(_dataName, dataBytes.length, dataBytes));

    // Bundle attachment files alongside their metadata.
    for (final Map<String, Object?> a in attachments) {
      final String path = (a['path'] as String?) ?? '';
      final File file = File(path);
      if (await file.exists()) {
        final List<int> bytes = await file.readAsBytes();
        final String name = 'files/${a['id']}_${p.basename(path)}';
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }
    }

    final Map<String, dynamic> manifest = <String, dynamic>{
      'app': 'NoteNest',
      'formatVersion': _formatVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'notes': notes.length,
      'labels': labels.length,
      'attachments': attachments.length,
    };
    final List<int> manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile(_manifestName, manifestBytes.length, manifestBytes));

    final List<int>? zipped = ZipEncoder().encode(archive);
    if (zipped == null) throw BackupException('Could not build the archive');

    final Directory tmp = await getTemporaryDirectory();
    final File out = File(p.join(tmp.path, 'notenest-backup-${_stamp()}.zip'));
    await out.writeAsBytes(zipped, flush: true);
    return out;
  }

  // --- Import -----------------------------------------------------------------

  /// Lets the user choose a backup file and validates it without writing.
  Future<File?> pickBackup() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['zip'],
    );
    final String? path = result?.files.single.path;
    if (path == null) return null;
    return File(path);
  }

  Future<BackupSummary> validate(File zip) async {
    if (!await zip.exists()) {
      throw BackupException('Backup file not found');
    }
    final Map<String, dynamic> manifest = await _readManifest(zip);
    if (manifest['app'] != 'NoteNest') {
      throw BackupException('Not a NoteNest backup');
    }
    final int version = manifest['formatVersion'] as int? ?? 0;
    if (version > _formatVersion) {
      throw BackupException('This backup was made with a newer version');
    }
    return BackupSummary(
      notes: manifest['notes'] as int? ?? 0,
      labels: manifest['labels'] as int? ?? 0,
      attachments: manifest['attachments'] as int? ?? 0,
      createdAt: DateTime.tryParse(manifest['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Restores [zip]. When [replace] is true existing notes are removed first;
  /// otherwise rows are merged by id (Spec §10).
  Future<BackupSummary> restore(File zip, {required bool replace}) async {
    final BackupSummary summary = await validate(zip);
    final Map<String, dynamic> payload = await _readPayload(zip);

    final Database db = await _db.database;
    final Directory attachmentsDir = await FileStorageService.instance.attachmentsDir();

    // Extract files first so metadata can point at real paths.
    final Archive archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    final Map<String, String> restoredPaths = <String, String>{};
    for (final ArchiveFile file in archive) {
      if (!file.isFile) continue;
      if (!file.name.startsWith('files/')) continue;
      final String base = p.basename(file.name);
      final String id = base.contains('_') ? base.split('_').first : base;
      final String dest = p.join(attachmentsDir.path, base);
      await File(dest).writeAsBytes(file.content as List<int>, flush: true);
      restoredPaths[id] = dest;
    }

    await db.transaction((txn) async {
      if (replace) {
        await txn.delete('attachments');
        await txn.delete('checklist_items');
        await txn.delete('note_labels');
        await txn.delete('labels');
        await txn.delete('notes');
      }
      await _insertAll(txn, 'notes', payload['notes']);
      await _insertAll(txn, 'checklist_items', payload['checklistItems']);
      await _insertAll(txn, 'labels', payload['labels']);
      await _insertAll(txn, 'note_labels', payload['noteLabels']);
      await _insertAttachments(txn, payload['attachments'], restoredPaths);
    });

    return summary;
  }

  Future<void> _insertAll(
      Transaction txn, String table, dynamic rows) async {
    if (rows is! List) return;
    for (final dynamic row in rows) {
      if (row is Map) {
        await txn.insert(table, Map<String, Object?>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  Future<void> _insertAttachments(
      Transaction txn, dynamic rows, Map<String, String> restoredPaths) async {
    if (rows is! List) return;
    for (final dynamic row in rows) {
      if (row is! Map) continue;
      final Map<String, Object?> map = Map<String, Object?>.from(row);
      final String id = (map['id'] as String?) ?? '';
      if (restoredPaths.containsKey(id)) {
        map['path'] = restoredPaths[id];
      }
      await txn.insert('attachments', map,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // --- Single-note text export (Spec §7/§10) ----------------------------------

  String noteAsText(Note note, List<ChecklistItem> items, List<Label> labels) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln(note.displayTitle);
    buffer.writeln('=' * note.displayTitle.length);
    if (labels.isNotEmpty) {
      buffer.writeln('Labels: ${labels.map((Label l) => l.name).join(', ')}');
    }
    buffer.writeln();
    if (note.type == NoteType.checklist) {
      for (final ChecklistItem item in items) {
        buffer.writeln('${item.isDone ? '[x]' : '[ ]'} ${item.text}');
      }
    } else {
      if (note.linkUrl != null) buffer.writeln(note.linkUrl);
      buffer.writeln(note.body);
    }
    return buffer.toString();
  }

  // --- Helpers ----------------------------------------------------------------

  Future<Map<String, dynamic>> _readManifest(File zip) async {
    final List<int> bytes = await _readZipEntry(zip, _manifestName);
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _readPayload(File zip) async {
    final List<int> bytes = await _readZipEntry(zip, _dataName);
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  Future<List<int>> _readZipEntry(File zip, String name) async {
    final Archive archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    for (final ArchiveFile file in archive) {
      if (file.name == name) return file.content as List<int>;
    }
    throw BackupException('Backup is missing $name');
  }

  String _stamp() {
    final DateTime now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}';
  }
}
