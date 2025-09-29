import 'dart:convert';

import 'package:http/http.dart' as http;

class FoodDataService {
  final String apiKey = "E9i8cZaMdKEncAdc82DI3g==jBiKv1MAexBS6IDZ";
  final String baseUrl = "https://api.calorieninjas.com/v1/nutrition";

  Future<Map<String, dynamic>?> searchFood(String query) async {
    final url = Uri.parse("$baseUrl?query=$query");

    final response = await http.get(url, headers: {"X-Api-Key": apiKey});

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['items'] == null || data['items'].isEmpty) {
        print("No data found for $query");
        return null;
      }

      final item = data['items'][0];

      final nutrients = {
        "protein": (item["protein_g"] as num?)?.toDouble() ?? 0.0,
        "fat": (item["fat_total_g"] as num?)?.toDouble() ?? 0.0,
        "carb": (item["carbohydrates_total_g"] as num?)?.toDouble() ?? 0.0,
        "energy": (item["calories"] as num?)?.toDouble() ?? 0.0,
      };

      print("Nutrients for $query: $nutrients");

      return nutrients;
    } else {
      print("Failed to fetch nutrition info: ${response.statusCode}");
    }

    return null;
  }

  Future<Map<String, dynamic>?> getNutrients(int foodId) async {
    final url = Uri.parse("$baseUrl/foods/$foodId?api_key=$apiKey");

    print("Fetching nutrients for FDC ID: $foodId");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      print("Nutrient data: $data");

      final nutrients = {
        "protein": getNutrient(data, 1003),
        "fat": getNutrient(data, 1004),
        "carb": getNutrient(data, 1005),
        "energy": getNutrient(data, 1008),
      };

      print("Parsed nutrients:");
      print("Protein: ${nutrients['protein']}g");
      print("Fat: ${nutrients['fat']}g");
      print("Carb: ${nutrients['carb']}g");
      print("Energy: ${nutrients['energy']} kcal");

      return nutrients;
    }

    return null;
  }

  double? getNutrient(Map<String, dynamic> data, int nutrientId) {
    final List<dynamic> nutrients = data["foodNutrients"];

    final match = nutrients.firstWhere(
      (n) =>
          (n["nutrient"]?["id"] == nutrientId) ||
          (n["nutrientId"] == nutrientId),
      orElse: () => null,
    );

    if (match == null) return 0.0;

    final amount = match["amount"] ?? match["value"];
    return (amount as num?)?.toDouble() ?? 0.0;
  }
}
