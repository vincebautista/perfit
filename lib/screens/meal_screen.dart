import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/screens/add_food_screen.dart';
import 'package:perfit/screens/my_meal_screen.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';

class MealScreen extends StatefulWidget {
  final String meal;

  MealScreen({super.key, required this.meal});

  @override
  State<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> {
  String? uid;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    uid = user!.uid;
  }

  Future<List<Map<String, dynamic>>> getAllFoods() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return [];
    }

    final snapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection("nutritionLogs")
            .doc(getTodayDateString())
            .collection("foods")
            .doc(widget.meal.toLowerCase())
            .collection("items")
            .get();

    return snapshot.docs.map((doc) => {"id": doc.id, ...doc.data()}).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.meal),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed:
                () => NavigationUtils.push(
                  context,
                  MyMealScreen(meal: widget.meal),
                ),
            child: Text(
              "My Meals",
              style: TextStyles.body.copyWith(color: AppColors.white),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.padding20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Foods Eaten"),
            Expanded(
              child: StreamBuilder(
                stream:
                    FirebaseFirestore.instance
                        .collection("users")
                        .doc(uid)
                        .collection("nutritionLogs")
                        .doc(getTodayDateString())
                        .collection("meals")
                        .doc(widget.meal.toLowerCase())
                        .collection("items")
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.data == null || !snapshot.hasData) {
                    return const Center(child: Text('No foods logged.'));
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(child: Text('No foods logged.'));
                  }

                  final foods =
                      docs.map((doc) => {"id": doc.id, ...doc.data()}).toList();

                  return ListView.builder(
                    itemCount: foods.length,
                    itemBuilder: (context, index) {
                      final food = foods[index];
                      final isRecipe = food['type'] == 'recipe';

                      final title =
                          isRecipe
                              ? (food['mealName'] ?? 'Unnamed Recipe')
                              : "${food['quantity'] ?? '-'} ${food['unit'] ?? '-'} ${food['foodName'] ?? 'Unnamed Food'}";

                      final subtitle =
                          "${food['totalCalories']?.toStringAsFixed(1) ?? '?'} kcal | "
                          "Protein: ${food['totalProtein']?.toStringAsFixed(1) ?? '?'}g | "
                          "Carbs: ${food['totalCarbs']?.toStringAsFixed(1) ?? '?'}g | "
                          "Fat: ${food['totalFat']?.toStringAsFixed(1) ?? '?'}g";

                      return Card(
                        child: ListTile(
                          title: Text(title),
                          subtitle: Text(subtitle),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => deleteFood(food),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed:
                  () => NavigationUtils.push(
                    context,
                    AddFoodScreen(meal: widget.meal, isFromMeal: false),
                  ),
              child: Text("Add Food"),
            ),
          ],
        ),
      ),
    );
  }

  void deleteFood(Map<String, dynamic> food) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final date = getTodayDateString();
    final meal = widget.meal.toLowerCase();
    final foodId = food['id'];

    QuickAlert.show(context: context, type: QuickAlertType.loading);

    final todayNutritionLogSnapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("nutritionLogs")
            .doc(date)
            .get();

    final todayNutritionLog = todayNutritionLogSnapshot.data() ?? {};

    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("nutritionLogs")
        .doc(date)
        .set({
          "totalCalories":
              (todayNutritionLog["totalCalories"] ?? 0) -
              (food["totalCalories"] ?? 0),
          "totalProtein":
              (todayNutritionLog["totalProtein"] ?? 0) -
              (food["totalProtein"] ?? 0),
          "totalCarbs":
              (todayNutritionLog["totalCarbs"] ?? 0) -
              (food["totalCarbs"] ?? 0),
          "totalFat":
              (todayNutritionLog["totalFat"] ?? 0) - (food["totalFat"] ?? 0),
        }, SetOptions(merge: true));

    final mealNutritionLogSnapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("nutritionLogs")
            .doc(date)
            .collection("meals")
            .doc(meal)
            .get();

    final mealNutritionLog = mealNutritionLogSnapshot.data() ?? {};

    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("nutritionLogs")
        .doc(date)
        .collection("meals")
        .doc(meal)
        .set({
          "totalCalories":
              (mealNutritionLog["totalCalories"] ?? 0) -
              (food["totalCalories"] ?? 0),
          "totalProtein":
              (mealNutritionLog["totalProtein"] ?? 0) -
              (food["totalProtein"] ?? 0),
          "totalCarbs":
              (mealNutritionLog["totalCarbs"] ?? 0) - (food["totalCarbs"] ?? 0),
          "totalFat":
              (mealNutritionLog["totalFat"] ?? 0) - (food["totalFat"] ?? 0),
        }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("nutritionLogs")
        .doc(date)
        .collection("meals")
        .doc(meal)
        .collection("items")
        .doc(foodId)
        .delete();

    NavigationUtils.pop(context);
  }

  String getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }
}
