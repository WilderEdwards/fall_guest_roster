import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Instance-based SQLite helper for the Fall Festival roster + catalogue.
///
/// Part I table ([table]) is preserved. Part II adds [foldersTable] and
/// [cardsTable] with a foreign key and an index. Version 2 upgrades a
/// version-1 database without deleting Part I rows.
class DatabaseHelper {
  static const _databaseName = 'MyDatabase.db';
  static const _databaseVersion = 2;

  // Part I (guest roster) — do not rename or drop.
  static const table = 'my_table';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';

  // Part II (folder catalogue).
  static const foldersTable = 'folders';
  static const folderId = 'id';
  static const folderName = 'name';
  static const folderCreatedAt = 'created_at';

  static const cardsTable = 'cards';
  static const cardId = 'id';
  static const cardTitle = 'title';
  static const cardSuit = 'suit';
  static const cardNotes = 'notes';
  static const cardImageRef = 'image_ref';
  static const cardFolderId = 'folder_id';

  late Database _db;

  /// Opens (creating or upgrading if needed) the database.
  /// Must be awaited before any CRUD operation.
  Future<void> init() async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final String path = join(documentsDirectory.path, _databaseName);
    _db = await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        // Foreign keys must be enabled on each connection.
        // The CASCADE rule below does nothing without this line.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        // Fresh install: build both Part I and Part II tables.
        // This callback already runs inside a transaction,
        // so do not start db.transaction() here.
        await createPartOneTables(db);
        await createCatalogueTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Upgrade keeps Part I rows. Only add what is missing.
        if (oldVersion < 2) {
          await createCatalogueTables(db);
        }
      },
    );
  }

  /// Original Part I table. Reused by onCreate so fresh installs
  /// get the same guest schema as before.
  Future<void> createPartOneTables(Database db) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnAge INTEGER NOT NULL
      )
      ''');
  }

  /// New Part II tables + index. Called from onCreate (fresh)
  /// or onUpgrade (existing v1 database). One execute per statement.
  Future<void> createCatalogueTables(Database db) async {
    await db.execute('''
      CREATE TABLE $foldersTable (
        $folderId INTEGER PRIMARY KEY AUTOINCREMENT,
        $folderName TEXT NOT NULL UNIQUE,
        $folderCreatedAt TEXT NOT NULL
      )
      ''');
    await db.execute('''
      CREATE TABLE $cardsTable (
        $cardId INTEGER PRIMARY KEY AUTOINCREMENT,
        $cardTitle TEXT NOT NULL,
        $cardSuit TEXT NOT NULL,
        $cardNotes TEXT NOT NULL DEFAULT '',
        $cardImageRef TEXT,
        $cardFolderId INTEGER NOT NULL,
        FOREIGN KEY ($cardFolderId)
          REFERENCES $foldersTable($folderId) ON DELETE CASCADE
      )
      ''');
    await db.execute('''
      CREATE INDEX idx_cards_folder_id ON $cardsTable($cardFolderId)
      ''');
  }

  // ---------- Part I CRUD (unchanged behavior) ----------

  /// Inserts a guest row without an [_id] so SQLite auto-assigns it.
  Future<int> insert(Map<String, dynamic> row) async {
    return await _db.insert(table, row);
  }

  /// Returns all guest rows ordered by id ascending.
  Future<List<Map<String, dynamic>>> queryAllRows() async {
    return await _db.query(table, orderBy: '$columnId ASC');
  }

  /// Returns the number of guest rows.
  Future<int> queryRowCount() async {
    final List<Map<String, Object?>> result =
        await _db.rawQuery('SELECT COUNT(*) FROM $table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Updates the single guest row whose [_id] is in [row].
  Future<int> update(Map<String, dynamic> row) async {
    final int id = row[columnId] as int;
    return await _db.update(
      table,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  /// Deletes the guest row with [id].
  Future<int> delete(int id) async {
    return await _db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // ---------- Part II repository (folders + cards) ----------

  /// Creates a folder. Caller trims and checks for empty first.
  /// Throws on duplicate name (UNIQUE). No ConflictAlgorithm.replace
  /// here — replacing a parent could cascade-delete its cards.
  Future<int> insertFolder(String name) async {
    return await _db.insert(foldersTable, {
      folderName: name,
      folderCreatedAt: DateTime.now().toIso8601String(),
    });
  }

  /// Lists every folder with its card count.
  /// LEFT JOIN keeps empty folders with count 0.
  Future<List<Map<String, dynamic>>> getFoldersWithCounts() async {
    return await _db.rawQuery('''
      SELECT f.$folderId AS $folderId,
             f.$folderName AS $folderName,
             f.$folderCreatedAt AS $folderCreatedAt,
             COUNT(c.$cardId) AS card_count
      FROM $foldersTable f
      LEFT JOIN $cardsTable c ON c.$cardFolderId = f.$folderId
      GROUP BY f.$folderId
      ORDER BY f.$folderName COLLATE NOCASE ASC
    ''');
  }

  /// Returns the cards in one folder, sorted A–Z (case-insensitive).
  Future<List<Map<String, dynamic>>> getCards(int folderIdValue) async {
    final rows = await _db.query(
      cardsTable,
      where: '$cardFolderId = ?',
      whereArgs: [folderIdValue],
      orderBy: '$cardTitle COLLATE NOCASE ASC',
    );
    return rows;
  }

  /// Inserts a card. [imageRef] may be null (stored as SQL NULL).
  /// Notes should be '' when omitted. Returns the new card id.
  Future<int> insertCard({
    required String title,
    required String suit,
    required String notes,
    String? imageRef,
    required int folderIdValue,
  }) async {
    return await _db.insert(cardsTable, {
      cardTitle: title,
      cardSuit: suit,
      cardNotes: notes,
      cardImageRef: imageRef,
      cardFolderId: folderIdValue,
    });
  }

  /// Updates one card by id. Returns affected rows (1 or 0).
  Future<int> updateCard({
    required int id,
    required String title,
    required String suit,
    required String notes,
    String? imageRef,
    required int folderIdValue,
  }) async {
    final affected = await _db.update(
      cardsTable,
      {
        cardTitle: title,
        cardSuit: suit,
        cardNotes: notes,
        cardImageRef: imageRef,
        cardFolderId: folderIdValue,
      },
      where: '$cardId = ?',
      whereArgs: [id],
    );
    return affected;
  }

  /// Deletes one card by id. Returns affected rows (1 or 0).
  Future<int> deleteCard(int cardIdValue) async {
    final affected = await _db.delete(
      cardsTable,
      where: '$cardId = ?',
      whereArgs: [cardIdValue],
    );
    return affected;
  }

  /// Deletes one folder by id. Its cards go away too (ON DELETE CASCADE).
  /// Returns deleted parent rows (1 or 0). Never test on real data.
  Future<int> deleteFolder(int folderIdValue) async {
    return await _db.delete(
      foldersTable,
      where: '$folderId = ?',
      whereArgs: [folderIdValue],
    );
  }

  // ---------- Read-only diagnostics for T1 evidence ----------

  Future<int?> getUserVersion() async {
    final rows = await _db.rawQuery('PRAGMA user_version');
    if (rows.isEmpty) return null;
    return rows.first.values.first as int?;
  }

  Future<int?> getForeignKeysOn() async {
    final rows = await _db.rawQuery('PRAGMA foreign_keys');
    if (rows.isEmpty) return null;
    return Sqflite.firstIntValue(rows);
  }

  Future<List<Map<String, dynamic>>> getCardForeignKeys() async {
    return await _db.rawQuery('PRAGMA foreign_key_list($cardsTable)');
  }

  Future<List<Map<String, dynamic>>> getCardIndexes() async {
    return await _db.rawQuery('PRAGMA index_list($cardsTable)');
  }
}
