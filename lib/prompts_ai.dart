import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // For environment variables

// Function to call OpenAI API and get a response
Future<String> chatWithGpt(String prompt) async {
  final apiKey =
      dotenv.env['OPENAI_API_KEY']; // Get API key from environment variables

  // OpenAI API endpoint
  final url = Uri.parse('https://api.openai.com/v1/chat/completions');

  // HTTP request body
  final body = jsonEncode({
    'model': 'gpt-4o-mini', // or 'gpt-4' if you have access
    'messages': [
      {'role': 'user', 'content': prompt},
    ],
    'temperature': 0.7,
    'n': 1,
  });

  // HTTP headers, including API key for authentication
  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $apiKey',
  };

  // Sending the request to OpenAI API
  final response = await http.post(url, headers: headers, body: body);

  // Checking if the request was successful
  if (response.statusCode == 200) {
    // final data = jsonDecode(response.body);
    final data = json.decode(utf8.decode(response.bodyBytes));
    return data['choices'][0]['message']['content'].trim();
  } else {
    throw Exception('Failed to load response from OpenAI: ${response.body}');
  }
}
