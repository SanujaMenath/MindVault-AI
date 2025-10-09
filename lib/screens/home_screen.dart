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
    final isDark = theme.brightness == Brightness.dark;

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
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          theme.colorScheme.primary.withOpacity(0.3),
                          theme.colorScheme.secondary.withOpacity(0.2),
                        ]
                      : [
                          theme.colorScheme.primary.withOpacity(0.1),
                          theme.colorScheme.secondary.withOpacity(0.05),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.waving_hand,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Hello there!",
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Your intelligent workspace for notes, documents, and smart summaries.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Icon(
                  Icons.dashboard_customize,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  "Quick Actions",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            // Action buttons - 2 rows with 3 cards each
             // Action Cards Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: [
                  _ActionCard(
                    size: 100,
                    icon: Icons.upload_file,
                    label: "Upload\nPDF",
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF982DF5),
                        const Color(0xFF4A00E0),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () => Navigator.pushNamed(context, '/upload'),
                  ),
                  _ActionCard(
                    size: 100,
                    icon: Icons.notes,
                    label: "My\nNotes",
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFC502E3),
                        const Color(0xFF650E65),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () => Navigator.pushNamed(context, '/notes'),
                  ),
                  _ActionCard(
                    size: 100,
                    icon: Icons.task,
                    label: "Tasks",
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2FA8C1),
                        const Color(0xFF1B517E),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () => Navigator.pushNamed(context, '/tasks'),
                  ),
                  _ActionCard(
                    size: 100,
                    icon: Icons.lock,
                    label: "Vault",
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFF8800),
                        const Color(0xFFCC5500),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
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
                    size: 100,
                    icon: Icons.notifications_active,
                    label: "Reminders",
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFF6B81),
                        const Color(0xFFFF4081),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () => Navigator.pushNamed(context, '/reminders'),
                  ),
                ],
              ),

            const SizedBox(height: 32),

            // Recent Summaries Header
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
