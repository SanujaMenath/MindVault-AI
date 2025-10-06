import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../db/notes_db.dart';
import '../services/note_service.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _localNotes = [];
  bool _isUser = false;

  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  void _checkUser() {
    final user = _auth.currentUser;
    setState(() => _isUser = user != null);
  }

  Future<void> _loadLocalNotes() async {
    final data = await NotesDB.getNotes();
    setState(() => _localNotes = data);
  }

  void _addNoteDialog() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controllerTitle = TextEditingController();
    final controllerContent = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        title: Row(
          children: [
            Icon(Icons.note_add, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text(
              "Add Note",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controllerTitle,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: "Title",
                labelStyle: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controllerContent,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: "Content",
                labelStyle: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final title = controllerTitle.text.trim();
              final content = controllerContent.text.trim();

              if (title.isEmpty || content.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in both title and content'),
                  ),
                );
                return;
              }

              final note = {
                'title': title,
                'content': content,
                'createdAt': DateTime.now().toIso8601String(),
              };

              if (_isUser) {
                await FirestoreService.addNote(note);
              } else {
                await NotesDB.addNote(note);
                await _loadLocalNotes();
              }

              Navigator.pop(context);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Note saved successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _editNoteDialog(Map<String, dynamic> note) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controllerTitle = TextEditingController(text: note['title']);
    final controllerContent = TextEditingController(text: note['content']);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text(
              "Edit Note",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controllerTitle,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: "Title",
                labelStyle: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controllerContent,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: "Content",
                labelStyle: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final title = controllerTitle.text.trim();
              final content = controllerContent.text.trim();

              if (title.isEmpty || content.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in both title and content'),
                  ),
                );
                return;
              }

              final updatedNote = {
                'title': title,
                'content': content,
                'createdAt': note['createdAt'] ?? DateTime.now().toIso8601String(),
              };

              if (_isUser) {
                await FirestoreService.updateNote(note['id'], updatedNote);
              } else {
                await NotesDB.updateNote(note['id'], updatedNote);
                await _loadLocalNotes();
              }

              Navigator.pop(context);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Note updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  void _deleteNote(Map<String, dynamic> note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[850] : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                "Delete Note",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          content: Text(
            "Are you sure you want to delete this note?",
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    if (_isUser) {
      await FirestoreService.deleteNote(note['id']);
    } else {
      await NotesDB.deleteNote(note['id']);
      await _loadLocalNotes();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note deleted'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_isUser ? Icons.cloud : Icons.person),
            const SizedBox(width: 8),
            Text(
              _isUser ? "Cloud Notes" : "Guest Notes",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, 197, 2, 227),
                  Color.fromARGB(255, 101, 14, 101),
                ],
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isUser ? Icons.cloud_done : Icons.storage,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isUser
                        ? 'Your notes are synced to the cloud'
                        : 'Notes are stored locally on this device',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isUser
                ? StreamBuilder<List<Map<String, dynamic>>>(
                    stream: FirestoreService.getNotesStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.deepPurple,
                          ),
                        );
                      }
                      final notes = snapshot.data!;
                      if (notes.isEmpty) {
                        return _buildEmptyState(isDark);
                      }
                      return _buildNotesGrid(notes, isDark);
                    },
                  )
                : FutureBuilder(
                    future: _loadLocalNotes(),
                    builder: (context, snapshot) {
                      if (_localNotes.isEmpty) {
                        return _buildEmptyState(isDark);
                      }
                      return _buildNotesGrid(_localNotes, isDark);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        onPressed: _addNoteDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_outlined,
            size: 80,
            color: isDark ? Colors.grey[700] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No notes yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to create your first note',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotesGrid(List<Map<String, dynamic>> notes, bool isDark) {
    final colors = [
      Colors.purple.shade100,
      Colors.blue.shade100,
      Colors.pink.shade100,
      Colors.orange.shade100,
      Colors.green.shade100,
      Colors.teal.shade100,
    ];

    final darkColors = [
      Colors.purple.shade900,
      Colors.blue.shade900,
      Colors.pink.shade900,
      Colors.orange.shade900,
      Colors.green.shade900,
      Colors.teal.shade900,
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: notes.length,
      itemBuilder: (context, i) {
        final note = notes[i];
        final colorIndex = i % (isDark ? darkColors.length : colors.length);
        final bgColor = isDark ? darkColors[colorIndex] : colors[colorIndex];

        return GestureDetector(
          onTap: () => _editNoteDialog(note),
          onLongPress: () => _deleteNote(note),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.sticky_note_2,
                      size: 20,
                      color: isDark ? Colors.white70 : Colors.deepPurple,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note['title'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.deepPurple,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Text(
                    note['content'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                      height: 1.4,
                    ),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: isDark ? Colors.white54 : Colors.deepPurple.shade300,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}