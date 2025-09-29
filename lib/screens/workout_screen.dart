import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/services/exercise_service.dart';
import 'package:perfit/core/services/firebase_firestore_service.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/exercise_metrics_model.dart';
import 'package:perfit/screens/assessment/gender_screen.dart';
import 'package:perfit/screens/perform_exercise_screen.dart';
import 'package:perfit/widgets/welcome_guest.dart';

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

    currentDay = fitnessPlan.currentDay;
    selectedDay = fitnessPlan.currentDay;
    planDuration = fitnessPlan.planDuration * 7;

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

  Future<void> completeWorkoutDay(int day, {required String status}) async {
    if (activeFitnessPlanId == null) return;

    final planRef = FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('fitnessPlan')
        .doc(activeFitnessPlanId);

    final workoutDayRef = planRef.collection('workouts').doc("day_$day");

    await workoutDayRef.set({
      'status': status,
      'dateCompleted': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // update local workouts list
    setState(() {
      final index = workouts.indexWhere((w) => w['day'] == day);
      if (index != -1) {
        workouts[index]['status'] = status;
        workouts[index]['dateCompleted'] = Timestamp.now();
      }
    });
  }

  Widget createWorkoutRoutineBtn() {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          NavigationUtils.push(context, GenderScreen());
        },
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
          icon: Icon(Icons.arrow_left),
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
                            day == selectedDay ? Colors.blue : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Day $day",
                        style: TextStyle(
                          color:
                              day == selectedDay ? Colors.white : Colors.black,
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
          icon: Icon(Icons.arrow_right),
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
          if (map.containsKey('reps')) {
            return RepsExercise(
              name: map['name'],
              sets: map['sets'] ?? 0,
              rest: map['rest'] ?? 0,
              reps: map['reps'] ?? 0,
            );
          } else {
            return TimeExercise(
              name: map['name'],
              sets: map['sets'] ?? 0,
              rest: map['rest'] ?? 0,
              duration: map['duration'] ?? 0,
            );
          }
        }).toList();

    final finishedCount =
        exercises.where((ex) {
          final key = "$day-${ex.name}";
          return exerciseStatus[key] == "completed";
        }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Day $day - ${dayWorkout['split'] ?? 'Workout'} Day",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "$finishedCount / ${exercises.length} exercises finished",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: exercises.length,
            itemBuilder: (_, index) {
              final ex = exercises[index];
              final key = "$day-${ex.name}";
              final status = exerciseStatus[key] ?? "pending";

              return Card(
                child: ListTile(
                  title: Text(
                    ex.name,
                    style: TextStyle(
                      color:
                          status == "pending" && selectedDay == currentDay
                              ? AppColors.white
                              : Colors.grey,
                    ),
                  ),
                  subtitle: Text(
                    ex is RepsExercise
                        ? "Sets: ${ex.sets} x Reps: ${ex.reps}"
                        : "Sets: ${ex.sets} x Duration: ${(ex as TimeExercise).duration}",
                  ),
                  enabled: status == "pending" && selectedDay == currentDay,
                  onTap:
                      status == "pending" && selectedDay == currentDay
                          ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => PerformExerciseScreen(
                                      name: ex.name,
                                      sets: ex.sets,
                                      reps: ex is RepsExercise ? ex.reps : null,
                                      duration:
                                          ex is TimeExercise
                                              ? ex.duration
                                              : null,
                                      planId: activeFitnessPlanId!,
                                      day: selectedDay.toString(),
                                      exercises: exercises,
                                    ),
                              ),
                            ).then((result) async {
                              if (result == "completed") {
                                setState(() {
                                  exerciseStatus[key] = result;
                                });

                                // ✅ check if all exercises in this day are completed
                                final allCompleted = exercises.every((e) {
                                  final k = "$day-${e.name}";
                                  return exerciseStatus[k] == 'completed';
                                });

                                if (allCompleted) {
                                  // 🎯 mark day completed & increment currentDay
                                  await completeWorkoutDay(
                                    day,
                                    status: 'completed',
                                  );
                                  setState(() {
                                    currentDay = currentDay + 1;
                                  });
                                }
                              }
                            });
                          }
                          : null,
                ),
              );
            },
          ),
        ),
      ],
    );
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
      appBar: AppBar(title: Text("Workout Plan")),
      body: Column(
        children: [
          Text("Week ${currentWeekIndex + 1}"),
          weekDaySelector(),
          Expanded(child: workoutForDay(selectedDay)),
        ],
      ),
    );
  }
}
