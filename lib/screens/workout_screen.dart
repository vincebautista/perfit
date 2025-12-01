import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/services/exercise_service.dart';
import 'package:perfit/core/services/firebase_firestore_service.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/exercise_metrics_model.dart';
import 'package:perfit/screens/assessment/gender_screen.dart';
import 'package:perfit/screens/perform_exercise_screen.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:perfit/widgets/welcome_guest.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  int currentWeekIndex = 0;
  late FirebaseFirestoreService firestoreService;
  late ExerciseService exerciseService;
  User? user;

  String? activeFitnessPlanId;
  int currentDay = 1;
  int selectedDay = 1;
  int planDuration = 0;
  List<Map<String, dynamic>> workouts = [];

  bool isLoading = true;
  bool hasPlan = false;

  Map<String, String> exerciseStatus = {};
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    firestoreService = FirebaseFirestoreService();
    exerciseService = ExerciseService();
    user = FirebaseAuth.instance.currentUser;

    loadWorkoutPlan();
  }

  Future<void> loadWorkoutPlan() async {
    if (user == null) {
      setState(() {
        isLoading = false;
        hasPlan = false;
      });
      return;
    }

    activeFitnessPlanId = await firestoreService.getActiveFitnessPlan(
      user!.uid,
    );

    if (activeFitnessPlanId == null) {
      setState(() {
        isLoading = false;
        hasPlan = false;
      });
      return;
    }

    final fitnessPlan = await firestoreService.getFitnessPlan(
      user!.uid,
      activeFitnessPlanId!,
    );

    if (fitnessPlan == null) {
      setState(() {
        isLoading = false;
        hasPlan = false;
      });
      return;
    }

    if (_isFirstLoad) {
      currentDay = fitnessPlan.currentDay;
      selectedDay = fitnessPlan.currentDay;
      planDuration = fitnessPlan.planDuration * 7;

      currentWeekIndex = ((currentDay - 1) ~/ 7);

      _isFirstLoad = false;
    }

    final workoutDocs = await firestoreService.getWorkouts(
      user!.uid,
      activeFitnessPlanId!,
    );
    workouts = workoutDocs.map((doc) => doc.data()).toList();

    exerciseStatus = await firestoreService.getExerciseStatuses(
      user!.uid,
      activeFitnessPlanId!,
    );

    setState(() {
      hasPlan = true;
      isLoading = false;
    });
  }

  Widget createWorkoutRoutineBtn() {
    return Center(
      child: ElevatedButton(
        onPressed: () => NavigationUtils.push(context, GenderScreen()),
        child: Text("Create workout plan"),
      ),
    );
  }

  Widget weekDaySelector() {
    int startDay = currentWeekIndex * 7 + 1;
    int endDay = (startDay + 6).clamp(1, planDuration);

    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_left, color: AppColors.primary),
          onPressed:
              currentWeekIndex > 0
                  ? () => setState(() => currentWeekIndex--)
                  : null,
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int day = startDay; day <= endDay; day++)
                  GestureDetector(
                    onTap: () => setState(() => selectedDay = day),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color:
                            day == selectedDay
                                ? AppColors.primary
                                : AppColors.grey,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Day $day",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.arrow_right, color: AppColors.primary),
          onPressed:
              endDay < planDuration
                  ? () => setState(() => currentWeekIndex++)
                  : null,
        ),
      ],
    );
  }

  Widget workoutForDay(int day) {
    final dayWorkout = workouts.firstWhere(
      (w) => w['day'] == day,
      orElse: () => {},
    );

    if (dayWorkout.isEmpty) {
      return Center(child: Text("No workout found for Day $day."));
    }

    if (dayWorkout['type'] == "Rest") {
      return Center(
        child: Text(
          "Day $day is a Rest Day.\nCome back tomorrow!",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      );
    }

    final List<dynamic> exercisesRaw = dayWorkout['exercises'] ?? [];
    final List<ExerciseMetricsModel> exercises =
        exercisesRaw.map((e) {
          final map = Map<String, dynamic>.from(e);
          return ExerciseMetricsModel.parseExercise(map);
        }).toList();

    final finishedCount =
        exercises.where((ex) {
          final key = "$day-${ex.name}";
          return exerciseStatus[key] == "completed" ||
              exerciseStatus[key] == "skipped";
        }).length;

    return Padding(
      padding: const EdgeInsets.all(AppSizes.padding20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${dayWorkout['split'] ?? 'Workout'} Day",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                "Progress: $finishedCount / ${exercises.length} finished",
                textAlign: TextAlign.center,
                style: TextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: exercises.length,
              itemBuilder: (_, index) {
                final ex = exercises[index];
                final key = "$day-${ex.name}";
                final status = exerciseStatus[key] ?? "pending";

                bool isPastDay = day < currentDay;
                bool isFutureDay = day > currentDay;
                bool isToday = day == currentDay;

                return Card(
                  color:
                      status == "pending" ? AppColors.grey : AppColors.surface,
                  shape: RoundedRectangleBorder(
                    // side: BorderSide(
                    //   color:
                    //       status == "completed"
                    //           ? AppColors.green
                    //           : status == "skipped"
                    //           ? AppColors.red
                    //           : Colors.transparent,
                    //   width: 2,
                    // ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    title: Text(
                      ex.name,
                      style: TextStyle(
                        color:
                            status == "pending"
                                ? AppColors.white
                                : status == "completed"
                                ? AppColors.green
                                : AppColors.red,
                      ),
                    ),
                    subtitle: Text(
                      ex is RepsExercise
                          ? "Sets: ${ex.sets} x Reps: ${ex.reps}"
                          : "Sets: ${ex.sets} x Duration: ${(ex as TimeExercise).duration}",
                    ),
                    // trailing:
                    //     (() {
                    //       final rawExercise = exercisesRaw.firstWhere(
                    //         (e) => e['name'] == ex.name,
                    //         orElse: () => null,
                    //       );

                    //       if (rawExercise != null &&
                    //           rawExercise.containsKey('elapsedTime') &&
                    //           (rawExercise['elapsedTime'] ?? 0) > 0) {
                    //         final elapsed = rawExercise['elapsedTime'];
                    //         return Text(
                    //           "${elapsed} s",
                    //           style: const TextStyle(
                    //             fontWeight: FontWeight.bold,
                    //             color: Colors.grey,
                    //           ),
                    //         );
                    //       }
                    //       return null;
                    //     })(),
                    enabled: !isPastDay,
                    onTap: () {
                      if (isPastDay) return;
                      if (isFutureDay) {
                        showDialog(
                          context: context,
                          builder:
                              (_) => AlertDialog(
                                title: const Text("Not yet available"),
                                content: const Text("Come back tomorrow."),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("OK"),
                                  ),
                                ],
                              ),
                        );
                      } else if (isToday && status == "pending") {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => PerformExerciseScreen(
                                  name: ex.name,
                                  sets: ex.sets,
                                  reps: ex is RepsExercise ? ex.reps : null,
                                  duration:
                                      ex is TimeExercise ? ex.duration : null,
                                  planId: activeFitnessPlanId!,
                                  day: selectedDay.toString(),
                                  exercises: exercises,
                                ),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> skipDay(int day) async {
    final dayWorkout = workouts.firstWhere(
      (w) => w['day'] == day,
      orElse: () => {},
    );
    if (dayWorkout.isEmpty) return;

    final List<dynamic> exercisesRaw = dayWorkout['exercises'] ?? [];

    // Mark all exercises skipped locally + Firebase
    for (var ex in exercisesRaw) {
      final key = "$day-${ex['name']}";
      exerciseStatus[key] = "skipped";
      await firestoreService.skipAllExercises(
        activeFitnessPlanId!,
        day,
        exercisesRaw,
      );
    }

    // Use your new method to mark the day complete
    await firestoreService.updateWorkoutDayCompletion(
      activeFitnessPlanId!,
      day,
    );

    // Increment currentDay in Firebase
    await firestoreService.incrementCurrentDay(user!.uid, activeFitnessPlanId!);

    // Move to next day locally
    if (day < planDuration) {
      setState(() {
        selectedDay = day + 1;
        currentDay = day + 1;
        currentWeekIndex = ((selectedDay - 1) ~/ 7);
      });
    }
  }

  bool isRestDay(int day) {
    final dayWorkout = workouts.firstWhere(
      (w) => w['day'] == day,
      orElse: () => {},
    );
    if (dayWorkout.isEmpty) return true;
    return dayWorkout['type'] == "Rest";
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("Workout Plan")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!hasPlan) {
      return Scaffold(
        appBar: AppBar(title: Text("Workout Plan")),
        body: user == null ? WelcomeGuest() : createWorkoutRoutineBtn(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Workout Plan"),
        actions: [
          if (hasPlan && selectedDay == currentDay && !isRestDay(selectedDay))
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder:
                      (_) => AlertDialog(
                        title: const Text(
                          "Skip Day?",
                          style: TextStyle(color: AppColors.primary),
                        ),
                        content: const Text(
                          "Are you sure you want to skip today's workout?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context), // cancel
                            child: const Text(
                              "Cancel",
                              style: TextStyle(color: AppColors.white),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSizes.padding16,
                              vertical: AppSizes.padding16 - 8,
                            ),
                            child: GestureDetector(
                              onTap: () async {
                                Navigator.pop(context);
                                // 🔹 Show QuickAlert loading while skipping
                                QuickAlert.show(
                                  context: context,
                                  type: QuickAlertType.loading,
                                  text: "Skipping today's workout...",
                                  barrierDismissible: false,
                                );

                                try {
                                  await skipDay(selectedDay);

                                  // 🔹 Dismiss loading after done
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop();

                                  // 🔹 Optional: show a success message
                                  QuickAlert.show(
                                    context: context,
                                    type: QuickAlertType.success,
                                    text: "Day skipped successfully!",
                                    autoCloseDuration: const Duration(
                                      seconds: 2,
                                    ),
                                  );
                                } catch (e) {
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop();
                                  QuickAlert.show(
                                    context: context,
                                    type: QuickAlertType.error,
                                    text: "Failed to skip day: $e",
                                    autoCloseDuration: const Duration(
                                      seconds: 3,
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                "Skip",
                                style: TextStyle(color: AppColors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                );
              },
              child: Text(
                "Skip Day",
                style: TextStyle(color: AppColors.primary),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Text("Week ${currentWeekIndex + 1}", style: TextStyles.body),
          weekDaySelector(),
          Expanded(child: workoutForDay(selectedDay)),
        ],
      ),
    );
  }
}
