import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/screens/assessment/gender_screen.dart';
import 'package:perfit/screens/meal_analytics_screen.dart';
import 'package:perfit/screens/meal_screen.dart';
import 'package:perfit/screens/nutrition_dashboard.dart';
import 'package:perfit/widgets/macro_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:perfit/widgets/walk_animation.dart';

class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key});

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  String? uid;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      uid = user.uid;
    }
  }

  Future<Map<String, dynamic>> getNutritionPlan() async {
    final docs =
        await FirebaseFirestore.instance.collection("users").doc(uid).get();

    final data = docs.data();
    final activePlan = data!["activeFitnessPlan"];

    final fitnessPlanDoc =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("fitnessPlan")
            .doc(activePlan)
            .get();

    final fitnessPlan = fitnessPlanDoc.data();

    return fitnessPlan!["nutritionPlan"];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Food")),
      body: FutureBuilder(
        future: getNutritionPlan(),
        builder: (context, nutritionPlanSnapshot) {
          if (nutritionPlanSnapshot.connectionState ==
              ConnectionState.waiting) {
            return Center(child: WalkAnimation());
          }

          if (nutritionPlanSnapshot.hasError) {
            return Center(
              child: GestureDetector(
                onTap: () => NavigationUtils.push(context, GenderScreen()),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primary, // line color
                      width: 1.0, // line thickness
                    ),
                    borderRadius: BorderRadius.circular(
                      8,
                    ), // optional: rounded corners
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.padding16,
                    vertical: AppSizes.padding16 / 2,
                  ),
                  child: Text(
                    "Create Fitness Plan",
                    style: TextStyles.body.copyWith(color: AppColors.primary),
                  ),
                ),
              ),
            );
          }

          final nutritionPlan = nutritionPlanSnapshot.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.gap20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreamBuilder(
                  stream:
                      FirebaseFirestore.instance
                          .collection("users")
                          .doc(uid)
                          .collection("nutritionLogs")
                          .doc(getTodayDateString())
                          .collection('foods')
                          .doc('totals')
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: WalkAnimation());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }

                    final data = snapshot.data!.data();

                    final totalCalories = data?["totalCalories"] ?? 0;
                    final totalProtein = data?["totalProtein"] ?? 0;
                    final totalCarbs = data?["totalCarbs"] ?? 0;
                    final totalFat = data?["totalFat"] ?? 0;

                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Today", style: TextStyles.body),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                HalfCircleProgress(
                                  progress:
                                      (totalCalories as num).toDouble() /
                                      (nutritionPlan!["calorieTarget"] as num)
                                          .toDouble(),
                                ),
                                Positioned(
                                  top: 30,
                                  child: Column(
                                    children: [
                                      Text(
                                        totalCalories
                                            .toDouble()
                                            .toStringAsFixed(1),
                                        style: TextStyles.title,
                                      ),
                                      Text(
                                        "of ${(nutritionPlan["calorieTarget"] as num).toDouble().toStringAsFixed(1)} kcal",
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              iconSize: 30,
                              padding: EdgeInsets.all(0),
                              onPressed:
                                  () => NavigationUtils.push(
                                    context,
                                    MealAnalyticsScreen(),
                                  ),
                              icon: Icon(Icons.analytics),
                            ),
                          ],
                        ),
                        Gap(AppSizes.gap20 * 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            MacroProgressBar(
                              label: "Protein",
                              currentValue: (totalProtein as num).toDouble(),
                              goal:
                                  (nutritionPlan["protein"] as num).toDouble(),
                              barColor: AppColors.primary,
                            ),
                            MacroProgressBar(
                              label: "Carbs",
                              currentValue: (totalCarbs as num).toDouble(),
                              goal: (nutritionPlan["carb"] as num).toDouble(),
                              barColor: AppColors.primary,
                            ),
                            MacroProgressBar(
                              label: "Fat",
                              currentValue: (totalFat as num).toDouble(),
                              goal: (nutritionPlan["fat"] as num).toDouble(),
                              barColor: AppColors.primary,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                Gap(AppSizes.gap20),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: const Text(
                    "Meals",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Gap(AppSizes.gap10),
                StreamBuilder(
                  stream:
                      FirebaseFirestore.instance
                          .collection("users")
                          .doc(uid)
                          .collection("nutritionLogs")
                          .doc(getTodayDateString())
                          .collection("foods")
                          .doc("breakfast")
                          .snapshots(),
                  builder: (context, snapshot) {
                    double totalCalories = 0;

                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data();
                      totalCalories = (data?["totalCalories"] ?? 0).toDouble();
                    }

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: AppSizes.gap15,
                          right: AppSizes.gap15,
                          left: AppSizes.gap15,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Breakfast", style: TextStyles.body),
                                Row(
                                  children: [
                                    Text(
                                      "${(totalCalories).toDouble().toStringAsFixed(1)} kcal",
                                    ),
                                    Gap(AppSizes.gap15),
                                    TextButton(
                                      onPressed:
                                          () => NavigationUtils.push(
                                            context,
                                            MealScreen(meal: "Breakfast"),
                                          ),
                                      child: Text(
                                        "View Meals",
                                        style: TextStyle(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSizes.gap15,
                              ),
                              child: IconButton(
                                onPressed:
                                    () => NavigationUtils.push(
                                      context,
                                      MealScreen(meal: "Breakfast"),
                                    ),
                                icon: Icon(Icons.add),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Gap(AppSizes.gap10),
                StreamBuilder(
                  stream:
                      FirebaseFirestore.instance
                          .collection("users")
                          .doc(uid)
                          .collection("nutritionLogs")
                          .doc(getTodayDateString())
                          .collection("foods")
                          .doc("lunch")
                          .snapshots(),
                  builder: (context, snapshot) {
                    double totalCalories = 0;

                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data();
                      totalCalories = (data?["totalCalories"] ?? 0).toDouble();
                    }

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: AppSizes.gap15,
                          right: AppSizes.gap15,
                          left: AppSizes.gap15,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Lunch", style: TextStyles.body),
                            Row(
                              children: [
                                Text(
                                  "${(totalCalories).toDouble().toStringAsFixed(1)} kcal",
                                ),
                                Gap(AppSizes.gap15),
                                TextButton(
                                  onPressed:
                                      () => NavigationUtils.push(
                                        context,
                                        MealScreen(meal: "Lunch"),
                                      ),
                                  child: Text(
                                    "View Lunch",
                                    style: TextStyle(color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Gap(AppSizes.gap10),
                StreamBuilder(
                  stream:
                      FirebaseFirestore.instance
                          .collection("users")
                          .doc(uid)
                          .collection("nutritionLogs")
                          .doc(getTodayDateString())
                          .collection("foods")
                          .doc("dinner")
                          .snapshots(),
                  builder: (context, snapshot) {
                    double totalCalories = 0;

                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data();
                      totalCalories = (data?["totalCalories"] ?? 0).toDouble();
                    }

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: AppSizes.gap15,
                          right: AppSizes.gap15,
                          left: AppSizes.gap15,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Dinner", style: TextStyles.body),
                            Row(
                              children: [
                                Text(
                                  "${(totalCalories).toDouble().toStringAsFixed(1)} kcal",
                                ),
                                Gap(AppSizes.gap15),
                                TextButton(
                                  onPressed:
                                      () => NavigationUtils.push(
                                        context,
                                        MealScreen(meal: "Dinner"),
                                      ),
                                  child: Text(
                                    "View Dinner",
                                    style: TextStyle(color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Gap(AppSizes.gap10),
                StreamBuilder(
                  stream:
                      FirebaseFirestore.instance
                          .collection("users")
                          .doc(uid)
                          .collection("nutritionLogs")
                          .doc(getTodayDateString())
                          .collection("foods")
                          .doc("snacks")
                          .snapshots(),
                  builder: (context, snapshot) {
                    double totalCalories = 0;

                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data();
                      totalCalories = (data?["totalCalories"] ?? 0).toDouble();
                    }

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: AppSizes.gap15,
                          right: AppSizes.gap15,
                          left: AppSizes.gap15,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Snacks", style: TextStyles.body),
                            Row(
                              children: [
                                Text(
                                  "${(totalCalories).toDouble().toStringAsFixed(1)} kcal",
                                ),
                                Gap(AppSizes.gap15),
                                TextButton(
                                  onPressed:
                                      () => NavigationUtils.push(
                                        context,
                                        MealScreen(meal: "Snacks"),
                                      ),
                                  child: Text(
                                    "View Snacks",
                                    style: TextStyle(color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }
}
