import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class HuggingFaceService {
  static const String apiUrl =
      "https://api-inference.huggingface.co/models/facebook/bart-large-cnn";

  static Future<String> summarizeText(String text) async {
    final apiKey = dotenv.env['HUGGINGFACE_API_KEY'] ?? "";

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"inputs": text}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List && data.isNotEmpty && data[0]["summary_text"] != null) {
        return data[0]["summary_text"];
      } else {
        return "No summary returned";
      }
    } else {
      throw Exception("Failed to summarize: ${response.body}");
    }
  }
}
