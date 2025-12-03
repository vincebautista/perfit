import 'package:perfit/data/models/nutrition_plan_model.dart';

class FitnessPlanModel {
  final int planDuration;
  final int currentDay;
  final NutritionPlanModel nutritionPlan;
  final String? lastWorkoutDate;
  final List<String>? feedbackHistory;
  final Map<String, dynamic> initialAssessment;

  /// NEW
  final List<int> workoutDays;
  final List<int> restDays;

  FitnessPlanModel({
    required this.planDuration,
    required this.currentDay,
    required this.nutritionPlan,
    this.lastWorkoutDate,
    this.feedbackHistory,
    required this.initialAssessment,
    required this.workoutDays,
    required this.restDays,
  });

  Map<String, dynamic> toMap() {
    return {
      'planDuration': planDuration,
      'currentDay': currentDay,
      'nutritionPlan': nutritionPlan.toMap(),
      'lastWorkoutDate': lastWorkoutDate,
      'feedbackHistory': feedbackHistory,
      'initialAssessment': initialAssessment,
      'workoutDays': workoutDays,
      'restDays': restDays,
    };
  }

  static FitnessPlanModel fromMap(Map<String, dynamic> map) {
    return FitnessPlanModel(
      planDuration: map['planDuration'],
      currentDay: map['currentDay'],
      nutritionPlan: NutritionPlanModel.fromMap(map['nutritionPlan']),
      lastWorkoutDate: map['lastWorkoutDate'],
      feedbackHistory: map['feedbackHistory'] != null
          ? List<String>.from(map['feedbackHistory'])
          : null,
      initialAssessment: Map<String, dynamic>.from(map['initialAssessment']),

      /// NEW
      workoutDays: map['workoutDays'] != null
          ? List<int>.from(map['workoutDays'])
          : [],
      restDays: map['restDays'] != null
          ? List<int>.from(map['restDays'])
          : [],
    );
  }
}
