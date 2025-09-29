import 'package:flutter/material.dart';

class FoodItem {
  final String foodName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double quantity;
  final String unit;

  FoodItem({
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.quantity,
    required this.unit,
  });
}

class MealProvider extends ChangeNotifier {
  List<FoodItem> _foods = [];

  List<FoodItem> get foods => _foods;

  double get totalCalories {
    double sum = 0;
    for (var food in _foods) {
      sum += food.calories;
    }
    return sum;
  }

  double get totalProtein {
    double sum = 0;
    for (var food in _foods) {
      sum += food.protein;
    }
    return sum;
  }

  double get totalCarbs {
    double sum = 0;
    for (var food in _foods) {
      sum += food.carbs;
    }
    return sum;
  }

  double get totalFat {
    double sum = 0;
    for (var food in _foods) {
      sum += food.fat;
    }
    return sum;
  }

  void addFood(FoodItem food) {
    _foods.add(food);
    notifyListeners();
  }

  void removeFood(int index) {
    _foods.removeAt(index);
    notifyListeners();
  }

  void clearMeal() {
    _foods.clear();
    notifyListeners();
  }
}
