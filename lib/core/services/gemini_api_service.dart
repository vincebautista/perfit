import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiApiService {
  final String API_KEY = "AIzaSyBadDeHTDpLSr3y5h8p2dbI7eCmFkQ0_5Q";
  final String API_URL =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=AIzaSyBadDeHTDpLSr3y5h8p2dbI7eCmFkQ0_5Q';

  Future<String?> fetchFromGemini(String prompt) async {
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": prompt},
          ],
        },
      ],
    });

    try {
      final response = await http.post(
        Uri.parse(API_URL),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        print('Error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<String> generateJson(String prompt) async {
    final response = await http.post(
      Uri.parse("$API_URL"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["candidates"][0]["content"]["parts"][0]["text"];
    } else {
      throw Exception("Gemini error: ${response.body}");
    }
  }
}
