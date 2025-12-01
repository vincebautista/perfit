import 'package:flutter/material.dart';

class AssessmentModel with ChangeNotifier {
  final Map<String, dynamic> _answers = {};

  void updateAnswer(String key, dynamic value) {
    _answers[key] = value;

    notifyListeners();
  }

  dynamic getAnswer(String key) => _answers[key];

  Map<String, dynamic> get answers => _answers;

  String suggestBodyType() {
    final weight = double.tryParse(_answers["weight"].toString());
    final height = double.tryParse(_answers["height"].toString());
    final experience = _answers["previousExperience"];
    final activity = _answers["activityLevel"];

    if (weight == null || height == null) return "Medium";

    final bmi = weight / ((height / 100) * (height / 100));

    if (bmi < 19) {
      return "Skinny";
    } else if (bmi < 24) {
      if (experience == "Beginner" || activity == "Low") {
        return "Flabby";
      }
      return "Medium";
    } else if (bmi < 28) {
      return "Flabby";
    } else {
      return "Flabby";
    }
  }
}

class AssessmentAnswer {
  final String key;
  dynamic value;

  AssessmentAnswer({required this.key, required this.value});
}
