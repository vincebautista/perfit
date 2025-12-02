import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/core/utils/validation_utils.dart';
import 'package:perfit/screens/create_meal_screen.dart';
import 'package:perfit/screens/my_meal_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';

class MyMealScreen extends StatefulWidget {
  final String meal;

  const MyMealScreen({super.key, required this.meal});

  @override
  State<MyMealScreen> createState() => _MyMealScreenState();
}

class _MyMealScreenState extends State<MyMealScreen> {
  String? uid;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    uid = user.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("My Meals"),
        actions: [
          TextButton(
            onPressed:
                () => NavigationUtils.push(
                  context,
                  CreateMealScreen(meal: widget.meal),
                ),
            child: Text("Create Meal", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body:
          uid == null
              ? Center(child: Text("User not logged in."))
              : StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection("users")
                        .doc(uid)
                        .collection("myMeals")
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text("No meals found."));
                  }

                  final meals = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: meals.length,
                    itemBuilder: (context, index) {
                      final mealDoc = meals[index];
                      final meal = mealDoc.data() as Map<String, dynamic>;
                      final mealId = mealDoc.id;

                      return Card(
                        child: ListTile(
                          title: Text(meal["mealName"] ?? "Unnamed Meal"),
                          subtitle: Text(
                            "Calories: ${meal["totalCalories"]?.toStringAsFixed(1) ?? "0"} kcal\n"
                            "Protein: ${meal["totalProtein"]?.toStringAsFixed(1) ?? "0"}g | "
                            "Carbs: ${meal["totalCarbs"]?.toStringAsFixed(1) ?? "0"}g | "
                            "Fat: ${meal["totalFat"]?.toStringAsFixed(1) ?? "0"}g",
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            onPressed: () => addMeal(meal, mealId),
                            icon: Icon(Icons.add),
                          ),
                          onTap:
                              () => NavigationUtils.push(
                                context,
                                MyMealDetailScreen(id: mealId),
                              ),
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }

  void addMeal(Map<String, dynamic> food, String mealId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final date = getTodayDateString();
    final meal = widget.meal.toLowerCase();
    final firestore = FirebaseFirestore.instance;

    // Show QuickAlert loading
    if (!mounted) return;
    QuickAlert.show(
      context: context,
      type: QuickAlertType.loading,
      text: 'Adding meal...',
      barrierDismissible: false,
    );

    try {
      final mealDocRef = firestore
          .collection("users")
          .doc(uid)
          .collection("nutritionLogs")
          .doc(date)
          .collection("foods")
          .doc(meal);

      final mealItemsRef = mealDocRef.collection("items");

      final foodsDocRef = firestore
          .collection("users")
          .doc(uid)
          .collection("nutritionLogs")
          .doc(date)
          .collection("foods")
          .doc("totals");

      final currentIntakeRef = firestore.collection("users").doc(uid);

      final totalCalories = (food["totalCalories"] ?? 0).toDouble();
      final totalProtein = (food["totalProtein"] ?? 0).toDouble();
      final totalCarbs = (food["totalCarbs"] ?? 0).toDouble();
      final totalFat = (food["totalFat"] ?? 0).toDouble();

      // Add meal item
      await mealItemsRef.add({
        "mealName": food["mealName"] ?? "Unnamed Meal",
        "totalCalories": totalCalories,
        "totalProtein": totalProtein,
        "totalCarbs": totalCarbs,
        "totalFat": totalFat,
        "type": "recipe",
        "mealId": mealId,
      });

      // Update meal totals
      await mealDocRef.set({
        "totalCalories": FieldValue.increment(totalCalories),
        "totalProtein": FieldValue.increment(totalProtein),
        "totalCarbs": FieldValue.increment(totalCarbs),
        "totalFat": FieldValue.increment(totalFat),
      }, SetOptions(merge: true));

      // Update daily totals
      final foodsSnapshot = await foodsDocRef.get();
      final foodsData = foodsSnapshot.data() ?? {};

      await foodsDocRef.set({
        "totalCalories": (foodsData["totalCalories"] ?? 0) + totalCalories,
        "totalProtein": (foodsData["totalProtein"] ?? 0) + totalProtein,
        "totalCarbs": (foodsData["totalCarbs"] ?? 0) + totalCarbs,
        "totalFat": (foodsData["totalFat"] ?? 0) + totalFat,
      }, SetOptions(merge: true));

      // Update user's current intake
      final userSnapshot = await currentIntakeRef.get();
      final userData = userSnapshot.data();
      final intake = userData?["currentIntake"] ?? {};

      await currentIntakeRef.set({
        "currentIntake": {
          "calories": (intake["calories"] ?? 0) + totalCalories,
          "protein": (intake["protein"] ?? 0) + totalProtein,
          "carbs": (intake["carbs"] ?? 0) + totalCarbs,
          "fat": (intake["fat"] ?? 0) + totalFat,
        },
      }, SetOptions(merge: true));

      // Dismiss loading alert and show success
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        text: 'Meal added successfully!',
      );
    } catch (e) {
      // Dismiss loading alert and show error
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        text: 'Failed to add meal: $e',
      );
    }
  }

  String getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }
}
