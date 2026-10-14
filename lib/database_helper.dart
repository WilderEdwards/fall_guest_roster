import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Instance-based SQLite helper for the Fall Festival guest roster.
///
/// This is intentionally NOT a singleton: create one instance, call
/// [init] once before any CRUD operation, and reuse that instance.
class DatabaseHelper {
  static const _databaseName = 'MyDatabase.db';
  static const _databaseVersion = 1;

  static const table = 'my_table';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';

  late Database _db;

  /// Opens (creating if needed) the database. Must be awaited before
  /// any [insert], [queryAllRows], [queryRowCount], [update], or [delete].
  Future<void> init() async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final String path = join(documentsDirectory.path, _databaseName);
    _db = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnAge INTEGER NOT NULL
      )
      ''');
  }

  /// Inserts a row without an [_id] so SQLite auto-assigns it.
  /// Returns the generated id. Example:
  /// ```dart
  /// final id = await helper.insert({
  ///   DatabaseHelper.columnName: name,
  ///   DatabaseHelper.columnAge: age,
  /// });
  /// ```
  Future<int> insert(Map<String, dynamic> row) async {
    return await _db.insert(table, row);
  }

  /// Returns all rows ordered by id ascending so the list has a
  /// stable, explainable order.
  Future<List<Map<String, dynamic>>> queryAllRows() async {
    return await _db.query(table, orderBy: '$columnId ASC');
  }

  /// Returns the number of rows in the table.
  Future<int> queryRowCount() async {
    final List<Map<String, Object?>> result =
        await _db.rawQuery('SELECT COUNT(*) FROM $table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Updates the single row whose [_id] is in [row].
  /// Returns the number of rows affected (1 on success, 0 if missing).
  Future<int> update(Map<String, dynamic> row) async {
    final int id = row[columnId] as int;
    return await _db.update(
      table,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  /// Deletes the row with [id]. Returns the number of rows affected.
  Future<int> delete(int id) async {
    return await _db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }
}
