import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class UploadPdfScreen extends StatefulWidget {
  const UploadPdfScreen({super.key});

  @override
  State<UploadPdfScreen> createState() => _UploadPdfScreenState();
}

class _UploadPdfScreenState extends State<UploadPdfScreen> {
  String? fileName;
  String? extractedText;

  Future<void> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      final path = result.files.single.path;
      if (path == null) return;

      setState(() {
        fileName = result.files.single.name;
        extractedText = null; // reset before extracting
      });

      try {
        final file = File(path);
        final bytes = await file.readAsBytes();

        // Load PDF and extract text
        final document = PdfDocument(inputBytes: bytes);
        final extractor = PdfTextExtractor(document);
        final text = extractor.extractText();
        document.dispose();

        setState(() {
          extractedText = text;
        });

        debugPrint("Extracted text: $text");
      } catch (e) {
        debugPrint("Error extracting PDF text: $e");
        setState(() {
          extractedText = "Failed to extract text.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload PDF")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: pickPdf,
              icon: const Icon(Icons.upload_file),
              label: const Text("Select PDF"),
            ),
            const SizedBox(height: 20),
            if (fileName != null) Text("Selected: $fileName"),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  extractedText ?? "No text extracted yet.",
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
