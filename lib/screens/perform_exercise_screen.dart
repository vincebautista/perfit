import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/services/firebase_firestore_service.dart';
import 'package:perfit/data/data_sources/exercise_list.dart';
import 'package:perfit/data/models/exercise_metrics_model.dart';
import 'package:perfit/data/models/exercise_model.dart';
import 'package:perfit/screens/exercise_start_screen.dart';
import 'package:perfit/screens/main_navigation.dart';
// import 'package:perfit/screens/exercise_start_screen.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:video_player/video_player.dart';

class PerformExerciseScreen extends StatefulWidget {
  final String name;
  final int sets;
  final int? reps;
  final int? duration;
  final String planId;
  final String day;
  final List<ExerciseMetricsModel> exercises;

  const PerformExerciseScreen({
    super.key,
    required this.name,
    required this.sets,
    this.reps,
    this.duration,
    required this.planId,
    required this.day,
    required this.exercises,
  });

  @override
  State<PerformExerciseScreen> createState() => _PerformExerciseScreenState();
}

class _PerformExerciseScreenState extends State<PerformExerciseScreen> {
  late ExerciseModel exercise;
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    exercise = exercises.firstWhere((e) => e.name == widget.name);

    _videoController = VideoPlayerController.asset(exercise.video[0]);

    _videoController.initialize().then((_) {
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: false,
        looping: true,
        allowMuting: true,
        aspectRatio: _videoController.value.aspectRatio,
      );

      setState(() {});
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void skipExercise() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Skip exercise?"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Gap(AppSizes.gap20),
                Text("This action is not reversible."),
                Gap(AppSizes.gap20),
                Gap(AppSizes.gap20),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text("Cancel"),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: Text("Skip"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );

    if (confirm == true) {
      await FirebaseFirestoreService().markExerciseSkipped(
        widget.planId,
        widget.day,
        exercise.name,
      );

      await FirebaseFirestoreService().updateWorkoutDayCompletion(
        widget.planId,
        int.parse(widget.day),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => MainNavigation(initialIndex: 2)),
        (route) => false,
      );
    }
  }

  void startExercise() {
    print("Starting exercise: ${exercise.name}");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ExerciseStartScreen(
              exercise: exercise,
              sets: widget.sets,
              reps: widget.reps,
              duration: widget.duration,
              planId: widget.planId,
              day: widget.day,
              exercises: widget.exercises,
              currentIndex: 0,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(exercise.name)),
      body:
          _chewieController != null && _videoController.value.isInitialized
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: _videoController.value.aspectRatio,
                    child: Chewie(controller: _chewieController!),
                  ),
                  Gap(AppSizes.gap15),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.padding16,
                    ),
                    child: Text("Sets: ${widget.sets}", style: TextStyles.body),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.padding16,
                    ),
                    child: Text(
                      widget.reps != null
                          ? "Reps: ${widget.reps}"
                          : "Duration: ${widget.duration}s",
                      style: TextStyles.body,
                    ),
                  ),
                  Gap(AppSizes.gap15),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.padding16,
                    ),
                    child: Text(
                      "Difficulty: ${exercise.difficulty}",
                      style: TextStyles.subtitle,
                    ),
                  ),
                  Gap(AppSizes.gap15),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.padding16,
                    ),
                    child: Text("Instructions:", style: TextStyles.subtitle),
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
                    children: [
                      Gap(AppSizes.gap10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => skipExercise(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: Text("Skip"),
                        ),
                      ),
                      Gap(AppSizes.gap10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => startExercise(),
                          child: Text("Start"),
                        ),
                      ),
                      Gap(AppSizes.gap10),
                    ],
                  ),
                  Gap(AppSizes.gap15),
                ],
              )
              : Center(child: CircularProgressIndicator()),
    );
  }
}
