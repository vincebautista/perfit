import 'package:perfit/data/models/nutrition_plan_model.dart';

class FitnessPlanModel {
  final int planDuration;
  final int currentDay;
  final NutritionPlanModel nutritionPlan;
  final String? lastWorkoutDate;
  final List<String>? feedbackHistory;
  final Map<String, dynamic> initialAssessment;

  FitnessPlanModel({
    required this.planDuration,
    required this.currentDay,
    required this.nutritionPlan,
    this.lastWorkoutDate,
    this.feedbackHistory,
    required this.initialAssessment,
  });

  Map<String, dynamic> toMap() {
    return {
      'planDuration': planDuration,
      'currentDay': currentDay,
      'nutritionPlan': nutritionPlan.toMap(),
      'lastWorkoutDate': lastWorkoutDate ?? null,
      'feedbackHistory': feedbackHistory ?? null,
      'initialAssessment': initialAssessment,
    };
  }

  static FitnessPlanModel fromMap(Map<String, dynamic> fitnessPlan) {
    return FitnessPlanModel(
      planDuration: fitnessPlan["planDuration"],
      currentDay: fitnessPlan["currentDay"],
      nutritionPlan: NutritionPlanModel.fromMap(fitnessPlan["nutritionPlan"]),
      lastWorkoutDate: fitnessPlan["lastWorkoutDate"],
      feedbackHistory:
          fitnessPlan["feedbackHistory"] != null
              ? List<String>.from(fitnessPlan["feedbackHistory"])
              : null,
      initialAssessment: Map<String, dynamic>.from(
        fitnessPlan["initialAssessment"],
      ),
    );
  }
}
