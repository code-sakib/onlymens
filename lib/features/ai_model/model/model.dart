import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  final String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

  /// Sends user message to GPT-4o-mini and returns AI's reply
  Future<String> sendMessage(String userMessage) async {
    final uri = Uri.parse(_baseUrl);

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    final body = jsonEncode({
      "model": "gpt-4o-mini",
      "messages": [
        {
          "role": "system",
          "content":
              "You are OnlyMens, a supportive AI that helps men quit pornography addiction. "
              "You are kind, practical, and motivating. "
              "Avoid judging the user. Help him identify triggers, plan short streaks, and stay positive."
        },
        {"role": "user", "content": userMessage}
      ],
      "max_tokens": 250,
      "temperature": 0.8
    });

    final response = await http.post(uri, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print(data);
      final reply = data['choices'][0]['message']['content'];
      return reply.trim();
    } else {
      print('Error: ${response.statusCode} - ${response.body}');
      return 'Sorry, something went wrong. Please try again.';
    }
  }
}
