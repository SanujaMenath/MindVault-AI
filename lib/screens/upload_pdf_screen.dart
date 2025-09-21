import 'package:flutter/material.dart';

class UploadPdfScreen extends StatelessWidget {
  const UploadPdfScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload PDF")),
      body: const Center(
        child: Text("Upload PDF Screen"),
      ),
    );
  }
}
