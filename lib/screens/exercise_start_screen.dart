import 'dart:async';
import 'package:gap/gap.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/services/firebase_firestore_service.dart';
import 'package:perfit/core/services/setting_service.dart';
import 'package:perfit/data/models/exercise_model.dart';
import 'package:perfit/data/models/exercise_metrics_model.dart';
import 'package:perfit/screens/rest_screen.dart';
import 'package:perfit/widgets/circular_countdown.dart';
import 'package:perfit/widgets/text_styles.dart';

class ExerciseStartScreen extends StatefulWidget {
  final ExerciseModel exercise;
  final int sets;
  final int? reps;
  final int? duration;
  final String planId;
  final String day;
  final List<ExerciseMetricsModel> exercises;
  final int currentIndex;
  final int currentSet; // NEW
  final bool skipCountdown;

  const ExerciseStartScreen({
    super.key,
    required this.exercise,
    required this.sets,
    this.reps,
    this.duration,
    required this.planId,
    required this.day,
    required this.exercises,
    required this.currentIndex,
    this.currentSet = 1,
    this.skipCountdown = false,
  });

  @override
  State<ExerciseStartScreen> createState() => _ExerciseStartScreenState();
}

class _ExerciseStartScreenState extends State<ExerciseStartScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;

  bool isCountdownOver = false;
  int remainingTime = 0;
  // int elapsedTime = 0;

  Timer? countdownTimer;
  Timer? exerciseTimer;
  Timer? repTimer;

  int rest = 60;
  int countdown = 3;
  int _startCountdown = 3;
  bool isRepExercise = false;

  @override
  void initState() {
    super.initState();

    loadSettings();

    isRepExercise = widget.exercise.type == "rep";

    // Initialize video
    _videoController = VideoPlayerController.asset(widget.exercise.video[0]);
    _videoController.initialize().then((_) {
      if (!mounted) return;
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: true,
        allowMuting: true,
        aspectRatio: _videoController.value.aspectRatio,
      );
      setState(() {});
    });

    if (widget.skipCountdown) {
      // Skip countdown after rest
      isCountdownOver = true;
      remainingTime = widget.duration ?? 0;
      // elapsedTime = 0;

      if (widget.exercise.type == "time" && widget.duration != null) {
        startExerciseTimer();
      } else if (isRepExercise) {
        startRepTimer();
      }
    }
  }

  Future<void> loadSettings() async {
    final service = SettingService();
    final restMap = await service.loadRest();
    final countdownMap = await service.loadCountdown();

    if (!mounted) return;
    setState(() {
      rest = restMap["rest"]!;
      countdown = countdownMap["countdown"]!;
      _startCountdown = countdownMap["countdown"]!;
    });

    if (!widget.skipCountdown) startCountdown();
  }

  void startCountdown() {
    countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        countdown--;
        if (countdown == 0) {
          isCountdownOver = true;
          countdownTimer?.cancel();

          if (widget.exercise.type == "time" && widget.duration != null) {
            remainingTime = widget.duration!;
            startExerciseTimer();
          } else if (isRepExercise) {
            startRepTimer();
          }
        }
      });
    });
  }

  void startExerciseTimer() {
    exerciseTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (remainingTime > 0) {
          remainingTime--;
        } else {
          exerciseTimer?.cancel();
        }
      });
    });
  }

  void startRepTimer() {
    repTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        // elapsedTime++;
      });
    });
  }

  void skipExercise() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("Skip exercise?"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Gap(AppSizes.gap20),
                Text("This action is not reversible."),
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
        widget.exercise.name,
      );
      await FirebaseFirestoreService().updateWorkoutDayCompletion(
        widget.planId,
        int.parse(widget.day),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => RestScreen(
                restSeconds: rest,
                currentSet: widget.currentSet,
                totalSets: widget.sets,
                exercise: widget.exercise,
                reps: widget.reps,
                duration: widget.duration,
                planId: widget.planId,
                day: widget.day,
                exercises: widget.exercises,
                skip: true,
              ),
        ),
      );
    }
  }

  void nextSetOrFinish() async {
    if (isRepExercise) repTimer?.cancel();
    if (exerciseTimer != null) exerciseTimer?.cancel();

    if (widget.currentSet < widget.sets) {
      if (!mounted) return;
      // Not last set → go to RestScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => RestScreen(
                restSeconds: rest,
                currentSet: widget.currentSet + 1,
                totalSets: widget.sets,
                exercise: widget.exercise,
                reps: widget.reps,
                duration: widget.duration,
                planId: widget.planId,
                day: widget.day,
                exercises: widget.exercises,
              ),
        ),
      );
    } else {
      // Last set → save to Firebase
      await FirebaseFirestoreService().markExerciseCompleted(
        widget.planId,
        widget.day,
        widget.exercise.name,
        extraData: {"elapsedTime": 1},
      );
      await FirebaseFirestoreService().updateWorkoutDayCompletion(
        widget.planId,
        int.parse(widget.day),
      );

      if (!mounted) return;
      // Go to RestScreen after finishing
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => RestScreen(
                restSeconds: rest,
                currentSet: widget.currentSet,
                totalSets: widget.sets,
                exercise: widget.exercise,
                reps: widget.reps,
                duration: widget.duration,
                planId: widget.planId,
                day: widget.day,
                exercises: widget.exercises,
              ),
        ),
      );
    }
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    exerciseTimer?.cancel();
    repTimer?.cancel();
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.exercise.name)),
      body: Center(
        child:
            countdown > 0 && !isCountdownOver
                ? CircularCountdown(
                  secondsLeft: countdown,
                  totalSeconds: _startCountdown,
                )
                : Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_chewieController != null &&
                        _videoController.value.isInitialized)
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
                                  widget.exercise.difficulty,
                                  style: TextStyles.label,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    Gap(AppSizes.gap10),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.padding16,
                      ),
                      child: Card(
                        color: AppColors.grey,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  Text("SETS", style: TextStyles.label),
                                  Gap(6),
                                  Text(
                                    "${widget.currentSet} / ${widget.sets}",
                                    style: TextStyles.subtitle.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                height: 40,
                                width: 1.2,
                                color: Colors.grey.shade300,
                              ),
                              Column(
                                children: [
                                  Text(
                                    widget.reps != null ? "REPS" : "DURATION",
                                    style: TextStyles.label,
                                  ),
                                  Gap(6),
                                  Text(
                                    widget.reps != null
                                        ? "${widget.reps}"
                                        : "${widget.duration}s",
                                    style: TextStyles.subtitle.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Gap(AppSizes.gap20),
                    if (widget.exercise.type == "time" &&
                        widget.duration != null)
                      CircularCountdown(
                        secondsLeft: remainingTime,
                        totalSeconds: widget.duration!,
                      ),
                    if (widget.exercise.type == "rep" && widget.reps != null)
                      Text(
                        "Perform ${widget.sets} sets of ${widget.reps} reps \n NEED REDESIGN",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    // if (isRepExercise)
                    //   Text(
                    //     "Elapsed Time: $elapsedTime s",
                    //     style: TextStyle(
                    //       fontSize: 18,
                    //       fontWeight: FontWeight.bold,
                    //     ),
                    //     textAlign: TextAlign.center,
                    //   ),
                    Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: skipExercise,
                          child: Card(
                            color: AppColors.grey,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.padding16 * 3,
                                vertical: AppSizes.padding16,
                              ),
                              child: Text("Skip"),
                            ),
                          ),
                        ),
                        Gap(AppSizes.gap20),
                        GestureDetector(
                          onTap: nextSetOrFinish,
                          child: Card(
                            color: AppColors.primary,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.padding16 * 3,
                                vertical: AppSizes.padding16,
                              ),
                              child: Text(
                                widget.currentSet < widget.sets
                                    ? "Next Set"
                                    : "Finish",
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Gap(AppSizes.gap20),
                  ],
                ),
      ),
    );
  }
}
