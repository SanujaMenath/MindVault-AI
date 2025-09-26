import 'package:flutter/material.dart';
import '../db/summary_db.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA), // soft background
      appBar: AppBar(
        title: const Text(
          "MindVault AI",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF4A00E0),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Text(
              "Welcome back!",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4A00E0),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Organize your notes, PDFs, and AI summaries all in one place.",
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),

            // Action Buttons with gradient style
            // Inside the Row with _ActionCard
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ActionCard(
                  icon: Icons.upload_file,
                  label: "Upload PDF",
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/upload');
                  },
                ),
                _ActionCard(
                  icon: Icons.notes,
                  label: "My Notes",
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/notes');
                  },
                ),
                _ActionCard(
                  icon: Icons.settings,
                  label: "Settings",
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFC5C7D), Color(0xFF6A82FB)],
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/settings');
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),
            Text(
              "Recent Summaries",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Summarized History Cards
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: SummaryDb.instance.getSummaries(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final summaries = snapshot.data!;
                  if (summaries.isEmpty) {
                    return const Center(child: Text("No summaries yet"));
                  }
                  return ListView.builder(
                    itemCount: summaries.length,
                    itemBuilder: (context, index) {
                      final item = summaries[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        child: ListTile(
                          leading: const Icon(
                            Icons.description,
                            color: Color(0xFF4A00E0),
                          ),
                          title: Text(item["fileName"]),
                          subtitle: Text(
                            item["summary"],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(item["fileName"]),
                                content: SingleChildScrollView(
                                  child: Text(item["summary"]),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Close"),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Action Card with gradient
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
