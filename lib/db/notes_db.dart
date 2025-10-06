// Add these methods to your NotesDB class

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class NotesDB {
  static Database? _database;
  
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'notes.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            content TEXT,
            createdAt TEXT
          )
        ''');
      },
    );
  }

  static Future<int> addNote(Map<String, dynamic> note) async {
    final db = await database;
    return await db.insert('notes', note);
  }

  static Future<List<Map<String, dynamic>>> getNotes() async {
    final db = await database;
    return await db.query('notes', orderBy: 'createdAt DESC');
  }

  // NEW METHOD: Update a note
  static Future<int> updateNote(int id, Map<String, dynamic> note) async {
    final db = await database;
    return await db.update(
      'notes',
      note,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // NEW METHOD: Delete a note
  static Future<int> deleteNote(int id) async {
    final db = await database;
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> close() async {
    final db = await database;
    await db.close();
  }
}