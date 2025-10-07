// lib/screens/task_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/task_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final String parentId;
  final String title;
  final bool isGuest;
  final VoidCallback? onChanged;

  const TaskDetailScreen({
    super.key,
    required this.parentId,
    required this.title,
    required this.isGuest,
    this.onChanged,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final TaskService _service = TaskService();
  final TextEditingController _subController = TextEditingController();
  List<Map<String, dynamic>> _localSubtasks = [];
  bool _loadingLocal = true;

  @override
  void initState() {
    super.initState();
    if (widget.isGuest) _loadLocal();
  }

  Future<void> _loadLocal() async {
    setState(() => _loadingLocal = true);
    final tasks = await _service.getGuestTasksWithSubtasks();
    final found = tasks.firstWhere((t) => t['id'] == widget.parentId, orElse: () => {});
    if (found.isNotEmpty) {
      _localSubtasks = List<Map<String, dynamic>>.from(found['subtasks'] ?? []);
    } else {
      _localSubtasks = [];
    }
    setState(() => _loadingLocal = false);
  }

  Future<void> _addSubtask() async {
    final text = _subController.text.trim();
    if (text.isEmpty) return;
    _subController.clear();
    if (widget.isGuest) {
      await _service.addGuestSubtask(widget.parentId, text);
      await _loadLocal();
      widget.onChanged?.call();
    } else {
      await _service.addUserSubtask(widget.parentId, text);
    }
  }

  Future<void> _toggleSub(String subId, bool done) async {
    if (widget.isGuest) {
      await _service.toggleGuestSubtaskDone(subId, widget.parentId, !done);
      await _loadLocal();
      widget.onChanged?.call();
    } else {
      await _service.toggleUserSubtaskDone(widget.parentId, subId, !done);
    }
  }

  Future<void> _deleteSub(String subId) async {
    if (widget.isGuest) {
      await _service.deleteGuestSubtask(subId, widget.parentId);
      await _loadLocal();
      widget.onChanged?.call();
    } else {
      await _service.deleteUserSubtask(widget.parentId, subId);
    }
  }

  Widget _animatedCheck(bool done) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
      child: done
          ? Icon(Icons.check_box, key: const ValueKey('checked'), color: Colors.deepPurple)
          : Icon(Icons.check_box_outline_blank, key: const ValueKey('unchecked'), color: Colors.grey),
    );
  }

  Widget _buildLocalList() {
    if (_loadingLocal) return const Center(child: CircularProgressIndicator());
    if (_localSubtasks.isEmpty) return const Center(child: Text('No subtasks yet'));
    return ListView.builder(
      itemCount: _localSubtasks.length,
      itemBuilder: (context, i) {
        final sub = _localSubtasks[i];
        final done = sub['done'] as bool;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: InkWell(onTap: () => _toggleSub(sub['id'], done), child: _animatedCheck(done)),
            title: Text(sub['title'], style: TextStyle(decoration: done ? TextDecoration.lineThrough : null)),
            trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteSub(sub['id'])),
          ),
        );
      },
    );
  }

  Widget _buildRemoteList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.getUserSubtasksStream(widget.parentId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('No subtasks yet'));
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            final done = (data['done'] ?? false) as bool;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: InkWell(onTap: () => _toggleSub(d.id, done), child: _animatedCheck(done)),
                title: Text(data['title'] ?? '', style: TextStyle(decoration: done ? TextDecoration.lineThrough : null)),
                trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteSub(d.id)),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), backgroundColor: Colors.deepPurple, centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _subController,
                decoration: InputDecoration(
                  hintText: 'Add a subtask...',
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onSubmitted: (_) => _addSubtask(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _addSubtask, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple), child: const Icon(Icons.add)),
          ]),
          const SizedBox(height: 16),
          Expanded(child: widget.isGuest ? _buildLocalList() : _buildRemoteList()),
        ]),
      ),
    );
  }
}
