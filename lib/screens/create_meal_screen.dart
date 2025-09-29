import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/core/utils/validation_utils.dart';
import 'package:perfit/data/models/meal_provider.dart';
import 'package:perfit/screens/add_food_screen.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

class CreateMealScreen extends StatefulWidget {
  final String meal;

  const CreateMealScreen({super.key, required this.meal});

  @override
  State<CreateMealScreen> createState() => _CreateMealScreenState();
}

class _CreateMealScreenState extends State<CreateMealScreen> {
  final nameCtrl = TextEditingController();
  String? uid;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    uid = user!.uid;
  }

  @override
  Widget build(BuildContext context) {
    final mealProvider = Provider.of<MealProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("Create Meal"),
        actions: [
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) {
                ValidationUtils.snackBar(context, "Please enter a meal name.");
                return;
              }

              if (mealProvider.foods.isEmpty) {
                ValidationUtils.snackBar(
                  context,
                  "Please add at least one food item.",
                );
                return;
              }

              final meal = await FirebaseFirestore.instance
                  .collection("users")
                  .doc(uid)
                  .collection("myMeals")
                  .add({
                    "mealName": nameCtrl.text.trim(),
                    "totalCalories": mealProvider.totalCalories,
                    "totalProtein": mealProvider.totalProtein,
                    "totalCarbs": mealProvider.totalCarbs,
                    "totalFat": mealProvider.totalFat,
                  });

              final foodsRef = FirebaseFirestore.instance
                  .collection("users")
                  .doc(uid)
                  .collection("myMeals")
                  .doc(meal.id)
                  .collection("foods");

              for (var food in mealProvider.foods) {
                await foodsRef.add({
                  "foodName": food.foodName,
                  "calories": food.calories,
                  "protein": food.protein,
                  "carbs": food.carbs,
                  "fat": food.fat,
                  "quantity": food.quantity,
                  "unit": food.unit,
                });
              }

              mealProvider.clearMeal();

              ValidationUtils.snackBar(context, "Meal saved successfully!");

              Navigator.of(context).pop();
            },
            child: Text("Save"),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.padding20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Meal Name", style: TextStyles.body),
            Gap(AppSizes.gap10),
            TextField(controller: nameCtrl),
            Gap(AppSizes.gap10),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.padding16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Total Calories"),
                          Text(mealProvider.totalCalories.toStringAsFixed(1)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.padding16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Total Protein"),
                          Text(mealProvider.totalProtein.toStringAsFixed(1)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.padding16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Total Carbs"),
                          Text(mealProvider.totalCarbs.toStringAsFixed(1)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.padding16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Total Fat"),
                          Text(mealProvider.totalFat.toStringAsFixed(1)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Gap(AppSizes.gap10),
            const Text(
              "Meal Items",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Gap(AppSizes.gap10),
            Expanded(
              child: ListView.builder(
                itemCount: mealProvider.foods.length,
                itemBuilder: (context, index) {
                  final food = mealProvider.foods[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        "${food.quantity} ${food.unit} ${food.foodName}",
                      ),
                      subtitle: Text(
                        "${food.calories.toStringAsFixed(2)} kcal | Protein: ${food.protein.toStringAsFixed(2)}g | Carbs: ${food.carbs.toStringAsFixed(2)}g | Fat: ${food.fat.toStringAsFixed(2)}g",
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => mealProvider.removeFood(index),
                      ),
                    ),
                  );
                },
              ),
            ),
            Gap(AppSizes.gap10),
            ElevatedButton(
              onPressed:
                  () => NavigationUtils.push(
                    context,
                    AddFoodScreen(meal: widget.meal, isFromMeal: true),
                  ),
              child: Text("Add Food"),
            ),
          ],
        ),
      ),
    );
  }
}
