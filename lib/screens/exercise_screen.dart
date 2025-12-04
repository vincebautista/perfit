import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/services/setting_service.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/core/utils/validation_utils.dart';
import 'package:perfit/data/data_sources/exercise_list.dart';
import 'package:perfit/data/models/exercise_model.dart';
import 'package:perfit/screens/form_correction/form_correction_router.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:perfit/widgets/walk_animation.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class ExerciseScreen extends StatefulWidget {
  final String id;
  final bool fromWorkoutScreen;
  final String? planId;
  final int? selectedDay;
  final String? exerciseName;

  const ExerciseScreen({
    super.key,
    required this.id,
    this.fromWorkoutScreen = false,
    this.planId,
    this.selectedDay,
    this.exerciseName,
  });

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  late ExerciseModel exercise;
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;

  final SettingService _settingService = SettingService();
  bool isDarkMode = true;

  @override
  void initState() {
    super.initState();

    exercise = exercises.firstWhere((e) => e.id == widget.id);

    _videoController = VideoPlayerController.asset(exercise.video[0]);

    _videoController.initialize().then((_) {
      if (!mounted) return;
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: false,
        looping: true,
        allowMuting: true,
        aspectRatio: _videoController.value.aspectRatio,
      );

      setState(() {});
    });

    _loadTheme();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _loadTheme() async {
    final mode = await _settingService.loadThemeMode();
    if (!mounted) return;
    setState(() {
      isDarkMode = mode == ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name),
        actions: [
          if (exercise.hasFormCorrection && !widget.fromWorkoutScreen)
            GestureDetector(
              onTap: () {
                final correctionScreen = FormCorrectionRouter.getScreen(
                  exercise.id,
                );

                if (correctionScreen == null) {
                  ValidationUtils.snackBar(
                    context,
                    "Form correction not available for this exercise!",
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => correctionScreen),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.padding16 * 2,
                  vertical: AppSizes.padding16,
                ),
                child: Text(
                  "Form Correction",
                  style: TextStyles.label.copyWith(
                    color: isDarkMode ? AppColors.white : AppColors.black,
                  ),
                ),
              ),
            ),
          if (widget.fromWorkoutScreen)
            TextButton(
              onPressed: () async {
                final result = await showDialog<Map<String, int>>(
                  context: context,
                  builder: (context) {
                    int sets = 3;
                    int repsOrDuration = 10;

                    return AlertDialog(
                      title: Text("Add Exercise"),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: "Sets"),
                            onChanged: (val) => sets = int.tryParse(val) ?? 3,
                          ),
                          Gap(AppSizes.gap15),
                          TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Reps / Duration",
                            ),
                            onChanged:
                                (val) =>
                                    repsOrDuration = int.tryParse(val) ?? 10,
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context, {
                              'sets': sets,
                              'repsOrDuration': repsOrDuration,
                            });
                          },
                          child: Text(
                            "Add",
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                      ],
                    );
                  },
                );

                if (result != null) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null ||
                      widget.planId == null ||
                      widget.selectedDay == null)
                    return;

                  final workoutDocRef = FirebaseFirestore.instance
                      .collection("users")
                      .doc(user.uid)
                      .collection("fitnessPlan")
                      .doc(widget.planId)
                      .collection("workouts")
                      .doc(widget.selectedDay.toString());

                  // Append exercise to the exercises array
                  await workoutDocRef.update({
                    "exercises": FieldValue.arrayUnion([
                      {
                        "name": widget.exerciseName,
                        "sets": result['sets'],
                        "reps": result['repsOrDuration'],
                        "status": "pending",
                        "elapsedTime": 0,
                        "rest": 60, // default rest, or you can ask
                      },
                    ]),
                  });

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Exercise added to Day ${widget.selectedDay}!",
                      ),
                    ),
                  );

                  Navigator.pop(context); // go back to workout screen
                }
              },
              child: Text(
                "Add to Workout",
                style: TextStyle(color: AppColors.primary),
              ),
            ),
        ],
      ),
      body:
          _chewieController != null && _videoController.value.isInitialized
              ? Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: _videoController.value.aspectRatio,
                        child: Chewie(controller: _chewieController!),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Card(
                          color: AppColors.primary,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.padding16,
                              vertical: AppSizes.padding16 - 8,
                            ),
                            child: Text(
                              exercise.difficulty,
                              style: TextStyles.label.copyWith(
                                color:
                                    isDarkMode
                                        ? AppColors.black
                                        : AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Gap(AppSizes.gap15),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.padding16,
                    ),
                    child: Text(
                      "Instructions",
                      textAlign: TextAlign.center,
                      style: TextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Gap(AppSizes.gap10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: exercise.instructions.length,
                      itemBuilder: (context, index) {
                        final instruction = exercise.instructions[index];

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text("${index + 1}"),
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor:
                                Theme.of(context).scaffoldBackgroundColor,
                          ),
                          title: Text(instruction),
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          final currentIndex = exercises.indexWhere(
                            (e) => e.id == exercise.id,
                          );

                          if (currentIndex > 0) {
                            final prevExercise = exercises[currentIndex - 1];

                            if (!mounted) return;
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder:
                                    (_) => ExerciseScreen(id: prevExercise.id),
                              ),
                            );
                          } else {
                            if (!mounted) return;
                            ValidationUtils.snackBar(
                              context,
                              "You're already at the first exercise!",
                            );
                          }
                        },
                        child: Card(
                          color: AppColors.grey,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.padding16 * 3,
                              vertical: AppSizes.padding16,
                            ),
                            child: Text(
                              "Back",
                              style: TextStyles.label.copyWith(
                                color:
                                    isDarkMode
                                        ? AppColors.black
                                        : AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Gap(AppSizes.gap20),
                      GestureDetector(
                        onTap: () {
                          final currentIndex = exercises.indexWhere(
                            (e) => e.id == exercise.id,
                          );

                          if (currentIndex != -1 &&
                              currentIndex < exercises.length - 1) {
                            final nextExercise = exercises[currentIndex + 1];

                            if (!mounted) return;
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder:
                                    (_) => ExerciseScreen(id: nextExercise.id),
                              ),
                            );
                          } else {
                            if (!mounted) return;
                            ValidationUtils.snackBar(
                              context,
                              "You've reached the last exercise!",
                            );
                          }
                        },
                        child: Card(
                          color: AppColors.primary,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.padding16 * 3,
                              vertical: AppSizes.padding16,
                            ),
                            child: Text(
                              "Next",
                              style: TextStyles.label.copyWith(
                                color:
                                    isDarkMode
                                        ? AppColors.black
                                        : AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Gap(AppSizes.gap20),
                ],
              )
              : Center(child: WalkAnimation()),
    );
  }
}
