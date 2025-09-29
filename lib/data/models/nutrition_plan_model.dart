class NutritionPlanModel {
  final int calorieTarget;
  final int protein;
  final int carb;
  final int fat;

  NutritionPlanModel({
    required this.calorieTarget,
    required this.protein,
    required this.carb,
    required this.fat,
  });

  Map<String, dynamic> toMap() {
    return {
      'calorieTarget': calorieTarget,
      'protein': protein,
      'carb': carb,
      'fat': fat,
    };
  }

  static NutritionPlanModel fromMap(Map<String, dynamic> nutritionPlan) {
    return NutritionPlanModel(
      calorieTarget: nutritionPlan["calorieTarget"],
      protein: nutritionPlan["protein"],
      carb: nutritionPlan["carb"],
      fat: nutritionPlan["fat"],
    );
  }
}
