// lib/screens/tasks_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/task_service.dart';
import 'task_detail_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TaskService _service = TaskService();
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _guestTasks = [];
  User? _user;
  bool _loadingGuest = true;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    if (_user == null) _loadGuest();
    // listen auth changes to refresh UI / optionally sync
    FirebaseAuth.instance.authStateChanges().listen((u) async {
      setState(() => _user = u);
      if (u != null) {
        // sync any guest data automatically
        await _service.syncGuestTasksToUser();
        setState(() {}); // refresh to use streams
      } else {
        await _loadGuest();
      }
    });
  }

  Future<void> _loadGuest() async {
    setState(() => _loadingGuest = true);
    _guestTasks = await _service.getGuestTasksWithSubtasks();
    setState(() => _loadingGuest = false);
  }

  Future<void> _addTask() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    if (_user == null) {
      await _service.addGuestTask(text);
      await _loadGuest();
    } else {
      await _service.addUserTask(text);
    }
  }

  Future<void> _deleteTask(String id) async {
    if (_user == null) {
      await _service.deleteGuestTask(id);
      await _loadGuest();
    } else {
      await _service.deleteUserTask(id);
    }
  }

  Future<void> _toggleTask(String id, bool currentDone) async {
    if (_user == null) {
      await _service.toggleGuestTaskDone(id, !currentDone);
      await _loadGuest();
    } else {
      await _service.toggleUserTaskDone(id, !currentDone);
    }
  }

  Widget _animatedCheck(bool done) {
    // animated icon for tick/untick
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: anim,
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: done
          ? Icon(
              Icons.check_box,
              key: const ValueKey('checked'),
              color: Colors.deepPurple,
            )
          : Icon(
              Icons.check_box_outline_blank,
              key: const ValueKey('unchecked'),
              color: Colors.grey,
            ),
    );
  }

  Widget _buildLocalCard(Map<String, dynamic> task) {
    final done = task['done'] as bool;
    final subs = task['subtasks'] as List<dynamic>;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskDetailScreen(
                parentId: task['id'],
                title: task['title'],
                isGuest: true,
                onChanged: _loadGuest,
              ),
            ),
          );
          await _loadGuest();
        },
        leading: InkWell(
          onTap: () => _toggleTask(task['id'], done),
          child: _animatedCheck(done),
        ),
        title: Text(
          task['title'],
          style: TextStyle(
            decoration: done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text('${subs.length} subtasks'),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteTask(task['id']),
        ),
      ),
    );
  }

  Widget _buildRemoteCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final done = (data['done'] ?? false) as bool;
    final title = data['title'] ?? '';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskDetailScreen(
                parentId: doc.id,
                title: title,
                isGuest: false,
                onChanged: () {},
              ),
            ),
          );
        },
        leading: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _service.getUserSubtasksStream(doc.id),
          builder: (context, snap) {
            final subs = snap.hasData ? snap.data!.docs : [];
            return InkWell(
              onTap: () => _toggleTask(doc.id, done),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _animatedCheck(done),
                  Text('${subs.length}', style: const TextStyle(fontSize: 10)),
                ],
              ),
            );
          },
        ),
        title: Text(
          title,
          style: TextStyle(
            decoration: done ? TextDecoration.lineThrough : null,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteTask(doc.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Tasks'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Add a main task...',
                      filled: true,
                      fillColor: theme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _user != null
                  ? StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _service.getUserTasksStream(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = snap.data?.docs ?? [];

                        if (docs.isEmpty) {
                          return const Center(child: Text('No tasks yet'));
                        }

                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (ctx, i) => _buildRemoteCard(docs[i]),
                        );
                      },
                    )
                  : _loadingGuest
                  ? const Center(child: CircularProgressIndicator())
                  : _guestTasks.isEmpty
                  ? const Center(child: Text('No tasks yet (guest)'))
                  : RefreshIndicator(
                      onRefresh: _loadGuest,
                      child: ListView.builder(
                        itemCount: _guestTasks.length,
                        itemBuilder: (ctx, i) =>
                            _buildLocalCard(_guestTasks[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
