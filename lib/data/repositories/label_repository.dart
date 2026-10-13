import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../models/label.dart';

/// CRUD for user labels (Spec §5).
class LabelRepository {
  LabelRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<List<Label>> getAll() async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows =
        await db.query('labels', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Label.fromMap).toList();
  }

  Future<void> insert(Label label) async {
    final Database db = await _db.database;
    await db.insert('labels', label.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Label label) async {
    final Database db = await _db.database;
    await db.update('labels', label.toMap(),
        where: 'id = ?', whereArgs: <Object>[label.id]);
  }

  Future<void> delete(String id) async {
    final Database db = await _db.database;
    await db.delete('labels', where: 'id = ?', whereArgs: <Object>[id]);
  }
}
