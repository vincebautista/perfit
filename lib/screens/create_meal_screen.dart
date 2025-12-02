import 'dart:convert';
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/core/utils/validation_utils.dart';
import 'package:perfit/data/models/meal_provider.dart';
import 'package:perfit/screens/add_food_screen.dart';
import 'package:perfit/core/services/gemini_api_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';

class CreateMealScreen extends StatefulWidget {
  final String meal;

  const CreateMealScreen({super.key, required this.meal});

  @override
  State<CreateMealScreen> createState() => _CreateMealScreenState();
}

class _CreateMealScreenState extends State<CreateMealScreen> {
  final nameCtrl = TextEditingController();
  String? uid;

  final caloriesClr = Color.fromARGB(255, 221, 192, 255);
  final proteinClr = Color.fromARGB(255, 69, 197, 136);
  final carbsClr = Color.fromARGB(255, 120, 180, 245);
  final fatClr = Color.fromARGB(255, 255, 111, 67);

  bool isGenerated = false;
  Map<String, dynamic>? generatedMeal;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    final mealProvider = Provider.of<MealProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isGenerated ? "Generated Meal" : "Create Meal"),
        actions: [
          if (!isGenerated)
            TextButton(
              onPressed:
                  () => NavigationUtils.push(
                    context,
                    AddFoodScreen(meal: widget.meal, isFromMeal: true),
                  ),
              child: const Text(
                "Add Food",
                style: TextStyle(color: AppColors.white),
              ),
            ),
          if (isGenerated)
            TextButton(
              onPressed: () => showSaveDialog(mealProvider), // 🔹 NEW
              child: const Text(
                "Save",
                style: TextStyle(color: AppColors.white),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.padding20),
        child:
            isGenerated
                ? buildGeneratedMealView(mealProvider) // 🔹 Show generated meal
                : buildMealInputView(mealProvider), // 🔹 Default view
      ),
    );
  }

  // 🔹 View before generation
  Widget buildMealInputView(MealProvider mealProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildMacroCards(mealProvider),
        Gap(AppSizes.gap15),
        const Text("Meal Items", style: TextStyle(fontWeight: FontWeight.bold)),
        Gap(AppSizes.gap10),
        Expanded(
          child: ListView.builder(
            itemCount: mealProvider.foods.length,
            itemBuilder: (context, index) {
              final food = mealProvider.foods[index];
              return Card(
                child: ListTile(
                  title: Text("${food.quantity} grams ${food.foodName}"),
                  subtitle: Text(
                    "${food.calories.toStringAsFixed(2)} kcal | Protein: ${food.protein.toStringAsFixed(2)}g | Carbs: ${food.carbs.toStringAsFixed(2)}g | Fat: ${food.fat.toStringAsFixed(2)}g",
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.red),
                    onPressed: () => mealProvider.removeFood(index),
                  ),
                ),
              );
            },
          ),
        ),
        Gap(AppSizes.gap10),
        ElevatedButton(
          onPressed: () => generateMeal(mealProvider),
          child: const Text("Generate Meal"),
        ),
      ],
    );
  }

  // 🔹 View after generation
  Widget buildGeneratedMealView(MealProvider mealProvider) {
    if (generatedMeal == null) return const SizedBox();

    final ingredients = mealProvider.foods; // ✅ Use provider foods
    final nutrition = {
      "calories": mealProvider.totalCalories,
      "protein": mealProvider.totalProtein,
      "carbs": mealProvider.totalCarbs,
      "fat": mealProvider.totalFat,
    };

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            generatedMeal!["mealName"],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Gap(AppSizes.gap15),
          buildMacroCardsFromMap(nutrition),
          Gap(AppSizes.gap15),
          const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            tabs: [Tab(text: "Meal Items"), Tab(text: "Instructions")],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // 🔹 Meal Items Tab
                ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: ingredients.length,
                  itemBuilder: (context, index) {
                    final food = ingredients[index];
                    return Card(
                      color: AppColors.surface,
                      child: ListTile(
                        title: Text("${food.quantity} grams ${food.foodName}"),
                        subtitle: Text(
                          "${food.calories.toStringAsFixed(2)} kcal | Protein: ${food.protein.toStringAsFixed(2)}g | Carbs: ${food.carbs.toStringAsFixed(2)}g | Fat: ${food.fat.toStringAsFixed(2)}g",
                        ),
                      ),
                    );
                  },
                ),
                // 🔹 Instructions Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ..._buildInstructionSteps(
                        generatedMeal!["instructions"] ?? "",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () => showRecreateDialog(), // 🔹 Call new dialog
              child: const Text("Recreate Meal"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> showRecreateDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              "Are you sure?",
              style: TextStyle(color: AppColors.primary),
            ),
            content: const Text(
              "This will reset the current meal and allow you to recreate it.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: AppColors.white),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Yes",
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
    );

    if (result == true) {
      if (!mounted) return; // before setState
      // 🔹 Show QuickAlert loading
      QuickAlert.show(
        context: context,
        type: QuickAlertType.loading,
        text: "Recreating meal...",
        barrierDismissible: false,
      );

      // 🔹 Simulate a small delay to show loading effect
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return; // before setState

      // 🔹 Reset the meal state
      setState(() {
        isGenerated = false;
        generatedMeal = null;
      });

      // 🔹 Dismiss QuickAlert
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  List<Widget> _buildInstructionSteps(String instructions) {
    // Split by numbers or newlines for steps
    final stepList =
        instructions
            .split(RegExp(r'(\d+\.)|\n')) // split by 1., 2., ... or newlines
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

    return List.generate(
      stepList.length,
      (index) => Card(
        color: AppColors.surface,
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary,
            child: Text(
              "${index + 1}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(stepList[index], style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }

  // 🔹 Shared widget: macro cards
  Widget buildMacroCards(MealProvider mealProvider) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: buildCard(
                "Calories",
                mealProvider.totalCalories,
                caloriesClr,
              ),
            ),
            Expanded(
              child: buildCard(
                "Protein",
                mealProvider.totalProtein,
                proteinClr,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: buildCard("Carbs", mealProvider.totalCarbs, carbsClr),
            ),
            Expanded(child: buildCard("Fat", mealProvider.totalFat, fatClr)),
          ],
        ),
      ],
    );
  }

  Widget buildMacroCardsFromMap(Map<String, dynamic> map) {
    double calories = (map["calories"] as num).toDouble();
    double protein = (map["protein"] as num).toDouble();
    double carbs = (map["carbs"] as num).toDouble();
    double fat = (map["fat"] as num).toDouble();

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: buildCard("Calories", calories, caloriesClr)),
            Expanded(child: buildCard("Protein", protein, proteinClr)),
          ],
        ),
        Row(
          children: [
            Expanded(child: buildCard("Carbs", carbs, carbsClr)),
            Expanded(child: buildCard("Fat", fat, fatClr)),
          ],
        ),
      ],
    );
  }

  Widget buildCard(String title, double value, Color clr) {
    return Card(
      color: clr,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.padding16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(title), Text(value.toStringAsFixed(2))],
        ),
      ),
    );
  }

  // 🔹 Generate meal via Gemini
  Future<void> generateMeal(MealProvider mealProvider) async {
    if (mealProvider.foods.isEmpty) {
      ValidationUtils.snackBar(context, "Please add at least one food item.");
      return;
    }

    final ingredients =
        mealProvider.foods
            .map(
              (f) => {
                "name": f.foodName,
                "quantity": f.quantity,
                "calories": f.calories,
                "protein": f.protein,
                "carbs": f.carbs,
                "fat": f.fat,
              },
            )
            .toList();

    final prompt = """
    You are a professional nutritionist and chef AI. Your task is to create a **healthy, realistic meal recipe** using ONLY the provided ingredients and quantities.

    Use your expertise to determine what type of meal it becomes (e.g., salad, smoothie, wrap, stir-fry, soup, bowl, etc.) and generate:
    1. A descriptive meal name that matches the ingredients and style of preparation.
    2. Detailed, step-by-step cooking or preparation instructions (at least 5 clear and realistic steps).
    3. Estimated nutrition totals based on the given ingredients (approximate macros).

    Follow these **strict formatting and logic rules**:
    - You must use **all provided ingredients** in the recipe. Do not add or remove any.
    - Be **creative but realistic** — only propose meals that can actually be made with those ingredients.
    - All cooking instructions must be **precise** (e.g., “heat oil in a pan,” “boil water,” “chop vegetables finely,” etc.).
    - Output **ONLY valid JSON**. Do NOT include explanations, markdown, or text outside the JSON.

    JSON Output Format:
    {
      "mealName": "string",
      "instructions": "string",
      "ingredients": [
        {"name": "string", "quantity": number, "unit": "string"}
      ],
      "nutrition": {
        "calories": number,
        "protein": number,
        "carbs": number,
        "fat": number
      }
    }

    Ingredients provided:
    $ingredients
  """;

    try {
      if (!mounted) return;
      // 🔹 Show QuickAlert loading
      QuickAlert.show(
        context: context,
        type: QuickAlertType.loading,
        text: "Generating meal...",
        barrierDismissible: false,
      );

      final gemini = GeminiApiService();
      final response = await gemini.generateJson(prompt);

      // 🔹 Dismiss loading
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      print("🔹 Gemini Raw Response:\n$response");

      // Clean JSON
      String cleaned = response.trim();
      cleaned =
          cleaned
              .replaceAll(RegExp(r'```json', caseSensitive: false), '')
              .replaceAll('```', '')
              .trim();
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start != -1 && end != -1) {
        cleaned = cleaned.substring(start, end + 1);
      }

      final result = json.decode(cleaned);

      if (!mounted) return;
      setState(() {
        generatedMeal = result;
        isGenerated = true;
      });
    } catch (e, stack) {
      // 🔹 Dismiss loading in case of error
      Navigator.of(context, rootNavigator: true).pop();

      print("❌ Error generating meal: $e");
      print(stack);
      ValidationUtils.snackBar(context, "Failed to generate meal: $e");
    }
  }

  // 🔹 Ask for name + save
  Future<void> showSaveDialog(MealProvider mealProvider) async {
    final mealNameCtrl = TextEditingController(
      text: generatedMeal?["mealName"] ?? "",
    );

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              "Save Meal",
              style: TextStyle(color: AppColors.primary),
            ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Meal Name"),
                Gap(AppSizes.gap10),
                TextField(controller: mealNameCtrl),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: AppColors.white),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.padding16,
                  vertical: AppSizes.padding16 - 8,
                ),
                child: GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    await saveMeal(mealProvider, mealNameCtrl.text.trim());
                  },
                  child: const Text(
                    "Save",
                    style: TextStyle(color: AppColors.white),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // 🔹 Save meal to Firestore
  Future<void> saveMeal(MealProvider mealProvider, String name) async {
    try {
      if (!mounted) return;
      // 🔹 Show QuickAlert loading
      QuickAlert.show(
        context: context,
        type: QuickAlertType.loading,
        text: "Saving meal...",
        barrierDismissible: false,
      );

      final mealRef = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .collection("myMeals")
          .add({
            "mealName": name,
            "instructions": generatedMeal?["instructions"] ?? "",
            "totalCalories": mealProvider.totalCalories,
            "totalProtein": mealProvider.totalProtein,
            "totalCarbs": mealProvider.totalCarbs,
            "totalFat": mealProvider.totalFat,
          });

      final foodsRef = FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .collection("myMeals")
          .doc(mealRef.id)
          .collection("foods");

      for (var food in mealProvider.foods) {
        await foodsRef.add({
          "foodName": food.foodName,
          "calories": food.calories,
          "protein": food.protein,
          "carbs": food.carbs,
          "fat": food.fat,
          "quantity": food.quantity,
        });
      }

      mealProvider.clearMeal();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ValidationUtils.snackBar(context, "Meal saved successfully!");
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      // 🔹 Dismiss QuickAlert in case of error
      Navigator.of(context, rootNavigator: true).pop();

      if (!mounted) return;
      ValidationUtils.snackBar(context, "Failed to save meal: $e");
      print("❌ Error saving meal: $e");
    }
  }
}
