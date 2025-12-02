import 'dart:convert';
import 'package:http/http.dart' as http;

class EdamamRecipeService {
  final String appId = "18ba57ad";
  final String appKey = "b507fb8377ba3eba83c0da0aa4183132";

  Future<List<dynamic>> searchRecipes(String query) async {
    final url = Uri.parse(
      "https://api.edamam.com/api/recipes/v2?type=public&q=pasta&app_id=$appId&app_key=$appKey",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Edamam wraps recipes inside "hits"
      return data["hits"];
    } else {
      throw Exception("Failed to fetch recipes: ${response.statusCode}");
    }
  }
}
