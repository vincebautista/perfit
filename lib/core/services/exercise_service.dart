import 'dart:convert';

import 'package:perfit/core/services/gemini_api_service.dart';
import 'package:perfit/data/data_sources/exercise_list.dart';
import 'package:perfit/data/models/exercise_metrics_model.dart';
import 'package:perfit/data/models/fitness_plan_model.dart';

enum DayType { workout, rest }

class ExerciseService {
  final geminiService = GeminiApiService();

  // Convert weekday text to index
  final Map<String, int> weekdayToIndex = {
    "Monday": 0,
    "Tuesday": 1,
    "Wednesday": 2,
    "Thursday": 3,
    "Friday": 4,
    "Saturday": 5,
    "Sunday": 6,
  };

  int calculateWeeks({
    required double weight,
    required double targetWeight,
    required String goal,
  }) {
    int weeks = 0;

    if (goal == "Lose fat") {
      double weightDifference = weight - targetWeight;

      double calorieDeficit = weightDifference * 7700;
      int days = (calorieDeficit / 500).ceil();
      weeks = (days / 7).ceil();
    } else if (goal == "Build muscle") {
      double weightDifference = targetWeight - weight;
      weeks = (weightDifference / 0.3).ceil();
    } else if (goal == "General health and fitness") {
      weeks = 8;
    }

    return weeks.ceil();
  }

