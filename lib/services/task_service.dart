import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;

  Future<void> addTask(String title) async {
    if (user == null) return;
    await _db.collection('tasks').add({
      'title': title,
      'createdAt': FieldValue.serverTimestamp(),
      'userId': user!.uid,
    });
  }

  Stream<QuerySnapshot> getUserTasks() {
    return _db
        .collection('tasks')
        .where('userId', isEqualTo: user?.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
