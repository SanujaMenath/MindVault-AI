import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ReminderDb {
  static final ReminderDb instance = ReminderDb._init();
  static Database? _database;

  ReminderDb._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('reminders.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        dateTime TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        notificationId INTEGER NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  // Create new reminder
  Future<int> createReminder(Map<String, dynamic> reminder) async {
    final db = await database;
    return await db.insert(
      'reminders',
      reminder,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all reminders sorted by date
  Future<List<Map<String, dynamic>>> getReminders() async {
    final db = await database;
    return await db.query(
      'reminders',
      orderBy: 'dateTime ASC',
    );
  }

  // Get reminders for a specific date
  Future<List<Map<String, dynamic>>> getRemindersByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return await db.query(
      'reminders',
      where: 'dateTime BETWEEN ? AND ?',
      whereArgs: [
        startOfDay.toIso8601String(),
        endOfDay.toIso8601String(),
      ],
      orderBy: 'dateTime ASC',
    );
  }

  // Update reminder details
  Future<int> updateReminder(int id, Map<String, dynamic> reminder) async {
    final db = await database;
    return await db.update(
      'reminders',
      reminder,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete reminder
  Future<int> deleteReminder(int id) async {
    final db = await database;
    return await db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Toggle completion status
  Future<int> toggleComplete(int id, bool isCompleted) async {
    final db = await database;
    return await db.update(
      'reminders',
      {'isCompleted': isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Close the database connection
  Future<void> close() async {
  if (_database != null) {
    await _database!.close();
    _database = null;
  }
}

}
