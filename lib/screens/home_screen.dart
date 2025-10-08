import 'package:flutter/material.dart';
import '../db/summary_db.dart';
import '../main.dart';
import 'package:local_auth/local_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  late Future<List<Map<String, dynamic>>> summariesFuture;

  @override
  void initState() {
    super.initState();
    _loadSummaries();
  }

  void _loadSummaries() {
    summariesFuture = SummaryDb.instance.getSummaries();
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadSummaries();
  }

  Future<void> _deleteSummary(int id) async {
    await SummaryDb.instance.deleteSummary(id);
    setState(() {
      _loadSummaries();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          "MindVault AI",
          style: TextStyle(
            color: theme.appBarTheme.foregroundColor ?? Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: theme.appBarTheme.foregroundColor ?? Colors.white,
            ),
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.pushNamed(context, '/settings');
              } else if (value == 'profile') {
                Navigator.pushNamed(context, '/profile');
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'profile',
                child: SizedBox(width: 150, child: Text("Profile")),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: SizedBox(width: 150, child: Text("Settings")),
              ),
            ],
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome back!",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
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

            // Action buttons - 2 rows with 3 cards each
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate card size for 3 cards per row
                final availableWidth = constraints.maxWidth;
                final cardSize = (availableWidth - 16) / 3; // 3 cards with 8px spacing

                return Column(
                  children: [
                    // First Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ActionCard(
                          size: cardSize,
                          icon: Icons.upload_file,
                          label: "Upload PDF",
                          gradient: const LinearGradient(
                            colors: [
                              Color.fromARGB(255, 152, 45, 245),
                              Color(0xFF4A00E0),
                            ],
                          ),
                          onTap: () => Navigator.pushNamed(context, '/upload'),
                        ),
                        _ActionCard(
                          size: cardSize,
                          icon: Icons.notes,
                          label: "My Notes",
                          gradient: const LinearGradient(
                            colors: [
                              Color.fromARGB(255, 197, 2, 227),
                              Color.fromARGB(255, 101, 14, 101),
                            ],
                          ),
                          onTap: () => Navigator.pushNamed(context, '/notes'),
                        ),
                        _ActionCard(
                          size: cardSize,
                          icon: Icons.task,
                          label: "Tasks",
                          gradient: const LinearGradient(
                            colors: [
                              Color.fromARGB(255, 47, 168, 193),
                              Color.fromARGB(255, 27, 81, 126),
                            ],
                          ),
                          onTap: () => Navigator.pushNamed(context, '/tasks'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Second Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ActionCard(
                          size: cardSize,
                          icon: Icons.lock,
                          label: "Vault",
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8800), Color(0xFFCC5500)],
                          ),
                          onTap: () async {
                            final auth = LocalAuthentication();
                            final didAuthenticate = await auth.authenticate(
                              localizedReason:
                                  'Please authenticate to access your Vault',
                              options: const AuthenticationOptions(
                                biometricOnly: true,
                                stickyAuth: true,
                              ),
                            );

                            if (didAuthenticate && context.mounted) {
                              Navigator.pushNamed(context, '/vault');
                            }
                          },
                        ),
                        _ActionCard(
                          size: cardSize,
                          icon: Icons.notifications_active,
                          label: "Reminders",
                          gradient: const LinearGradient(
                            colors: [
                              Color.fromARGB(255, 255, 107, 129),
                              Color.fromARGB(255, 255, 64, 129),
                            ],
                          ),
                          onTap: () => Navigator.pushNamed(context, '/reminders'),
                        ),
                        // Empty space for symmetry (or add another card if needed)
                        SizedBox(width: cardSize),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),
            Text(
              "Recent Summaries",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Summary List
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: summariesFuture,
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
                          onLongPress: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("Delete Summary"),
                                content: const Text(
                                  "Are you sure you want to delete this summary?",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text(
                                      "Delete",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              _deleteSummary(item["id"]);
                            }
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

// Action Card widget
class _ActionCard extends StatelessWidget {
  final double size;
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _ActionCard({
    required this.size,
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
        width: size,
        height: size,
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
            Icon(icon, size: size * 0.32, color: Colors.white),
            SizedBox(height: size * 0.08),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}