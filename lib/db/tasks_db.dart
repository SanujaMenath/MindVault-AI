import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class TasksDB {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'guest_tasks.db');

    _db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        // enable foreign keys (defensive; we still delete subtasks explicitly)
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            done INTEGER NOT NULL DEFAULT 0,
            timestamp INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE subtasks(
            id TEXT PRIMARY KEY,
            parentId TEXT NOT NULL,
            title TEXT NOT NULL,
            done INTEGER NOT NULL DEFAULT 0,
            timestamp INTEGER,
            FOREIGN KEY(parentId) REFERENCES tasks(id) ON DELETE CASCADE
          )
        ''');
      },
    );
    return _db!;
  }

  // Insert main task
  static Future<void> insertTask(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert('tasks', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Insert subtask
  static Future<void> insertSubtask(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert('subtasks', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Update task (title/done)
  static Future<void> updateTask(String id, Map<String, dynamic> values) async {
    final db = await database;
    await db.update('tasks', values, where: 'id = ?', whereArgs: [id]);
  }

  // Update subtask
  static Future<void> updateSubtask(String id, Map<String, dynamic> values) async {
    final db = await database;
    await db.update('subtasks', values, where: 'id = ?', whereArgs: [id]);
  }

  // Delete task (and subtasks)
  static Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete('subtasks', where: 'parentId = ?', whereArgs: [id]);
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // Delete subtask
  static Future<void> deleteSubtask(String id) async {
    final db = await database;
    await db.delete('subtasks', where: 'id = ?', whereArgs: [id]);
  }

  // Read all tasks with subtasks
  static Future<List<Map<String, dynamic>>> getTasksWithSubtasks() async {
    final db = await database;
    final tasks = await db.query('tasks', orderBy: 'timestamp DESC');

    final List<Map<String, dynamic>> out = [];
    for (final t in tasks) {
      final subs = await db.query(
        'subtasks',
        where: 'parentId = ?',
        whereArgs: [t['id']],
        orderBy: 'timestamp DESC',
      );
      out.add({
        'id': t['id'],
        'title': t['title'],
        'done': (t['done'] as int) == 1,
        'timestamp': t['timestamp'],
        'subtasks': subs
            .map((s) => {
                  'id': s['id'],
                  'parentId': s['parentId'],
                  'title': s['title'],
                  'done': (s['done'] as int) == 1,
                  'timestamp': s['timestamp']
                })
            .toList(),
      });
    }
    return out;
  }

  // Get only subtasks for a parent
  static Future<List<Map<String, dynamic>>> getSubtasks(String parentId) async {
    final db = await database;
    final subs = await db.query('subtasks', where: 'parentId = ?', whereArgs: [parentId], orderBy: 'timestamp DESC');
    return subs
        .map((s) => {
              'id': s['id'],
              'parentId': s['parentId'],
              'title': s['title'],
              'done': (s['done'] as int) == 1,
              'timestamp': s['timestamp']
            })
        .toList();
  }

  // Clear local DB (used after sync)
  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('subtasks');
    await db.delete('tasks');
  }
}
