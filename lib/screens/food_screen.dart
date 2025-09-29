import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/screens/meal_analytics_screen.dart';
import 'package:perfit/screens/meal_screen.dart';
import 'package:perfit/screens/nutrition_dashboard.dart';
import 'package:perfit/widgets/macro_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

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

    uid = user!.uid;
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
      appBar: AppBar(
        title: Text("Meal Plan", style: TextStyle(color: AppColors.primary)),
        centerTitle: true,
      ),
      body: FutureBuilder(
        future: getNutritionPlan(),
        builder: (context, nutritionPlanSnapshot) {
          if (nutritionPlanSnapshot.connectionState ==
              ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (nutritionPlanSnapshot.hasError) {
            return Center(child: Text("Error: ${nutritionPlanSnapshot.error}"));
          }

          final nutritionPlan = nutritionPlanSnapshot.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.gap20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StreamBuilder(
                  stream:
                      FirebaseFirestore.instance
                          .collection("users")
                          .doc(uid)
                          .collection("nutritionLogs")
                          .doc(getTodayDateString())
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
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
                Text("Meals", style: TextStyles.body),
                Gap(AppSizes.gap10),
                StreamBuilder(
                  stream:
                      FirebaseFirestore.instance
                          .collection("users")
                          .doc(uid)
                          .collection("nutritionLogs")
                          .doc(getTodayDateString())
                          .collection("meals")
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
                        child: Column(
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
                                    "Add breakfast",
                                    style: TextStyle(color: AppColors.white),
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
                          .collection("meals")
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
                                    "Add Lunch",
                                    style: TextStyle(color: AppColors.white),
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
                          .collection("meals")
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
                                    "Add Dinner",
                                    style: TextStyle(color: AppColors.white),
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
                          .collection("meals")
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
                                    "Add Snacks",
                                    style: TextStyle(color: AppColors.white),
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

// return Scaffold(
//       appBar: AppBar(
//         title: Text("Meal Plan", style: TextStyle(color: AppColors.primary)),
//         centerTitle: true,
//       ),
//       body: StreamBuilder(
//         stream:
//             FirebaseFirestore.instance
//                 .collection("users")
//                 .doc(user!.uid)
//                 .collection("nutritionLogs")
//                 .doc(getTodayDateString())
//                 .snapshots(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           }

//           if (snapshot.hasError) {
//             return Center(child: Text("Error: ${snapshot.error}"));
//           }

//           final data = snapshot.data!.data();

//           final totalCalories = data?["totalCalories"] ?? 0;
//           final totalProtein = data?["totalProtein"] ?? 0;
//           final totalCarbs = data?["totalCarbs"] ?? 0;
//           final totalFat = data?["totalFat"] ?? 0;

//           final totalBreakfastCalories = 0;
//           final totalLunchCalories = 0;
//           final totalDinnerCalories = 0;
//           final totalSnacksCalories = 0;

//           print(totalCalories);
//           print(totalProtein);
//           print(totalCarbs);
//           print(totalFat);
//           print(totalBreakfastCalories);
//           print(totalLunchCalories);
//           print(totalDinnerCalories);
//           print(totalSnacksCalories);

//           return FutureBuilder(
//             future: getNutritionPlan(),
//             builder: (context, nutritionPlanSnapshot) {
//               if (nutritionPlanSnapshot.connectionState ==
//                   ConnectionState.waiting) {
//                 return Center(child: CircularProgressIndicator());
//               }

//               if (nutritionPlanSnapshot.hasError) {
//                 return Center(
//                   child: Text("Error: ${nutritionPlanSnapshot.error}"),
//                 );
//               }

//               final nutritionPlan = nutritionPlanSnapshot.data;

//               print(nutritionPlan);

//               return SingleChildScrollView(
//                 padding: const EdgeInsets.all(AppSizes.gap20),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text("Today", style: TextStyles.body),
//                         Stack(
//                           alignment: Alignment.center,
//                           children: [
//                             HalfCircleProgress(
//                               progress:
//                                   (totalCalories as num).toDouble() /
//                                   (nutritionPlan!["calorieTarget"] as num)
//                                       .toDouble(),
//                             ),
//                             Positioned(
//                               top: 30,
//                               child: Column(
//                                 children: [
//                                   Text(
//                                     totalCalories.toDouble().toStringAsFixed(1),
//                                     style: TextStyles.title,
//                                   ),
//                                   Text(
//                                     "of ${(nutritionPlan["calorieTarget"] as num).toDouble().toStringAsFixed(1)} kcal",
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                         IconButton(
//                           iconSize: 30,
//                           padding: EdgeInsets.all(0),
//                           onPressed:
//                               () => NavigationUtils.push(
//                                 context,
//                                 MealAnalyticsScreen(),
//                               ),
//                           icon: Icon(Icons.analytics),
//                         ),
//                       ],
//                     ),
//                     Gap(AppSizes.gap20 * 2),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceAround,
//                       children: [
//                         MacroProgressBar(
//                           label: "Protein",
//                           currentValue: (totalProtein as num).toDouble(),
//                           goal: (nutritionPlan["protein"] as num).toDouble(),
//                           barColor: AppColors.primary,
//                         ),
//                         MacroProgressBar(
//                           label: "Carbs",
//                           currentValue: (totalCarbs as num).toDouble(),
//                           goal: (nutritionPlan["carb"] as num).toDouble(),
//                           barColor: AppColors.primary,
//                         ),
//                         MacroProgressBar(
//                           label: "Fat",
//                           currentValue: (totalFat as num).toDouble(),
//                           goal: (nutritionPlan["fat"] as num).toDouble(),
//                           barColor: AppColors.primary,
//                         ),
//                       ],
//                     ),
//                     Gap(AppSizes.gap20 * 1.5),
//                     Text(
//                       "Meals",
//                       style: TextStyles.body.copyWith(fontSize: 24),
//                     ),
//                     Gap(AppSizes.gap10),
//                     Card(
//                       child: Padding(
//                         padding: const EdgeInsets.only(
//                           top: AppSizes.gap15,
//                           right: AppSizes.gap15,
//                           left: AppSizes.gap15,
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text("Breakfast", style: TextStyles.body),
//                             Row(
//                               children: [
//                                 Text(
//                                   "${(totalBreakfastCalories).toDouble().toStringAsFixed(1)} kcal",
//                                 ),
//                                 Gap(AppSizes.gap15),
//                                 TextButton(
//                                   onPressed:
//                                       () => NavigationUtils.push(
//                                         context,
//                                         MealScreen(meal: "Breakfast"),
//                                       ),
//                                   child: Text("Add breakfast"),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     Gap(AppSizes.gap10),
//                     Card(
//                       child: Padding(
//                         padding: const EdgeInsets.only(
//                           top: AppSizes.gap15,
//                           right: AppSizes.gap15,
//                           left: AppSizes.gap15,
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text("Lunch", style: TextStyles.body),
//                             Row(
//                               children: [
//                                 Text(
//                                   "${(totalLunchCalories).toDouble().toStringAsFixed(1)} kcal",
//                                 ),
//                                 Gap(AppSizes.gap15),
//                                 TextButton(
//                                   onPressed:
//                                       () => NavigationUtils.push(
//                                         context,
//                                         MealScreen(meal: "Lunch"),
//                                       ),
//                                   child: Text("Add lunch"),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     Gap(AppSizes.gap10),
//                     Card(
//                       child: Padding(
//                         padding: const EdgeInsets.only(
//                           top: AppSizes.gap15,
//                           right: AppSizes.gap15,
//                           left: AppSizes.gap15,
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text("Dinner", style: TextStyles.body),
//                             Row(
//                               children: [
//                                 Text(
//                                   "${(totalDinnerCalories).toDouble().toStringAsFixed(1)} kcal",
//                                 ),
//                                 Gap(AppSizes.gap15),
//                                 TextButton(
//                                   onPressed:
//                                       () => NavigationUtils.push(
//                                         context,
//                                         MealScreen(meal: "Dinner"),
//                                       ),
//                                   child: Text("Add dinner"),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     Gap(AppSizes.gap10),
//                     Card(
//                       child: Padding(
//                         padding: const EdgeInsets.only(
//                           top: AppSizes.gap15,
//                           right: AppSizes.gap15,
//                           left: AppSizes.gap15,
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text("Snacks", style: TextStyles.body),
//                             Row(
//                               children: [
//                                 Text(
//                                   "${(totalSnacksCalories).toDouble().toStringAsFixed(1)} kcal",
//                                 ),
//                                 Gap(AppSizes.gap15),
//                                 TextButton(
//                                   onPressed:
//                                       () => NavigationUtils.push(
//                                         context,
//                                         MealScreen(meal: "Snack"),
//                                       ),
//                                   child: Text("Add snack"),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
