import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the SQLite database: creation, schema and forward-only migrations.
///
/// This is the single source of truth for persisted notes (Spec §8). It is a
/// real on-disk database — not an in-memory list — so data survives restarts.
class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _dbName = 'notenest.db';
  static const int _dbVersion = 3;

  Database? _db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final String path = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (Database db, int version) async {
        await _createV1(db);
        await _migrateTo2(db);
        await _migrateTo3(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        // Forward-only, ordered migrations. Never destructive.
        if (oldVersion < 2) await _migrateTo2(db);
        if (oldVersion < 3) await _migrateTo3(db);
      },
    );
  }

  // --- Schema -----------------------------------------------------------------

  Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        body TEXT NOT NULL DEFAULT '',
        type INTEGER NOT NULL DEFAULT 0,
        color INTEGER NOT NULL DEFAULT 0,
        isPinned INTEGER NOT NULL DEFAULT 0,
        isFavorite INTEGER NOT NULL DEFAULT 0,
        isArchived INTEGER NOT NULL DEFAULT 0,
        isTrashed INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        trashedAt INTEGER,
        reminderAt INTEGER,
        recurrence TEXT NOT NULL DEFAULT 'none',
        notificationId INTEGER,
        linkUrl TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE checklist_items (
        id TEXT PRIMARY KEY,
        noteId TEXT NOT NULL,
        text TEXT NOT NULL DEFAULT '',
        isDone INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (noteId) REFERENCES notes (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE labels (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE note_labels (
        noteId TEXT NOT NULL,
        labelId TEXT NOT NULL,
        PRIMARY KEY (noteId, labelId),
        FOREIGN KEY (noteId) REFERENCES notes (id) ON DELETE CASCADE,
        FOREIGN KEY (labelId) REFERENCES labels (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE attachments (
        id TEXT PRIMARY KEY,
        noteId TEXT NOT NULL,
        type INTEGER NOT NULL DEFAULT 3,
        path TEXT NOT NULL,
        mimeType TEXT,
        durationMs INTEGER,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (noteId) REFERENCES notes (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE search_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        term TEXT NOT NULL UNIQUE,
        createdAt INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE meta (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX idx_notes_updated ON notes (updatedAt DESC)');
    await db.execute('CREATE INDEX idx_notes_flags ON notes (isTrashed, isArchived, isPinned)');
    await db.execute('CREATE INDEX idx_checklist_note ON checklist_items (noteId, position)');
    await db.execute('CREATE INDEX idx_attach_note ON attachments (noteId)');
    await db.execute('CREATE INDEX idx_notelabels_note ON note_labels (noteId)');
  }

  /// v2 — favourites were split out from pins (Spec §5).
  Future<void> _migrateTo2(Database db) async {
    // Column already present in v1 create; guard for older installs.
    final List<Map<String, Object?>> cols =
        await db.rawQuery('PRAGMA table_info(notes)');
    final bool hasFav = cols.any((Map<String, Object?> c) => c['name'] == 'isFavorite');
    if (!hasFav) {
      await db.execute('ALTER TABLE notes ADD COLUMN isFavorite INTEGER NOT NULL DEFAULT 0');
    }
  }

  /// v3 — track when a note entered the trash so it can auto-purge (Spec §5).
  Future<void> _migrateTo3(Database db) async {
    final List<Map<String, Object?>> cols =
        await db.rawQuery('PRAGMA table_info(notes)');
    final bool hasTrashedAt =
        cols.any((Map<String, Object?> c) => c['name'] == 'trashedAt');
    if (!hasTrashedAt) {
      await db.execute('ALTER TABLE notes ADD COLUMN trashedAt INTEGER');
    }
  }

  // --- Maintenance ------------------------------------------------------------

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Danger: wipes every row. Used by "Clear local data" (Spec §12).
  Future<void> wipe() async {
    final Database db = await database;
    await db.delete('attachments');
    await db.delete('checklist_items');
    await db.delete('note_labels');
    await db.delete('labels');
    await db.delete('notes');
    await db.delete('search_history');
  }

  Future<String> readMeta(String key) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows =
        await db.query('meta', where: 'key = ?', whereArgs: <Object>[key], limit: 1);
    if (rows.isEmpty) return '';
    return (rows.first['value'] as String?) ?? '';
  }

  Future<void> writeMeta(String key, String value) async {
    final Database db = await database;
    await db.insert(
      'meta',
      <String, Object?>{'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
