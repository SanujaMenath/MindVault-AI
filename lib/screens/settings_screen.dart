import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isDarkMode = false;
  double fontSize = 16;
  bool notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: const Color(0xFF4A00E0),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Dark Mode"),
            value: isDarkMode,
            onChanged: (value) {
              setState(() => isDarkMode = value);
              // TODO: Apply dark theme globally
            },
          ),
          ListTile(
            title: const Text("Font Size"),
            subtitle: Text("Adjust text size for summaries"),
            trailing: DropdownButton<double>(
              value: fontSize,
              items: const [
                DropdownMenuItem(value: 14, child: Text("Small")),
                DropdownMenuItem(value: 16, child: Text("Medium")),
                DropdownMenuItem(value: 18, child: Text("Large")),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => fontSize = value);
                  // TODO: Apply font size in summary/notes
                }
              },
            ),
          ),
          SwitchListTile(
            title: const Text("Enable Notifications"),
            value: notificationsEnabled,
            onChanged: (value) {
              setState(() => notificationsEnabled = value);
              // TODO: Enable/disable reminders
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info, color: Colors.deepPurple),
            title: const Text("About"),
            subtitle: const Text("MindVault AI v1.0.0"),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: "MindVault AI",
                applicationVersion: "1.0.0",
                applicationLegalese: "© 2025 MindVault",
              );
            },
          ),
        ],
      ),
    );
  }
}
