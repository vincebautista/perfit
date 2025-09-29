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
  final appId = "2309bcc3";
  final appKey = "fc0f766a22fc7dfb1f59369e4f14a3c3";

  Future<Map<String, List<dynamic>>>? foodResult;

  Future<Map<String, List<dynamic>>>? searchFood(String query) async {
    try {
      final result = await http.get(
        Uri.parse(
          "https://trackapi.nutritionix.com/v2/search/instant?query=$query",
        ),
        headers: {"x-app-id": appId, "x-app-key": appKey},
      );

      if (result.statusCode == 200) {
        final json = jsonDecode(result.body);
        print(json);
        return {
          "common": json["common"] ?? [],
          "branded": json["branded"] ?? [],
        };
      } else {
        print('API Error: ${result.body}');
        throw Exception("Error: ${result.statusCode}");
      }
    } on SocketException catch (e) {
      print("Network error: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchFoodInfo(
    Map<String, dynamic> food, {
    bool isBranded = false,
  }) async {
    final headers = {
      "x-app-id": appId,
      "x-app-key": appKey,
      "Content-Type": "application/json",
    };

    try {
      if (isBranded) {
        final id = food["nix_item_id"];

        if (id == null) {
          return null;
        }

        final result = await http.get(
          Uri.parse(
            "https://trackapi.nutritionix.com/v2/search/item?nix_item_id=$id",
          ),
          headers: headers,
        );

        if (result.statusCode == 200) {
          final json = jsonDecode(result.body);
          return json["foods"]?[0];
        }
      } else {
        final name = food["food_name"];
        final result = await http.post(
          Uri.parse("https://trackapi.nutritionix.com/v2/natural/nutrients"),
          headers: headers,
          body: jsonEncode({"query": name}),
        );

        if (result.statusCode == 200) {
          final json = jsonDecode(result.body);
          return json["foods"]?[0];
        }
      }
    } catch (e) {
      print("Error fetching full food info: $e");
    }

    return null;
  }

  Widget foodItem(Map<String, dynamic> food, {bool isBranded = false}) {
    return Card(
      child: ListTile(
        leading: Image.network(
          food["photo"]?["thumb"] ??
              (isBranded ? "https://via.placeholder.com/50" : ""),
          width: 50,
          height: 50,
          errorBuilder: (_, __, ___) => const Icon(Icons.fastfood),
          fit: BoxFit.cover,
        ),
        title: Text(food["food_name"] ?? "Unknown"),
        subtitle:
            isBranded
                ? Text(food["brand_name"] ?? "Branded Food")
                : Text("Common Food"),
        trailing: IconButton(
          onPressed: () => showFoodInfo(food, isBranded: isBranded),
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
                      : FutureBuilder(
                        future: foodResult,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
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

                          final commonFoods = data["common"];
                          final brandedFoods = data["branded"];

                          return ListView(
                            children: [
                              if (commonFoods!.isNotEmpty)
                                Text("Common Foods", style: TextStyles.title),
                              ...commonFoods.map((food) => foodItem(food)),
                              Gap(AppSizes.gap20),
                              if (brandedFoods!.isNotEmpty)
                                Text("Branded Foods", style: TextStyles.title),
                              ...brandedFoods.map(
                                (food) => foodItem(food, isBranded: true),
                              ),
                            ],
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  void showFoodInfo(Map<String, dynamic> food, {bool isBranded = false}) async {
    final fullFoodInfo = await fetchFoodInfo(food, isBranded: isBranded);

    if (fullFoodInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unable to fetch food information.")),
      );
      return;
    }

    final measures = fullFoodInfo["alt_measures"] ?? [];
    final servingWeight = fullFoodInfo["serving_weight_grams"];
    final calories = fullFoodInfo["nf_calories"];
    final protein = fullFoodInfo["nf_protein"];
    final carb = fullFoodInfo["nf_total_carbohydrate"];
    final fat = fullFoodInfo["nf_total_fat"];

    final caloriesPerGram = calories / servingWeight;
    final proteinPerGram = protein / servingWeight;
    final carbPerGram = carb / servingWeight;
    final fatPerGram = fat / servingWeight;

    Map<String, dynamic> selectedMeasure =
        measures.isNotEmpty
            ? measures[0]
            : {
              "serving_weight": servingWeight,
              "qty": 1,
              "measure": fullFoodInfo["serving_unit"],
            };

    servingCtrl.text = "1";

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double quantity = double.tryParse(servingCtrl.text) ?? 1;

            final double selectedWeight =
                (selectedMeasure["serving_weight"] as num).toDouble();
            final double selectedQty =
                (selectedMeasure["qty"] as num).toDouble();

            final double perUnitWeight = selectedWeight / selectedQty;
            final double totalGrams = quantity * perUnitWeight;

            final double totalCalories = caloriesPerGram * totalGrams;
            final double totalProtein = proteinPerGram * totalGrams;
            final double totalCarbs = carbPerGram * totalGrams;
            final double totalFat = fatPerGram * totalGrams;

            return AlertDialog(
              title: Text(fullFoodInfo["food_name"]),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Quantity"),
                    Gap(AppSizes.gap10),
                    TextField(
                      controller: servingCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        setModalState(() {});
                      },
                    ),
                    Gap(AppSizes.gap20),
                    Text("Unit"),
                    Gap(AppSizes.gap10),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      value: selectedMeasure,
                      items:
                          measures.map<DropdownMenuItem<Map<String, dynamic>>>((
                            measure,
                          ) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: measure,
                              child: SizedBox(
                                width:
                                    double
                                        .infinity, // forces ellipsis within bounds
                                child: Text(
                                  measure["measure"],
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() {
                            selectedMeasure = value;
                          });
                        }
                      },
                      selectedItemBuilder: (context) {
                        return measures.map<Widget>((measure) {
                          return Text(
                            measure["measure"],
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          );
                        }).toList();
                      },
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
                    if (widget.isFromMeal) {
                      addFoodToProvider(
                        food: fullFoodInfo,
                        quantity: quantity,
                        measure: selectedMeasure,
                        totalCalories: totalCalories,
                        totalProtein: totalProtein,
                        totalCarbs: totalCarbs,
                        totalFat: totalFat,
                      );
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();

                      ValidationUtils.snackBar(
                        context,
                        "added $quantity ${selectedMeasure["measure"]} ${fullFoodInfo["food_name"]}",
                      );
                    } else {
                      addFood(
                        food: fullFoodInfo,
                        quantity: quantity,
                        measure: selectedMeasure,
                        totalCalories: totalCalories,
                        totalProtein: totalProtein,
                        totalCarbs: totalCarbs,
                        totalFat: totalFat,
                      );
                      Navigator.of(context).pop();
                      ValidationUtils.snackBar(
                        context,
                        "added $quantity ${selectedMeasure["measure"]} ${fullFoodInfo["food_name"]}",
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
    required Map<String, dynamic> measure,
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

    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("nutritionLogs")
        .doc(date)
        .set({
          "totalCalories": FieldValue.increment(totalCalories),
          "totalProtein": FieldValue.increment(totalProtein),
          "totalCarbs": FieldValue.increment(totalCarbs),
          "totalFat": FieldValue.increment(totalFat),
        }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("nutritionLogs")
        .doc(date)
        .collection("meals")
        .doc(meal)
        .collection("items")
        .add({
          "foodName": food["food_name"],
          "quantity": quantity,
          "unit": measure["measure"],
          "totalCalories": totalCalories,
          "totalProtein": totalProtein,
          "totalCarbs": totalCarbs,
          "totalFat": totalFat,
          "type": "food",
        });

    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("nutritionLogs")
        .doc(date)
        .collection("meals")
        .doc(meal)
        .set({
          "totalCalories": FieldValue.increment(totalCalories),
          "totalProtein": FieldValue.increment(totalProtein),
          "totalCarbs": FieldValue.increment(totalCarbs),
          "totalFat": FieldValue.increment(totalFat),
        }, SetOptions(merge: true));
  }

  void addFoodToProvider({
    required Map<String, dynamic> food,
    required double quantity,
    required Map<String, dynamic> measure,
    required double totalCalories,
    required double totalProtein,
    required double totalCarbs,
    required double totalFat,
  }) {
    final foodItem = FoodItem(
      foodName: food["food_name"],
      calories: totalCalories,
      protein: totalProtein,
      carbs: totalCarbs,
      fat: totalFat,
      quantity: quantity,
      unit: measure["measure"],
    );

    final mealProvider = Provider.of<MealProvider>(context, listen: false);
    mealProvider.addFood(foodItem);
  }

  String getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }
}
