import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/task_service.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TextEditingController _controller = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TaskService _taskService = TaskService();

  List<Map<String, dynamic>> _guestTasks = [];

  User? get currentUser => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _loadGuestTasks();
  }

  Future<void> _loadGuestTasks() async {
    if (currentUser == null) {
      final tasks = await _taskService.getGuestTasks();
      setState(() => _guestTasks = tasks);
    }
  }

  Future<void> _addTask() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _taskService.addTask(id, text);
    if (currentUser == null) {
      await _loadGuestTasks(); // refresh guest list
    }

    _controller.clear();
  }

  Future<void> _deleteTask(String id) async {
    await _taskService.deleteTask(id);
    if (currentUser == null) {
      await _loadGuestTasks(); // refresh guest list
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Tasks"),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Input row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Enter a new task...",
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
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Task list
            Expanded(
              child: currentUser != null
                  ? StreamBuilder<QuerySnapshot>(
                      stream: _taskService.getUserTasks(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return const Center(child: Text("No tasks yet"));
                        }
                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final task = docs[index];
                            return _buildTaskTile(
                              task['title'],
                              task.id,
                              colorScheme,
                            );
                          },
                        );
                      },
                    )
                  : _guestTasks.isEmpty
                      ? const Center(child: Text("No tasks yet (guest mode)"))
                      : ListView.builder(
                          itemCount: _guestTasks.length,
                          itemBuilder: (context, index) {
                            final task = _guestTasks[index];
                            return _buildTaskTile(
                              task['title'],
                              task['id'],
                              colorScheme,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTile(String title, String id, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.check_circle_outline, color: colorScheme.primary),
        title: Text(title),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteTask(id),
        ),
      ),
    );
  }
}