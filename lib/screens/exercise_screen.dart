import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/services/setting_service.dart';
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
      appBar: AppBar(title: Text(exercise.name)),
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
              : Center(child: CircularProgressIndicator()),
    );
  }
}
