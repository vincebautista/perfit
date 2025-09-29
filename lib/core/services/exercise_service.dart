import 'dart:convert';

import 'package:perfit/core/services/gemini_api_service.dart';
import 'package:perfit/data/data_sources/exercise_list.dart';
import 'package:perfit/data/models/exercise_metrics_model.dart';
import 'package:perfit/data/models/fitness_plan_model.dart';

enum DayType { workout, rest }

class ExerciseService {
  final geminiService = GeminiApiService();

  int calculateWeeks({
    required double weight,
    required double targetWeight,
    required String goal,
  }) {
    int weeks = 0;

    if (goal == "Lose fat") {
      double weightDifference = weight - targetWeight;

      double calorieDeficit =
          weightDifference * 7700; //7700 is approximate kcal in 1kg

      int days = (calorieDeficit / 500).ceil(); //500 calorie deficit per day

      weeks = (days / 7).ceil();
    } else if (goal == "Build muscle") {
      double weightDifference = targetWeight - weight;

      weeks = (weightDifference / 0.3).ceil(); //0.3kg kg gain per week
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
    if (activityLevel == "Sedentary") {
      return bmr * 1.2;
    } else if (activityLevel == "Lightly active") {
      return bmr * 1.375;
    } else if (activityLevel == "Moderately active") {
      return bmr * 1.55;
    } else {
      return bmr * 1.725;
    }
  }

  String determineFinalActivityLevel({
    required String dailyActivityLevel,
    required int workoutDays,
  }) {
    if (dailyActivityLevel == "Sedentary") {
      if (workoutDays >= 5) {
        return "Very active";
      } else {
        return "Moderately active";
      }
    } else if (dailyActivityLevel == "Lightly active") {
      if (workoutDays >= 5) {
        return "Very active";
      } else {
        return "Moderately active";
      }
    } else {
      return "Very active";
    }
  }

  List<DayType> getWeeklySchedule(int workoutCommitment) {
    switch (workoutCommitment) {
      case 4:
        return [
          DayType.workout,
          DayType.workout,
          DayType.rest,
          DayType.workout,
          DayType.workout,
          DayType.rest,
          DayType.rest,
        ];
      case 5:
        return [
          DayType.workout,
          DayType.workout,
          DayType.workout,
          DayType.rest,
          DayType.workout,
          DayType.workout,
          DayType.rest,
        ];
      case 6:
        return [
          DayType.workout,
          DayType.workout,
          DayType.workout,
          DayType.workout,
          DayType.workout,
          DayType.workout,
          DayType.rest,
        ];
      default:
        return [
          DayType.workout,
          DayType.workout,
          DayType.rest,
          DayType.workout,
          DayType.workout,
          DayType.rest,
          DayType.rest,
        ];
    }
  }

  List<String> getWeeklySplits(int workoutCommitment) {
    if (workoutCommitment == 4) {
      return [
        "Upper Body",
        "Lower Body",
        "Rest",
        "Push",
        "Pull",
        "Rest",
        "Rest",
      ];
    } else if (workoutCommitment == 5) {
      return [
        "Push",
        "Pull",
        "Legs",
        "Rest",
        "Upper Body",
        "Lower Body",
        "Rest",
      ];
    } else if (workoutCommitment == 6) {
      return [
        "Push",
        "Pull",
        "Legs",
        "Upper Body",
        "Lower Body",
        "Full Body",
        "Rest",
      ];
    } else {
      return [
        "Full Body",
        "Full Body",
        "Rest",
        "Full Body",
        "Full Body",
        "Rest",
        "Rest",
      ];
    }
  }

  Future<String> generateTarget(FitnessPlanModel fitnessPlan) async {
    final userAnswers = fitnessPlan.initialAssessment;
    String availableExercises = formatExercisesForPrompt(
      userAnswers["workoutLocation"],
    );

    final weeklySchedule = getWeeklySchedule(
      int.parse(userAnswers["workoutCommitment"]),
    );

    final weeklySplits = getWeeklySplits(
      int.parse(userAnswers["workoutCommitment"]),
    );

    final weeklyScheduleString =
        weeklySchedule
            .map((d) => d == DayType.workout ? "Workout" : "Rest")
            .toList()
            .toString();

    final weeklySplitsString = weeklySplits.toString();

    int totalWeeks = fitnessPlan.planDuration;
    int batchSize = 4;
    List<Map<String, dynamic>> mergedDays = [];

    int dayCounter = 1;

    for (int startWeek = 1; startWeek <= totalWeeks; startWeek += batchSize) {
      int endWeek =
          (startWeek + batchSize - 1 > totalWeeks)
              ? totalWeeks
              : startWeek + batchSize - 1;

      // Calculate the start and end day for this batch
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
    - Workout Commitment: ${userAnswers["workoutCommitment"]} days a week
    - Experience: ${userAnswers["previousExperience"]}
    - Workout Location: ${userAnswers["workoutLocation"]}
    - Activity Level: ${userAnswers["activityLevel"]}

    Workout Schedule (Weekly): $weeklyScheduleString
    Split Schedule (Weekly): $weeklySplitsString

    Workout Exercises to use:
    $availableExercises

    Rules:
    - ALWAYS AND ONLY use exercises from the "Workout Exercises to use" list provided below. Do NOT invent or suggest any other exercises.
    - Just use the exact exercise name as provided in the list (e.g., "Wall Sit", not "Wall Sit (Legs)").
    - Follow the split schedule for each workout day.
    - Include both workout and rest days in the JSON.
    - Use 5–8 exercises per workout day.
    - Always include exact sets, reps (for rep-based), or duration (for time-based).
    - Day numbers must continue across all weeks (e.g., 1–28, 29–56, etc.).
    
    - No explanations, markdown, or text outside the JSON.

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
          } else {
            print("Unexpected JSON format: $cleaned");
          }
        } catch (e) {
          print("JSON parsing error: $e");
          print("Raw response: $rawResponse");
        }
      }

      dayCounter = endDay + 1;
    }

    return const JsonEncoder.withIndent("  ").convert(mergedDays);
  }

  String formatList(List<dynamic>? list) {
    if (list == null || list.isEmpty) {
      return "None";
    }

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
        exercises.where((e) {
          return e.location == workoutLocation;
        }).toList();

    return locationFiltered
        .map((e) {
          return "- ${e.name}";
        })
        .join("\n");
  }
}
