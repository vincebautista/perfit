import 'package:flutter/material.dart';

class AssessmentModel with ChangeNotifier {
  final Map<String, dynamic> _answers = {};

  void updateAnswer(String key, dynamic value) {
    _answers[key] = value;

    notifyListeners();
  }

  dynamic getAnswer(String key) => _answers[key];

  Map<String, dynamic> get answers => _answers;
}

class AssessmentAnswer {
  final String key;
  dynamic value;

  AssessmentAnswer({required this.key, required this.value});
}
