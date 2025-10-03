import 'package:sqflite/sqflite.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart';

class SummaryDb {
  static final SummaryDb instance = SummaryDb._init();
  static Database? _database;

  SummaryDb._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB("summaries.db");
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE summaries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fileName TEXT,
          summary TEXT,
          createdAt TEXT
        )
        ''');
      },
    );
  }

  Future<int> insertSummary(String fileName, String summary) async {
    final db = await instance.database;
    return await db.insert("summaries", {
      "fileName": fileName,
      "summary": summary,
      "createdAt": DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getSummaries() async {
    final db = await instance.database;
    return await db.query("summaries", orderBy: "createdAt DESC");
  }

  Future<int> deleteSummary(int id) async {
    final db = await instance.database;
    return await db.delete("summaries", where: "id = ?", whereArgs: [id]);
  }
}
