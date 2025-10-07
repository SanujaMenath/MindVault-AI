// lib/services/task_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../db/tasks_db.dart';

class TaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();

  // ---------- Helpers ----------
  CollectionReference<Map<String, dynamic>> _userTasksRef(String uid) =>
      _db.collection('users').doc(uid).collection('tasks');

  // ---------- GUEST (local) wrappers ----------
  Future<List<Map<String, dynamic>>> getGuestTasksWithSubtasks() async {
    return await TasksDB.getTasksWithSubtasks();
  }

  Future<void> addGuestTask(String title) async {
    final id = _uuid.v4();
    await TasksDB.insertTask({
      'id': id,
      'title': title,
      'done': 0,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> addGuestSubtask(String parentId, String title) async {
    final id = _uuid.v4();
    await TasksDB.insertSubtask({
      'id': id,
      'parentId': parentId,
      'title': title,
      'done': 0,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    // update parent done state (if needed)
    await _updateParentDoneFromSubtasksLocal(parentId);
  }

  Future<void> deleteGuestTask(String id) async {
    await TasksDB.deleteTask(id);
  }

  Future<void> deleteGuestSubtask(String id, String parentId) async {
    await TasksDB.deleteSubtask(id);
    await _updateParentDoneFromSubtasksLocal(parentId);
  }

  Future<void> toggleGuestTaskDone(String id, bool done) async {
    await TasksDB.updateTask(id, {'done': done ? 1 : 0});
    if (done) {
      // mark child subtasks done
      final subs = await TasksDB.getSubtasks(id);
      for (final s in subs) {
        await TasksDB.updateSubtask(s['id'] as String, {'done': 1});
      }
    }
  }

  Future<void> toggleGuestSubtaskDone(String id, String parentId, bool done) async {
    await TasksDB.updateSubtask(id, {'done': done ? 1 : 0});
    await _updateParentDoneFromSubtasksLocal(parentId);
  }

  Future<void> _updateParentDoneFromSubtasksLocal(String parentId) async {
    final subs = await TasksDB.getSubtasks(parentId);
    final allDone = subs.isNotEmpty && subs.every((s) => s['done'] == true);
    await TasksDB.updateTask(parentId, {'done': allDone ? 1 : 0});
  }

  // ---------- FIRESTORE (remote) wrappers ----------
  Future<void> addUserTask(String title) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user');
    final id = _uuid.v4();
    await _userTasksRef(user.uid).doc(id).set({
      'title': title,
      'done': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addUserSubtask(String parentId, String title) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user');
    final id = _uuid.v4();
    final taskRef = _userTasksRef(user.uid).doc(parentId);
    await taskRef.collection('subtasks').doc(id).set({
      'title': title,
      'done': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
    await _updateParentDoneFromSubtasksFirestore(parentId);
  }

  Future<void> deleteUserTask(String id) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user');
    // delete subtasks batch + task
    final taskRef = _userTasksRef(user.uid).doc(id);
    final subs = await taskRef.collection('subtasks').get();
    final batch = _db.batch();
    for (final d in subs.docs) batch.delete(d.reference);
    batch.delete(taskRef);
    await batch.commit();
  }

  Future<void> deleteUserSubtask(String parentId, String subId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user');
    final subRef = _userTasksRef(user.uid).doc(parentId).collection('subtasks').doc(subId);
    await subRef.delete();
    await _updateParentDoneFromSubtasksFirestore(parentId);
  }

  Future<void> toggleUserTaskDone(String id, bool done) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user');
    final taskRef = _userTasksRef(user.uid).doc(id);
    await taskRef.update({'done': done});
    if (done) {
      final subs = await taskRef.collection('subtasks').get();
      final batch = _db.batch();
      for (final d in subs.docs) batch.update(d.reference, {'done': true});
      await batch.commit();
    }
  }

  Future<void> toggleUserSubtaskDone(String parentId, String subId, bool done) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user');
    final subRef = _userTasksRef(user.uid).doc(parentId).collection('subtasks').doc(subId);
    await subRef.update({'done': done});
    await _updateParentDoneFromSubtasksFirestore(parentId);
  }

  Future<void> _updateParentDoneFromSubtasksFirestore(String parentId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final subsSnap = await _userTasksRef(user.uid).doc(parentId).collection('subtasks').get();
    final allDone = subsSnap.docs.isNotEmpty && subsSnap.docs.every((d) => (d.data()['done'] ?? false) == true);
    await _userTasksRef(user.uid).doc(parentId).update({'done': allDone});
  }

  // Streams
  Stream<QuerySnapshot<Map<String, dynamic>>> getUserTasksStream() {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user');
    return _userTasksRef(user.uid).orderBy('timestamp', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserSubtasksStream(String parentId) {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user');
    return _userTasksRef(user.uid).doc(parentId).collection('subtasks').orderBy('timestamp', descending: true).snapshots();
  }

  // ---------- SYNC guest -> firestore ----------
  Future<void> syncGuestTasksToUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final local = await TasksDB.getTasksWithSubtasks();
    for (final t in local) {
      final tid = t['id'] as String;
      final title = t['title'] as String;
      final done = t['done'] as bool;
      final timestampInt = t['timestamp'] as int?;
      final timestamp = timestampInt != null ? Timestamp.fromMillisecondsSinceEpoch(timestampInt) : FieldValue.serverTimestamp();

      final taskRef = _userTasksRef(user.uid).doc(tid);
      await taskRef.set({
        'title': title,
        'done': done,
        'timestamp': timestamp,
      });

      final subs = t['subtasks'] as List<dynamic>;
      for (final s in subs) {
        final sid = s['id'] as String;
        final stitle = s['title'] as String;
        final sdone = s['done'] as bool;
        final stimestampInt = s['timestamp'] as int?;
        final stimestamp = stimestampInt != null ? Timestamp.fromMillisecondsSinceEpoch(stimestampInt) : FieldValue.serverTimestamp();

        await taskRef.collection('subtasks').doc(sid).set({
          'title': stitle,
          'done': sdone,
          'timestamp': stimestamp,
        });
      }
    }
    // clear local after sync
    await TasksDB.clearAll();
  }
}
