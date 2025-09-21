import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/upload_pdf_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MindVault AI',
      theme: ThemeData(
        useMaterial3: true, // modern Material 3 UI
        primarySwatch: Colors.deepPurple,
      ),
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/upload': (context) => const UploadPdfScreen(),
        '/notes': (context) => const NotesScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
