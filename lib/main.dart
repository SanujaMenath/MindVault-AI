import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; 
import 'splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/upload_pdf_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
        useMaterial3: true,
        primarySwatch: Colors.deepPurple,
      ),
      home: const SplashScreen(),
      navigatorObservers: [routeObserver],
      routes: {
        '/home': (context) => const HomeScreen(),
        '/upload': (context) => const UploadPdfScreen(),
        '/notes': (context) => const NotesScreen(),
        '/tasks': (context) => const TasksScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
