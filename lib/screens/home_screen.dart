import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/data_sources/exercise_list.dart';
import 'package:perfit/data/models/exercise_model.dart';
import 'package:perfit/screens/all_exercises_screen.dart';
import 'package:perfit/screens/exercise_screen.dart';
import 'package:perfit/widgets/text_styles.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<ExerciseModel> _exercises;
  late List<ExerciseModel> _filteredExercises;
  List<String> viewedExercises = [];
  String _selectedFilter = "All";

  int currentDay = 1;
  String? activeFitnessPlanId;
  Map<String, dynamic>? todayWorkout;
  bool loadingWorkout = true;

  @override
  void initState() {
    super.initState();
    _exercises = exercises;
    _filteredExercises = _exercises;
    fetchViewedExercises();
    fetchTodayWorkout();
  }

  Future<void> fetchViewedExercises() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection("viewedExercises")
            .get();

    setState(() {
      viewedExercises = snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  Future<void> fetchTodayWorkout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection("users").doc(user.uid);
    final userDoc = await userRef.get();
    if (!userDoc.exists) {
      setState(() => loadingWorkout = false);
      return;
    }

    final userData = userDoc.data() ?? {};
    if (!userData.containsKey('activeFitnessPlan')) {
      setState(() => loadingWorkout = false);
      return;
    }

    activeFitnessPlanId = userData['activeFitnessPlan'];
    final planRef = userRef.collection("fitnessPlan").doc(activeFitnessPlanId);
    final planDoc = await planRef.get();

    if (!planDoc.exists) {
      setState(() => loadingWorkout = false);
      return;
    }

    final planData = planDoc.data() ?? {};
    int day = planData['currentDay'] ?? 1;

    DateTime today = DateTime.now();
    DateTime? lastOpened;
    if (planData['lastOpenedDate'] != null) {
      lastOpened = DateTime.tryParse(planData['lastOpenedDate']);
    }

    final workoutDoc =
        await planRef.collection("workouts").doc(day.toString()).get();

    if (!workoutDoc.exists) {
      setState(() => loadingWorkout = false);
      return;
    }

    final workoutData = workoutDoc.data() ?? {};
    final type = workoutData['type'] ?? "Workout";

    if (type == "Rest") {
      if (lastOpened != null &&
          (lastOpened.year != today.year ||
              lastOpened.month != today.month ||
              lastOpened.day != today.day)) {
        day++;
        await planRef.update({
          'currentDay': day,
          'lastOpenedDate': today.toIso8601String(),
        });

        final nextWorkoutDoc =
            await planRef.collection("workouts").doc(day.toString()).get();
        setState(() {
          currentDay = day;
          todayWorkout = nextWorkoutDoc.data();
          loadingWorkout = false;
        });
        return;
      }

      await planRef.update({'lastOpenedDate': today.toIso8601String()});
      setState(() {
        currentDay = day;
        todayWorkout = workoutData;
        loadingWorkout = false;
      });
      return;
    }

    final exercises = (workoutData['exercises'] as List<dynamic>? ?? []);
    final allCompleted =
        exercises.isNotEmpty &&
        exercises.every((ex) => ex['status'] == 'completed');

    if (allCompleted && workoutData['isCompleted'] != true) {
      await workoutDoc.reference.update({'isCompleted': true});

      day++;
      await planRef.update({
        'currentDay': day,
        'lastOpenedDate': today.toIso8601String(),
      });

      final nextWorkoutDoc =
          await planRef.collection("workouts").doc(day.toString()).get();
      setState(() {
        currentDay = day;
        todayWorkout = nextWorkoutDoc.data();
        loadingWorkout = false;
      });
      return;
    }

    await planRef.update({'lastOpenedDate': today.toIso8601String()});
    setState(() {
      currentDay = day;
      todayWorkout = workoutData;
      loadingWorkout = false;
    });
  }

  void saveViewedExercise(String exerciseId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("viewedExercises")
        .doc(exerciseId)
        .set({"viewedAt": Timestamp.now()});

    setState(() {
      viewedExercises.add(exerciseId);
    });
  }

  void filterExercises(String filter) {
    setState(() {
      _selectedFilter = filter;
      if (filter == "All") {
        _filteredExercises = _exercises;
      } else {
        _filteredExercises =
            _exercises
                .where((exercise) => exercise.difficulty == filter)
                .toList();
      }
    });
  }

  Widget todayWorkoutSummary() {
    if (loadingWorkout) {
      return const Center(child: CircularProgressIndicator());
    }

    if (todayWorkout == null) {
      return Text("No active fitness plan found.", style: TextStyles.body);
    }

    if (todayWorkout!['type'] == "Rest") {
      return Text("Today is a Rest Day 🛌", style: TextStyles.body);
    }

    final exercises = todayWorkout!['exercises'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Today's workout", style: TextStyles.subtitle),
        Text(
          "Day $currentDay - ${todayWorkout!['split'] ?? 'Workout'}",
          style: TextStyles.body,
        ),
        Gap(8),
        ...exercises.map((ex) {
          final name = ex['name'];
          final sets = ex['sets'] ?? 0;
          final reps = ex['reps'];
          final duration = ex['duration'];

          return Text(
            reps != null
                ? "$name - $sets x $reps reps ${ex['status'] == 'completed' ? '✅' : ''}"
                : "$name - $sets x ${duration ?? 0}s ${ex['status'] == 'completed' ? '✅' : ''}",
            style: TextStyles.label,
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.padding16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Welcome to Perfit!", style: TextStyles.heading),
                      Text(
                        "Ready to perfect your form and build strength the right way?",
                        style: TextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Gap(AppSizes.gap20),
            todayWorkoutSummary(),
            Gap(AppSizes.gap20),
            // 🔹 Filter buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var filter in [
                    "All",
                    "Beginner",
                    "Intermediate",
                    "Advance",
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSizes.gap10),
                      child: ElevatedButton(
                        onPressed: () => filterExercises(filter),
                        style: ElevatedButton.styleFrom(
                          fixedSize: Size(130, AppSizes.buttonSmall),
                          backgroundColor:
                              _selectedFilter == filter
                                  ? Theme.of(context).primaryColor
                                  : AppColors.grey,
                        ),
                        child: Text(filter, style: TextStyles.buttonSmall),
                      ),
                    ),
                ],
              ),
            ),
            Gap(AppSizes.gap15),

            // 🔹 Exercises Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Exercises", style: TextStyles.body),
                TextButton(
                  onPressed:
                      () => NavigationUtils.push(
                        context,
                        const AllExercisesScreen(),
                      ),
                  child: Text(
                    "View All",
                    style: TextStyles.body.copyWith(color: AppColors.white),
                  ),
                ),
              ],
            ),
            Gap(AppSizes.gap10),
            Expanded(
              child:
                  _filteredExercises.isNotEmpty
                      ? GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 200,
                              mainAxisSpacing: AppSizes.gap10,
                              crossAxisSpacing: AppSizes.gap10,
                            ),
                        itemCount: _filteredExercises.length,
                        itemBuilder: (context, index) {
                          final exercise = _filteredExercises[index];

                          return GestureDetector(
                            onTap: () {
                              NavigationUtils.push(
                                context,
                                ExerciseScreen(id: exercise.id),
                              );
                              saveViewedExercise(exercise.id);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppSizes.roundedRadius,
                              ),
                              child: GridTile(
                                footer: Container(
                                  padding: const EdgeInsets.all(5),
                                  color: AppColors.grey.withValues(alpha: 0.5),
                                  alignment: Alignment.center,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSizes.padding16,
                                    ),
                                    child: Text(
                                      exercise.name,
                                      style: TextStyles.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                header:
                                    viewedExercises.contains(exercise.id)
                                        ? Align(
                                          alignment: Alignment.topRight,
                                          child: Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal:
                                                        AppSizes.padding20 / 2,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppSizes.circleRadius,
                                                    ),
                                              ),
                                              child: const Text(
                                                "viewed",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                        : const SizedBox.shrink(),
                                child: Image.asset(
                                  exercise.image,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    debugPrint(
                                      "ERROR loading asset: ${exercise.image}",
                                    );
                                    return const Center(
                                      child: Text("Image unavailable"),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      )
                      : const Center(child: Text("No exercises found.")),
            ),
          ],
        ),
      ),
    );
  }
}
