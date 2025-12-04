import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/services/setting_service.dart';
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
  final SettingService _settingService = SettingService();

  bool isDarkMode = true;
  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    uid = user!.uid;
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final mode = await _settingService.loadThemeMode();
    if (!mounted) return;
    setState(() {
      isDarkMode = mode == ThemeMode.dark;
    });
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
        title: Text(widget.meal, style: TextStyle(color: AppColors.primary)),
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
              style: TextStyles.caption.copyWith(
                color: isDarkMode ? AppColors.black : AppColors.white,
              ),
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
                        .collection("foods")
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
                              : "${food['quantity'].toStringAsFixed(2) ?? '-'} grams ${food['foodName'] ?? 'Unnamed Food'}";

                      final subtitle =
                          "${food['totalCalories']?.toStringAsFixed(2) ?? '?'} kcal | "
                          "Protein: ${food['totalProtein']?.toStringAsFixed(2) ?? '?'}g | "
                          "Carbs: ${food['totalCarbs']?.toStringAsFixed(2) ?? '?'}g | "
                          "Fat: ${food['totalFat']?.toStringAsFixed(2) ?? '?'}g";

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
    if (user == null || !mounted) return;

    final uid = user.uid;
    final date = getTodayDateString();
    final meal = widget.meal.toLowerCase();
    final foodId = food['id'];

    // Show loading
    if (!mounted) return;
    QuickAlert.show(
      context: context,
      type: QuickAlertType.loading,
      text: "Deleting food...",
    );

    // 1️⃣ Delete the food item first
    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("nutritionLogs")
        .doc(date)
        .collection("foods")
        .doc(meal)
        .collection("items")
        .doc(foodId)
        .delete();

    // 2️⃣ Recalculate meal totals
    final mealSnapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("nutritionLogs")
            .doc(date)
            .collection("foods")
            .doc(meal)
            .collection("items")
            .get();

    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (var doc in mealSnapshot.docs) {
      final data = doc.data();
      totalCalories += (data["totalCalories"] ?? 0);
      totalProtein += (data["totalProtein"] ?? 0);
      totalCarbs += (data["totalCarbs"] ?? 0);
      totalFat += (data["totalFat"] ?? 0);
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
          "totalCalories": totalCalories,
          "totalProtein": totalProtein,
          "totalCarbs": totalCarbs,
          "totalFat": totalFat,
        });

    // 3️⃣ Recalculate daily totals by summing all meals
    final foodsSnapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("nutritionLogs")
            .doc(date)
            .collection("foods")
            .get();

    double dayCalories = 0;
    double dayProtein = 0;
    double dayCarbs = 0;
    double dayFat = 0;

    for (var doc in foodsSnapshot.docs) {
      if (doc.id == "totals") continue; // skip totals document
      final data = doc.data();
      dayCalories += (data["totalCalories"] ?? 0);
      dayProtein += (data["totalProtein"] ?? 0);
      dayCarbs += (data["totalCarbs"] ?? 0);
      dayFat += (data["totalFat"] ?? 0);
    }

    // Update daily totals
    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("nutritionLogs")
        .doc(date)
        .collection("foods")
        .doc("totals")
        .set({
          "totalCalories": dayCalories,
          "totalProtein": dayProtein,
          "totalCarbs": dayCarbs,
          "totalFat": dayFat,
        });

    // Close loading
    if (!mounted) return;
    NavigationUtils.pop(context);
  }

  String getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }
}
