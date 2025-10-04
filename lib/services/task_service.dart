import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class TaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Database? _database;

  Future<User?> get currentUser async => _auth.currentUser;

  // init local SQLite
  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'guest_tasks.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE tasks(id TEXT PRIMARY KEY, title TEXT, timestamp INTEGER)',
        );
      },
    );
    return _database!;
  }

  // --- FIRESTORE LOGIC ---
  Future<void> addTask(String id, String title) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .doc(id)
          .set({
        'title': title,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      await insertGuestTask(id, title);
    }
  }

  Future<void> deleteTask(String id) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .doc(id)
          .delete();
    } else {
      await deleteGuestTask(id);
    }
  }

  Stream<QuerySnapshot> getUserTasks() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("No user logged in");
    }
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('tasks')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // --- SQLITE LOGIC ---
  Future<void> insertGuestTask(String id, String title) async {
    final db = await database;
    await db.insert(
      'tasks',
      {
        'id': id,
        'title': title,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getGuestTasks() async {
    final db = await database;
    return db.query('tasks', orderBy: 'timestamp DESC');
  }

  Future<void> deleteGuestTask(String id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // --- NEW FEATURE: SYNC GUEST TASKS TO USER ACCOUNT ---
  Future<void> syncGuestTasksToUser() async {
    final user = _auth.currentUser;
    if (user == null) return; // only sync if logged in

    final db = await database;
    final guestTasks = await db.query('tasks');

    for (final task in guestTasks) {
      final id = task['id'] as String;
      final title = task['title'] as String;
      final timestamp = task['timestamp'] as int?;

      await _db
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .doc(id)
          .set({
        'title': title,
        'timestamp': timestamp != null
            ? Timestamp.fromMillisecondsSinceEpoch(timestamp)
            : FieldValue.serverTimestamp(),
      });
    }

    // after syncing, clear guest tasks
    await db.delete('tasks');
  }
}