  double calculateBMR({
    required String gender,
    required int age,
    required double height,
    required double weight,
  }) {
    if (gender == "male") {
      return (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      return (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }
  }

  double calculateTDEE({required double bmr, required String activityLevel}) {
    if (activityLevel == "Sedentary") return bmr * 1.2;
    if (activityLevel == "Lightly active") return bmr * 1.375;
    if (activityLevel == "Moderately active") return bmr * 1.55;
    return bmr * 1.725;
  }

  String determineFinalActivityLevel({
    required String dailyActivityLevel,
    required int workoutDays,
  }) {
    if (dailyActivityLevel == "Sedentary" ||
        dailyActivityLevel == "Lightly active") {
      return workoutDays >= 5 ? "Very active" : "Moderately active";
    } else {
      return "Very active";
    }
  }

  /// 🔥 Create dynamic WEEK schedule from user selections
  List<DayType> buildWeeklySchedule(FitnessPlanModel fitnessPlan) {
    List<DayType> schedule = List.filled(7, DayType.workout);

    // convert rest days (names → index)
    for (int day in fitnessPlan.restDays) {
      int idx = day - 1; // convert day number to index (1→0)
      if (idx >= 0 && idx < 7) {
        schedule[idx] = DayType.rest;
      }
    }

    // all other days automatically become workout days
    return schedule;
  }

  /// 🔥 Simple dynamic split generator (consistent per week)
  List<String> generateSplits(FitnessPlanModel fitnessPlan) {
    int workoutCount = fitnessPlan.workoutDays.length;

    if (workoutCount == 1) return ["Full Body"];
    if (workoutCount == 2) return ["Upper Body", "Lower Body"];
    if (workoutCount == 3) return ["Push", "Pull", "Legs"];
    if (workoutCount == 4) return ["Upper", "Lower", "Push", "Pull"];
    if (workoutCount == 5)
      return ["Push", "Pull", "Legs", "Upper", "Full Body"];
    if (workoutCount == 6)
      return ["Push", "Pull", "Legs", "Upper", "Lower", "Full Body"];

    return ["Full Body"];
  }

  List<String> createDynamicWeeklySplits(List<DayType> schedule) {
    int push = 0, pull = 0, legs = 0;

    return schedule.map((day) {
      if (day == DayType.rest) return "Rest";

      if (push == pull && pull == legs) {
        push++;
        return "Push";
      } else if (push > pull) {
        pull++;
        return "Pull";
      } else {
        legs++;
        return "Legs";
      }
    }).toList();
  }

  List<DayType> createDynamicWeeklySchedule({
    required List<String> restDays,
    required List<String> allDays,
  }) {
    return allDays.map((dayName) {
      return restDays.contains(dayName) ? DayType.rest : DayType.workout;
    }).toList();
  }

  Future<String> generateTarget(FitnessPlanModel fitnessPlan) async {
    final userAnswers = fitnessPlan.initialAssessment;

    String availableExercises = formatExercisesForPrompt(
      userAnswers["workoutLocation"],
    );

    // 🔥 dynamic based on user-select rest days
    final weeklySchedule = buildWeeklySchedule(fitnessPlan);
    final weeklySplits = generateSplits(fitnessPlan);

    final workoutDaysString =
        weeklySchedule
            .asMap()
            .entries
            .where((e) => e.value == DayType.workout)
            .map((e) => e.key + 1)
            .toList()
            .toString();

    final restDaysString =
        weeklySchedule
            .asMap()
            .entries
            .where((e) => e.value == DayType.rest)
            .map((e) => e.key + 1)
            .toList()
            .toString();

    int totalWeeks = fitnessPlan.planDuration;
    int batchSize = 4;
    List<Map<String, dynamic>> mergedDays = [];

    int dayCounter = 1;

    for (int startWeek = 1; startWeek <= totalWeeks; startWeek += batchSize) {
      int endWeek =
          (startWeek + batchSize - 1 > totalWeeks)
              ? totalWeeks
              : startWeek + batchSize - 1;

      int startDay = dayCounter;
      int endDay = startDay + ((endWeek - startWeek + 1) * 7) - 1;

      String prompt = '''
You are an expert fitness coach creating a workout plan for Days $startDay–$endDay. Respond ONLY in JSON.

Client Profile:
- Gender: ${userAnswers["gender"]}
- Age: ${userAnswers["age"]}
- Height: ${userAnswers["height"]} cm
- Weight: ${userAnswers["weight"]} kg
- Target Weight: ${userAnswers["targetWeight"] ?? userAnswers["weight"]} kg
- Body Type: ${userAnswers["bodyType"]}
- Fitness Goal: ${userAnswers["fitnessGoal"]}
- Training Level: ${userAnswers["trainingLevel"]}
- Experience: ${userAnswers["previousExperience"]}
- Workout Location: ${userAnswers["workoutLocation"]}

Workout Days (day numbers): $workoutDaysString
Rest Days (day numbers): $restDaysString

Workout Exercises to use:
$availableExercises

Rules:
- ONLY generate workouts on the listed Workout Days; all other days MUST be Rest.
- Each workout day must include 5–8 exercises.
- Choose split types from: ${weeklySplits.toString()}
- Include exact sets, reps, rest, or duration.
- Day numbers must continue across all weeks.
- Do NOT add exercises not listed.
- No explanations — only valid JSON.

Output Format:
[
  {
    "day": $startDay,
    "type": "Workout",
    "split": "Lower Body",
    "exercises": [
      {"name": "Bodyweight Squat", "sets": 3, "rest": 60, "reps": 10}
    ]
  },
  {
    "day": ${startDay + 1},
    "type": "Rest"
  }
]
''';

      final rawResponse = await geminiService.fetchFromGemini(prompt);

      if (rawResponse != null && rawResponse.trim().isNotEmpty) {
        try {
          String cleaned =
              rawResponse
                  .replaceAll("```json", "")
                  .replaceAll("```", "")
                  .trim();

          final parsed = jsonDecode(cleaned);

          if (parsed is List) {
            mergedDays.addAll(parsed.cast<Map<String, dynamic>>());
          }
        } catch (e) {
          print("JSON parsing error: $e");
          print("Raw: $rawResponse");
        }
      }

      dayCounter = endDay + 1;
    }

    return const JsonEncoder.withIndent("  ").convert(mergedDays);
  }

  String formatList(List<dynamic>? list) {
    if (list == null || list.isEmpty) return "None";
    return list.join(", ");
  }

  List<ExerciseMetricsModel> cleanJson(String response) {
    String workoutJson =
        response.replaceAll("```json", "").replaceAll("```", "").trim();

    final decoded = jsonDecode(workoutJson);

    if (decoded is List) {
      return decoded
          .map<ExerciseMetricsModel>(
            (exercise) => ExerciseMetricsModel.parseExercise(exercise),
          )
          .toList();
    }

    return [];
  }

  String formatExercisesForPrompt(String workoutLocation) {
    final locationFiltered =
        exercises.where((e) => e.location == workoutLocation).toList();

    return locationFiltered.map((e) => "- ${e.name}").join("\n");
  }

  int parseDuration(dynamic value) {
    if (value == null) return 0;
    final match = RegExp(r'\d+').firstMatch(value.toString());
    return match != null ? int.parse(match.group(0)!) : 0;
  }
}
