import 'dart:convert';
import 'dart:io';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/validation_utils.dart';
import 'package:perfit/data/models/meal_provider.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:http/http.dart' as http;
import 'package:perfit/widgets/walk_animation.dart';
import 'package:provider/provider.dart';

class AddFoodScreen extends StatefulWidget {
  final String meal;
  final bool isFromMeal;

  const AddFoodScreen({
    super.key,
    required this.meal,
    required this.isFromMeal,
  });

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final searchCtrl = TextEditingController();
  final servingCtrl = TextEditingController();
  final appId = "8cbd9bae";
  final appKey = "f7455b98be55ee9b094918b0b9c3f767";

  Future<List<dynamic>>? foodResult;

  // Search Edamam for foods
  Future<List<dynamic>> searchFood(String query) async {
    try {
      final url =
          "https://api.edamam.com/api/food-database/v2/parser?ingr=${Uri.encodeComponent(query)}&app_id=$appId&app_key=$appKey&nutrition-type=logging";

      final result = await http.get(Uri.parse(url));

      if (result.statusCode == 200) {
        final jsonData = jsonDecode(result.body);
        List<dynamic> response = [];

        if (jsonData['parsed'] != null) {
          for (var item in jsonData['parsed']) {
            response.add(item['food']);
          }
        }

        if (jsonData['hints'] != null) {
          for (var item in jsonData['hints']) {
            response.add(item['food']);
          }
        }

        print(response);

        return response;
      } else {
        print('API Error: ${result.body}');
        throw Exception("Error: ${result.statusCode}");
      }
    } on SocketException catch (e) {
      print("Network error: $e");
      rethrow;
    } catch (e) {
      print("Unexpected error: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchFoodInfo(Map<String, dynamic> food) async {
    try {
      final foodId = food["foodId"];
      final measureURI =
          "http://www.edamam.com/ontologies/edamam.owl#Measure_gram"; // per gram

      final result = await http.post(
        Uri.parse(
          "https://api.edamam.com/api/food-database/v2/nutrients?app_id=$appId&app_key=$appKey",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "ingredients": [
            {
              "quantity": 1,
              "measureURI": measureURI,
              "foodId": foodId,
            }, // 1 gram
          ],
        }),
      );

      if (result.statusCode == 200) {
        final jsonData = jsonDecode(result.body);
        jsonData["food_name"] = food["label"];
        return jsonData;
      } else {
        print("Error fetching nutrients: ${result.body}");
      }
    } catch (e) {
      print("Error fetching food info: $e");
    }
    return null;
  }

  Widget foodItem(Map<String, dynamic> food) {
    return Card(
      child: ListTile(
        title: Text(food["label"] ?? "Unknown"),
        trailing: IconButton(
          onPressed: () => showFoodInfo(food),
          icon: Icon(Icons.add),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Food"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.padding20),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.padding16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Search Food"),
                    Gap(AppSizes.gap10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: searchCtrl)),
                        IconButton(
                          onPressed: () {
                            if (searchCtrl.text.isEmpty) return;
                            if (!mounted) return;
                            setState(() {
                              foodResult = searchFood(searchCtrl.text);
                            });
                          },
                          icon: Icon(Icons.search),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Gap(AppSizes.gap10),
            Expanded(
              child:
                  foodResult == null
                      ? Center(child: Text("Search food."))
                      : FutureBuilder<List<dynamic>>(
                        future: foodResult,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: WalkAnimation());
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text("Error: ${snapshot.error}"),
                            );
                          }

                          final data = snapshot.data;
                          if (data == null || data.isEmpty) {
                            return Center(child: Text("No results found."));
                          }

                          return ListView(
                            children:
                                data.map((food) => foodItem(food)).toList(),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  void showFoodInfo(Map<String, dynamic> food) async {
    final fullFoodInfo = await fetchFoodInfo(food);

    if (!mounted) return;

    if (fullFoodInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unable to fetch food information.")),
      );
      return;
    }

    final nutrients = fullFoodInfo["totalNutrients"] ?? {};

    final calories = (nutrients["ENERC_KCAL"]?["quantity"] ?? 0).toDouble();
    final protein = (nutrients["PROCNT"]?["quantity"] ?? 0).toDouble();
    final carbs = (nutrients["CHOCDF"]?["quantity"] ?? 0).toDouble();
    final fat = (nutrients["FAT"]?["quantity"] ?? 0).toDouble();

    servingCtrl.text = "1";

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double quantity = double.tryParse(servingCtrl.text) ?? 1;

            final double totalCalories = calories * quantity;
            final double totalProtein = protein * quantity;
            final double totalCarbs = carbs * quantity;
            final double totalFat = fat * quantity;

            return AlertDialog(
              title: Text(fullFoodInfo["food_name"]),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Quantity (grams)"),
                    Gap(AppSizes.gap10),
                    TextField(
                      controller: servingCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setModalState(() {}),
                    ),
                    Gap(AppSizes.gap20),
                    Card(
                      child: ListTile(
                        title: Text("Calories"),
                        trailing: Text(
                          "${totalCalories.toStringAsFixed(1)} kcal",
                        ),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        title: Text("Protein"),
                        trailing: Text("${totalProtein.toStringAsFixed(1)} g"),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        title: Text("Carbs"),
                        trailing: Text("${totalCarbs.toStringAsFixed(1)} g"),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        title: Text("Fat"),
                        trailing: Text("${totalFat.toStringAsFixed(1)} g"),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text("Close"),
                ),
                TextButton(
                  onPressed: () {
                    if (!mounted) return;

                    if (widget.isFromMeal) {
                      addFoodToProvider(
                        food: fullFoodInfo,
                        quantity: quantity,
                        totalCalories: totalCalories,
                        totalProtein: totalProtein,
                        totalCarbs: totalCarbs,
                        totalFat: totalFat,
                      );

                      if (!mounted) return;
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();

                      if (!mounted) return;
                      ValidationUtils.snackBar(
                        context,
                        "added $quantity ${fullFoodInfo["food_name"]}",
                      );
                    } else {
                      addFood(
                        food: fullFoodInfo,
                        quantity: quantity,
                        totalCalories: totalCalories,
                        totalProtein: totalProtein,
                        totalCarbs: totalCarbs,
                        totalFat: totalFat,
                      );
                      if (!mounted) return;
                      Navigator.of(context).pop();

                      if (!mounted) return;
                      ValidationUtils.snackBar(
                        context,
                        "added $quantity grams ${fullFoodInfo["food_name"]}",
                      );
                    }
                  },
                  child: Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void addFood({
    required Map<String, dynamic> food,
    required double quantity,
    required double totalCalories,
    required double totalProtein,
    required double totalCarbs,
    required double totalFat,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final date = getTodayDateString();
    final meal = widget.meal.toLowerCase();

    final itemsCollection = FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("nutritionLogs")
        .doc(date)
        .collection("foods")
        .doc(meal)
        .collection("items");

    // Check if food already exists
    final existing =
        await itemsCollection
            .where("foodName", isEqualTo: food["food_name"])
            .limit(1)
            .get();

    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      await doc.reference.update({
        "quantity": FieldValue.increment(quantity),
        "totalCalories": FieldValue.increment(totalCalories),
        "totalProtein": FieldValue.increment(totalProtein),
        "totalCarbs": FieldValue.increment(totalCarbs),
        "totalFat": FieldValue.increment(totalFat),
      });
    } else {
      await itemsCollection.add({
        "foodName": food["food_name"],
        "quantity": quantity,
        "totalCalories": totalCalories,
        "totalProtein": totalProtein,
        "totalCarbs": totalCarbs,
        "totalFat": totalFat,
        "type": "food",
      });
    }

    // Update meal totals
    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("nutritionLogs")
        .doc(date)
        .collection("foods")
        .doc(meal)
        .set({
          "totalCalories": FieldValue.increment(totalCalories),
          "totalProtein": FieldValue.increment(totalProtein),
          "totalCarbs": FieldValue.increment(totalCarbs),
          "totalFat": FieldValue.increment(totalFat),
        }, SetOptions(merge: true));

    // Update daily totals
    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("nutritionLogs")
        .doc(date)
        .collection("foods")
        .doc("totals")
        .set({
          "totalCalories": FieldValue.increment(totalCalories),
          "totalProtein": FieldValue.increment(totalProtein),
          "totalCarbs": FieldValue.increment(totalCarbs),
          "totalFat": FieldValue.increment(totalFat),
        }, SetOptions(merge: true));

    // -------------------------------
    // Update 10-day and 30-day food log badges
    final planDoc =
        await FirebaseFirestore.instance.collection("users").doc(uid).get();

    final activePlanId = planDoc.data()?['activeFitnessPlan'];
    if (activePlanId == null || activePlanId == "") return;

    final badgesRef = FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("fitnessPlan")
        .doc(activePlanId)
        .collection("badges");

    for (var badgeId in ["10dayfoodlog", "30dayfoodlog"]) {
      final badgeDoc = badgesRef.doc(badgeId);
      final badgeSnapshot = await badgeDoc.get();

      if (!badgeSnapshot.exists) continue;

      final badgeData = badgeSnapshot.data()!;
      final lastUpdated = badgeData["lastUpdated"] as String?;
      if (lastUpdated == date) continue; // already incremented today

      await badgeDoc.update({
        "stat": FieldValue.increment(1),
        "lastUpdated": date,
        "completed": (badgeData["stat"] + 1) >= badgeData["requiredStats"],
      });
    }
  }

  void addFoodToProvider({
    required Map<String, dynamic> food,
    required double quantity,
    required double totalCalories,
    required double totalProtein,
    required double totalCarbs,
    required double totalFat,
  }) {
    final mealProvider = Provider.of<MealProvider>(context, listen: false);

    if (!mounted) return;

    // Check if the food already exists
    final index = mealProvider.foods.indexWhere(
      (item) => item.foodName == food["food_name"],
    );

    if (index != -1) {
      // Replace with a new FoodItem with updated values
      final existing = mealProvider.foods[index];
      final updated = FoodItem(
        foodName: existing.foodName,
        calories: existing.calories + totalCalories,
        protein: existing.protein + totalProtein,
        carbs: existing.carbs + totalCarbs,
        fat: existing.fat + totalFat,
        quantity: existing.quantity + quantity,
      );

      mealProvider.foods[index] = updated;
      mealProvider.notifyListeners();
    } else {
      // Add new food item
      final foodItem = FoodItem(
        foodName: food["food_name"],
        calories: totalCalories,
        protein: totalProtein,
        carbs: totalCarbs,
        fat: totalFat,
        quantity: quantity,
      );
      mealProvider.addFood(foodItem);
    }
  }

  String getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }
}
