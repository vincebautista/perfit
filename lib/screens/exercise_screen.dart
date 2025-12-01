import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/core/utils/validation_utils.dart';
import 'package:perfit/data/data_sources/exercise_list.dart';
import 'package:perfit/data/models/exercise_model.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class ExerciseScreen extends StatefulWidget {
  final String id;

  const ExerciseScreen({super.key, required this.id});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  late ExerciseModel exercise;
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();

    exercise = exercises.firstWhere((e) => e.id == widget.id);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name),
        actions: [
          TextButton(
            onPressed: () {
              final currentIndex = exercises.indexWhere(
                (e) => e.id == exercise.id,
              );

              if (currentIndex != -1 && currentIndex < exercises.length - 1) {
                final nextExercise = exercises[currentIndex + 1];

                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => ExerciseScreen(id: nextExercise.id),
                  ),
                );
              } else {
                ValidationUtils.snackBar(
                  context,
                  "You've reached the last exercise!",
                );
              }
            },
            child: Text("Next"),
          ),
        ],
      ),
      body:
          _chewieController != null && _videoController.value.isInitialized
              ? Column(
                mainAxisAlignment: MainAxisAlignment.start,
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
                ],
              )
              : Center(child: CircularProgressIndicator()),
    );
  }
}
