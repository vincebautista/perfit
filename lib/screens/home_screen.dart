import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/services/firebase_firestore_service.dart';
import 'package:perfit/core/services/setting_service.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/data_sources/exercise_list.dart';
import 'package:perfit/data/models/exercise_model.dart';
import 'package:perfit/data/models/user_model.dart';
import 'package:perfit/screens/all_exercises_screen.dart';
import 'package:perfit/screens/exercise_screen.dart';
import 'package:perfit/screens/main_navigation.dart';
import 'package:perfit/widgets/last_7_days_chart.dart';
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

  final FirebaseFirestoreService _service = FirebaseFirestoreService();
  UserModel? userModel;

  final user = FirebaseAuth.instance.currentUser;

  final SettingService _settingService = SettingService();
  bool isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _exercises = exercises;
    _filteredExercises = _exercises;
    fetchViewedExercises();
    _loadUser();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final mode = await _settingService.loadThemeMode();
    if (!mounted) return;
    setState(() {
      isDarkMode = mode == ThemeMode.dark;
    });
  }

  Future<void> _loadUser() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    final doc = await _service.getUserData(firebaseUser.uid);
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    if (!mounted) return;
    setState(() {
      userModel = UserModel(
        uid: firebaseUser.uid,
        fullname: data['fullname'] ?? '',
        assessmentDone: data['assessmentDone'] ?? false,
        activeFitnessPlan: data['activeFitnessPlan'],
        pendingWorkout: data['pendingWorkout'],
      );
    });
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

    if (!mounted) return;
    setState(() {
      viewedExercises = snapshot.docs.map((doc) => doc.id).toList();
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

    if (!mounted) return;
    setState(() {
      viewedExercises.add(exerciseId);
    });
  }

  void filterExercises(String filter) {
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _fetchAllData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Full-screen loading indicator
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData) {
              return const Center(child: Text("No data available."));
            }

            final data = snapshot.data!;
            final last7Workouts =
                data['last7Workouts'] as List<Map<String, dynamic>>;
            final todayWorkout = data['todayWorkout'];
            final currentDay = data['currentDay'] ?? 1;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.padding16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome section
                  Text(
                    user == null
                        ? "Welcome to Perfit!"
                        : "Welcome back, ${userModel!.fullname.split(' ').first}!",
                    style: TextStyles.heading.copyWith(fontSize: 20),
                  ),
                  Text(
                    "Perfect your form and build strength the right way!",
                    style: TextStyles.caption.copyWith(
                      color: isDarkMode ? AppColors.lightgrey : AppColors.black,
                    ),
                  ),
                  Gap(AppSizes.gap10),

                  // Weekly Summary
                  if (user != null &&
                      last7Workouts != null &&
                      last7Workouts.isNotEmpty)
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          12,
                        ), // rounded corners
                        side: BorderSide(
                          color:
                              isDarkMode
                                  ? AppColors.white
                                  : Colors.transparent, // border color
                          width: 0.5, // border width
                        ),
                      ),
                      color:
                          isDarkMode ? AppColors.surface : AppColors.lightgrey,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.padding16),
                        child: Column(
                          children: [
                            Text(
                              "Weekly Summary",
                              style: TextStyles.subtitle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Gap(AppSizes.gap10),
                            Last7DaysStackedChart(last7Workouts: last7Workouts),
                            Gap(AppSizes.gap10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildLegend(Colors.green, "Completed"),
                                _buildLegend(Colors.red, "Skipped"),
                                _buildLegend(Colors.grey, "Pending"),
                                _buildLegend(AppColors.primary, "Rest Day"),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  Gap(AppSizes.gap10),

                  // Today's Workout
                  if (todayWorkout != null)
                    Column(
                      children: [
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          color: AppColors.primary,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.white,
                              child: Icon(
                                Icons.calendar_today_outlined,
                                color: AppColors.primary,
                              ),
                            ),
                            title: Text(
                              "Today's Workout",
                              style: TextStyles.caption.copyWith(
                                color: AppColors.white,
                              ),
                            ),
                            subtitle: Text(
                              "Day $currentDay - ${todayWorkout['split'] ?? 'Workout'}",
                              style: TextStyles.body.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => MainNavigation(initialIndex: 2),
                                  ),
                                );
                              },
                              child: Text(
                                "View All",
                                style: TextStyles.label.copyWith(
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Gap(AppSizes.gap10),
                      ],
                    ),

                  // Filters
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
                            padding: const EdgeInsets.only(
                              right: AppSizes.gap10,
                            ),
                            child: ElevatedButton(
                              onPressed: () => filterExercises(filter),
                              style: ElevatedButton.styleFrom(
                                fixedSize: Size(130, AppSizes.buttonSmall),
                                backgroundColor:
                                    _selectedFilter == filter
                                        ? Theme.of(context).primaryColor
                                        : isDarkMode
                                        ? AppColors.grey
                                        : AppColors.lightgrey,
                              ),
                              child: Text(
                                filter,
                                style: TextStyles.buttonSmall,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Gap(AppSizes.gap10),

                  // Exercises header
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
                          style: TextStyles.body.copyWith(
                            color:
                                isDarkMode ? AppColors.white : AppColors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Gap(AppSizes.gap10),

                  // Exercises Grid
                  _filteredExercises.isNotEmpty
                      ? GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
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
                                  color: AppColors.grey.withValues(
                                    alpha: isDarkMode ? 0.5 : 0.8,
                                  ),
                                  alignment: Alignment.center,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSizes.padding16,
                                    ),
                                    child: Text(
                                      exercise.name,
                                      style:
                                          isDarkMode
                                              ? TextStyles.label
                                              : TextStyles.label.copyWith(
                                                color: AppColors.white,
                                              ),
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style:
              isDarkMode
                  ? TextStyles.caption
                  : TextStyles.caption.copyWith(color: AppColors.black),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _fetchAllData() async {
    final last7Workouts = await fetchLast7DaysWorkouts();
    final todayWorkoutData = await fetchTodayWorkoutForUI();
    return {
      'last7Workouts': last7Workouts,
      'todayWorkout': todayWorkoutData?['todayWorkout'],
      'currentDay': todayWorkoutData?['currentDay'],
    };
  }

  // --- Keep your existing fetchTodayWorkoutForUI & fetchLast7DaysWorkouts methods below ---
  Future<Map<String, dynamic>?> fetchTodayWorkoutForUI() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final userDoc =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .get();
    if (!userDoc.exists) return null;

    final userData = userDoc.data() ?? {};
    if (!userData.containsKey('activeFitnessPlan')) return null;

    final activeFitnessPlanId = userData['activeFitnessPlan'];
    final planRef = FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("fitnessPlan")
        .doc(activeFitnessPlanId);

    final planDoc = await planRef.get();
    if (!planDoc.exists) return null;

    final planData = planDoc.data() ?? {};
    int currentDay = planData['currentDay'] ?? 1;

    final workoutDoc =
        await planRef.collection("workouts").doc(currentDay.toString()).get();
    final todayWorkout = workoutDoc.exists ? workoutDoc.data() : null;

    return {
      'activeFitnessPlanId': activeFitnessPlanId,
      'todayWorkout': todayWorkout,
      'currentDay': currentDay,
    };
  }

  Future<List<Map<String, dynamic>>?> fetchLast7DaysWorkouts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final userDoc =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .get();
    if (!userDoc.exists) return [];

    final userData = userDoc.data() ?? {};
    if (!userData.containsKey('activeFitnessPlan')) return [];

    final activeFitnessPlanId = userData['activeFitnessPlan'];
    final planRef = FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("fitnessPlan")
        .doc(activeFitnessPlanId);

    final planDoc = await planRef.get();
    if (!planDoc.exists) return [];

    final planData = planDoc.data() ?? {};
    int currentDay = planData['currentDay'] ?? 1;

    List<Map<String, dynamic>> last7Workouts = [];
    int startDay = (currentDay - 6) > 0 ? currentDay - 6 : 1;

    for (int day = startDay; day <= currentDay; day++) {
      final workoutDoc =
          await planRef.collection("workouts").doc(day.toString()).get();
      if (!workoutDoc.exists) continue;

      final workoutData = workoutDoc.data() ?? {};
      final exercises =
          workoutData['exercises'] != null
              ? List<Map<String, dynamic>>.from(
                (workoutData['exercises'] as List).map(
                  (e) => Map<String, dynamic>.from(e as Map),
                ),
              )
              : <Map<String, dynamic>>[];

      int completed = exercises.where((e) => e['status'] == 'completed').length;
      int skipped = exercises.where((e) => e['status'] == 'skipped').length;
      int fallback = exercises.length - completed - skipped;

      last7Workouts.add({
        'day': day,
        'completed': completed,
        'skipped': skipped,
        'fallback': fallback,
        'type': workoutData['type'] ?? 'Workout',
      });
    }

    return last7Workouts;
  }
}
