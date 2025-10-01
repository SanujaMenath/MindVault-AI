import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Center(
        child: user == null
            ? ElevatedButton(
                onPressed: () async {
                  final user = await authService.signInWithGoogle();
                  if (user != null && mounted) {
                    Navigator.pushReplacementNamed(context, '/home');
                  }
                },

                child: const Text("Sign in with Google"),
              )
            : ElevatedButton(
                onPressed: () async {
                  await authService.signOut();
                  setState(() {});
                },
                child: const Text("Sign Out"),
              ),
      ),
    );
  }
}
