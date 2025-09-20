import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MindVault AI Home'),
      ),
      body: const Center(
        child: Text(
          'Welcome to MindVault AI!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
