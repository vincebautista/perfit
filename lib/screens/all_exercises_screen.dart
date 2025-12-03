import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/data_sources/exercise_list.dart';
import 'package:perfit/data/models/exercise_model.dart';
import 'package:perfit/screens/exercise_screen.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class AllExercisesScreen extends StatefulWidget {
  final bool fromWorkoutScreen;
  final String? planId;
  final int? selectedDay;

  const AllExercisesScreen({
    super.key,
    this.fromWorkoutScreen = false,
    this.planId,
    this.selectedDay,
  });

  @override
  State<AllExercisesScreen> createState() => _AllExercisesScreenState();
}

class _AllExercisesScreenState extends State<AllExercisesScreen> {
  late List<ExerciseModel> _exercises;
  late List<ExerciseModel> _filteredExercises;
  List<String> viewedExercises = [];

  String _selectedFilter = "All";

  @override
  void initState() {
    super.initState();

    _exercises = exercises;
    _filteredExercises = _exercises;
    fetchViewedExercises();
  }

  Future<void> fetchViewedExercises() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

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

    if (user == null) {
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Exercise List")),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.padding16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: () => filterExercises("All"),
                    style: ElevatedButton.styleFrom(
                      fixedSize: Size(130, AppSizes.buttonSmall),
                      backgroundColor:
                          _selectedFilter == "All"
                              ? Theme.of(context).primaryColor
                              : AppColors.grey,
                    ),
                    child: Text("All", style: TextStyles.buttonSmall),
                  ),
                  Gap(AppSizes.gap10),
                  ElevatedButton(
                    onPressed: () => filterExercises("Beginner"),
                    style: ElevatedButton.styleFrom(
                      fixedSize: Size(130, AppSizes.buttonSmall),
                      backgroundColor:
                          _selectedFilter == "Beginner"
                              ? Theme.of(context).primaryColor
                              : AppColors.grey,
                    ),
                    child: Text("Beginner", style: TextStyles.buttonSmall),
                  ),
                  Gap(AppSizes.gap10),
                  ElevatedButton(
                    onPressed: () => filterExercises("Intermediate"),
                    style: ElevatedButton.styleFrom(
                      fixedSize: Size(130, AppSizes.buttonSmall),
                      backgroundColor:
                          _selectedFilter == "Intermediate"
                              ? Theme.of(context).primaryColor
                              : AppColors.grey,
                    ),
                    child: Text("Intermediate", style: TextStyles.buttonSmall),
                  ),
                  Gap(AppSizes.gap10),
                  ElevatedButton(
                    onPressed: () => filterExercises("Advance"),
                    style: ElevatedButton.styleFrom(
                      fixedSize: Size(130, AppSizes.buttonSmall),
                      backgroundColor:
                          _selectedFilter == "Advance"
                              ? Theme.of(context).primaryColor
                              : AppColors.grey,
                    ),
                    child: Text("Advance", style: TextStyles.buttonSmall),
                  ),
                ],
              ),
            ),
            Gap(AppSizes.gap15),
            Text("Exercises"),
            Gap(AppSizes.gap10),
            Expanded(
              child:
                  _filteredExercises.isNotEmpty
                      ? GridView.builder(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
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
                                ExerciseScreen(
                                  id: exercise.id,
                                  fromWorkoutScreen: widget.fromWorkoutScreen,
                                  planId: widget.planId,
                                  selectedDay: widget.selectedDay,
                                  exerciseName: exercise.name,
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppSizes.roundedRadius,
                              ),
                              child: GridTile(
                                footer: Container(
                                  padding: EdgeInsets.all(5),
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
                                        ? Padding(
                                          padding: const EdgeInsets.all(
                                            AppSizes.padding16 / 2,
                                          ),
                                          child: Text(
                                            "viewed",
                                            style: TextStyle(
                                              color: Colors.black,
                                            ),
                                            textAlign: TextAlign.end,
                                          ),
                                        )
                                        : Text(""),
                                child: Image.asset(
                                  exercise.image,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Text("Image unavailable"),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      )
                      : Center(child: Text("No exercises found.")),
            ),
          ],
        ),
      ),
    );
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
}
