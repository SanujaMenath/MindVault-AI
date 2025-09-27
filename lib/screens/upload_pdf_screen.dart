import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../services/huggingface_service.dart';
import '../db/summary_db.dart';

class UploadPdfScreen extends StatefulWidget {
  const UploadPdfScreen({super.key});

  @override
  State<UploadPdfScreen> createState() => _UploadPdfScreenState();
}

class _UploadPdfScreenState extends State<UploadPdfScreen> {
  String? fileName;
  String? extractedText;
  String? summary;
  bool isLoading = false;

  List<String> chunkText(String text, {int chunkSize = 1000}) {
    final List<String> chunks = [];
    for (var i = 0; i < text.length; i += chunkSize) {
      final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      chunks.add(text.substring(i, end));
    }
    return chunks;
  }

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
        extractedText = null;
        summary = null;
      });

      try {
        final file = File(path);
        final bytes = await file.readAsBytes();

        final document = PdfDocument(inputBytes: bytes);
        final extractor = PdfTextExtractor(document);
        final text = extractor.extractText();
        document.dispose();

        setState(() {
          extractedText = text;
        });
      } catch (e) {
        debugPrint("Error extracting PDF text: $e");
      }
    }
  }

  Future<void> summarize() async {
    if (extractedText == null || fileName == null) return;

    setState(() => isLoading = true);

    try {
      final chunks = chunkText(extractedText!, chunkSize: 1000);
      final List<String> summaries = [];

      for (final chunk in chunks) {
        final result = await HuggingFaceService.summarizeText(chunk);
        summaries.add(result);
      }

      // Combine chunk summaries
      final combinedSummary = summaries.join(" ");

  
      String finalSummary = combinedSummary;
      if (combinedSummary.length > 1000) {
        finalSummary = await HuggingFaceService.summarizeText(combinedSummary);
      }

      setState(() {
        summary = finalSummary;
      });

      // Save to DB
      await SummaryDb.instance.insertSummary(fileName!, finalSummary);
    } catch (e) {
      debugPrint("Summarization failed: $e");
      setState(() => summary = "Failed to summarize text.");
    } finally {
      setState(() => isLoading = false);
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

            if (extractedText != null)
              ElevatedButton.icon(
                onPressed: summarize,
                icon: const Icon(Icons.summarize),
                label: const Text("Summarize"),
              ),

            const SizedBox(height: 20),
            if (isLoading) const CircularProgressIndicator(),
            if (summary != null) ...[
              const SizedBox(height: 20),
              Text(summary!, style: const TextStyle(fontSize: 16)),
            ],
          ],
        ),
      ),
    );
  }
}
