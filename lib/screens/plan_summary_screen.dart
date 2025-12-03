import 'dart:convert';
import 'package:gap/gap.dart';
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/services/exercise_service.dart';
import 'package:perfit/core/services/firebase_firestore_service.dart';
import 'package:perfit/core/services/notification_service.dart';
import 'package:perfit/core/services/setting_service.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/data/models/fitness_plan_model.dart';
import 'package:perfit/data/models/nutrition_plan_model.dart';
import 'package:perfit/screens/main_navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class PlanSummaryScreen extends StatefulWidget {
  const PlanSummaryScreen({super.key});

  @override
  State<PlanSummaryScreen> createState() => _PlanSummaryScreenState();
}

class _PlanSummaryScreenState extends State<PlanSummaryScreen> {
  final exerciseService = ExerciseService();
  late Future<String> _planFuture;

  int? planDuration;
  double? calorieTarget, protein, carb, fat;

  Map<String, List<int>> goalMacroSplits = {
    "Lose fat": [40, 30, 30],
    "Build muscle": [30, 50, 20],
    "General health and fitness": [30, 40, 30],
  };

  @override
  void initState() {
    super.initState();
    _planFuture = saveFitnessPlan();
  }

  Future<String> saveFitnessPlan() async {
    try {
      Map<String, dynamic> userAnswers =
          Provider.of<AssessmentModel>(context, listen: false).answers;

      String finalActivityLevel = exerciseService.determineFinalActivityLevel(
        dailyActivityLevel: userAnswers["activityLevel"],
        workoutDays: int.parse(userAnswers["workoutCommitment"]),
      );

      double bmr = exerciseService.calculateBMR(
        gender: userAnswers["gender"],
        age: int.parse(userAnswers["age"]),
        height: double.parse(userAnswers["height"]),
        weight: double.parse(userAnswers["weight"]),
      );

      double tdee = exerciseService.calculateTDEE(
        bmr: bmr,
        activityLevel: finalActivityLevel,
      );

      if (userAnswers["fitnessGoal"] == "Lose fat") {
        calorieTarget = tdee - 500;
      } else if (userAnswers["fitnessGoal"] == "Build muscle") {
        calorieTarget = tdee + 300;
      } else {
        calorieTarget = tdee;
      }

      planDuration = exerciseService.calculateWeeks(
        weight: double.parse(userAnswers["weight"]),
        targetWeight:
            double.tryParse(userAnswers["targetWeight"] ?? "") ??
            double.parse(userAnswers["weight"]),
        goal: userAnswers["fitnessGoal"],
      );

      List<int> macroSplit = goalMacroSplits[userAnswers["fitnessGoal"]]!;

      protein = (calorieTarget! * (macroSplit[0] / 100)) / 4;
      carb = (calorieTarget! * (macroSplit[1] / 100)) / 4;
      fat = (calorieTarget! * (macroSplit[2] / 100)) / 9;

      NutritionPlanModel nutritionPlan = NutritionPlanModel(
        calorieTarget: calorieTarget!.round(),
        protein: protein!.round(),
        carb: carb!.round(),
        fat: fat!.round(),
      );

      int workoutCount;
      if (userAnswers["workoutCommitment"] is String) {
        workoutCount = int.parse(userAnswers["workoutCommitment"]);
      } else {
        workoutCount = userAnswers["workoutCommitment"] as int;
      }
      List<int> workoutDays = List.generate(workoutCount, (i) => i + 1);
      List<int> restDays = List.generate(
        7 - workoutCount,
        (i) => workoutCount + i + 1,
      );

      FitnessPlanModel fitnessPlan = FitnessPlanModel(
        planDuration: planDuration!,
        currentDay: 1,
        nutritionPlan: nutritionPlan,
        initialAssessment: userAnswers,
        workoutDays: workoutDays,
        restDays: restDays,
      );

      String generatedTarget = await exerciseService.generateTarget(
        fitnessPlan,
      );

      final List<Map<String, dynamic>> workouts =
          List<Map<String, dynamic>>.from(jsonDecode(generatedTarget));

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final planId = await FirebaseFirestoreService().saveFitnessPlan(
          user.uid,
          fitnessPlan,
          workouts,
        );
        await FirebaseFirestoreService().setAssessmentDone(user.uid, true);

        final startingWeight = double.parse(userAnswers["weight"]);
        final startDateId = DateFormat("M-d-yyyy").format(DateTime.now());

        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection("fitnessPlan")
            .doc(planId)
            .collection("weightLogs")
            .doc(startDateId)
            .set({
              "kg": startingWeight,
              "timestamp": FieldValue.serverTimestamp(),
            });
      } else {
        throw Exception("User not logged in.");
      }

      return generatedTarget;
    } catch (e) {
      throw Exception("Error: $e");
    }
  }

  Future<void> saveWorkouts(
    String uid,
    String planId,
    List<dynamic> workouts,
  ) async {
    final planRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('fitnessPlans')
        .doc(planId)
        .collection('workouts');

    for (var dayData in workouts) {
      final String dayId = dayData["day"].toString();
      await planRef.doc(dayId).set(dayData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<String>(
        future: _planFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  Gap(50),
                  Text("Generating your plan...", style: TextStyles.body),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Center(child: Text("${snapshot.error}"));
          } else {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.padding20),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: const Color.fromARGB(80, 255, 255, 255),
                    elevation: 100,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.padding20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Your daily net calorie goal is:",
                            style: TextStyles.body,
                            textAlign: TextAlign.center,
                          ),
                          Gap(AppSizes.gap10),
                          Text(
                            "${calorieTarget?.round() ?? 0} kcal",
                            style: TextStyles.heading,
                            textAlign: TextAlign.center,
                          ),
                          Gap(AppSizes.gap20),
                          Text(
                            "With this $planDuration-week plan, you should aim:",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Gap(AppSizes.gap10),
                          Card(
                            color: AppColors.primary,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                "${protein?.round() ?? 0}g protein",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.white,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          Card(
                            color: AppColors.primary,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                "${carb?.round() ?? 0}g carbs",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.white,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          Card(
                            color: AppColors.primary,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                "${fat?.round() ?? 0}g fat",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.white,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await SettingService().saveReminder(6, 0);
                        await NotificationService.scheduleNotification(
                          title: "Reminder",
                          body: "Workout Reminder",
                          hour: 6,
                          minute: 0,
                        );

                        if (!mounted) return;
                        NavigationUtils.pushAndRemoveUntil(
                          context,
                          MainNavigation(),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        child: Text("Start my plan"),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
