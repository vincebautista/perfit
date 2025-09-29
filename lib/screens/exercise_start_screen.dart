import 'dart:async';
import 'package:gap/gap.dart';
import 'package:perfit/core/services/firebase_firestore_service.dart';
import 'package:perfit/core/services/setting_service.dart';
import 'package:perfit/data/models/exercise_metrics_model.dart';
import 'package:perfit/data/models/exercise_model.dart';
import 'package:perfit/screens/rest_screen.dart';
import 'package:flutter/material.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class ExerciseStartScreen extends StatefulWidget {
  final ExerciseModel exercise;
  final int sets;
  final int? reps;
  final int? duration;
  final String planId;
  final String day;
  final List<ExerciseMetricsModel> exercises;
  final int currentIndex;

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
  });

  @override
  State<ExerciseStartScreen> createState() => _ExerciseStartScreenState();
}

class _ExerciseStartScreenState extends State<ExerciseStartScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool isCountdownOver = false;
  int remainingTime = 0;
  Timer? countdownTimer;
  Timer? exerciseTimer;

  int rest = 60;
  int countdown = 3;

  @override
  void initState() {
    super.initState();

    loadSettings();

    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.exercise.video[0]),
    );

    _videoController.initialize().then((_) {
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: true,
        allowMuting: true,
        aspectRatio: _videoController.value.aspectRatio,
      );
      setState(() {});
    });
  }

  void startCountdown() {
    countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        countdown--;
        if (countdown == 0) {
          isCountdownOver = true;
          countdownTimer?.cancel();

          if (widget.exercise.type == "time" && widget.duration != null) {
            remainingTime = widget.duration!;

            startExerciseTimer();
          }
        }
      });
    });
  }

  void startExerciseTimer() {
    exerciseTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (remainingTime > 0) {
          remainingTime--;
        } else {
          exerciseTimer?.cancel();
        }
      });
    });
  }

  void skipExercise() async {
    await FirebaseFirestoreService().markExerciseSkipped(
      widget.planId,
      widget.day,
      widget.exercise.name,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => RestScreen(restSeconds: rest)),
    );
  }

  void finishExercise() async {
    await FirebaseFirestoreService().markExerciseCompleted(
      widget.planId,
      widget.day,
      widget.exercise.name,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => RestScreen(restSeconds: rest)),
    );
  }

  Future<void> loadSettings() async {
    final service = SettingService();

    final restMap = await service.loadRest();
    final countdownMap = await service.loadCountdown();

    setState(() {
      rest = restMap["rest"]!;
      countdown = countdownMap["countdown"]!;
    });

    startCountdown();
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    exerciseTimer?.cancel();
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child:
            countdown > 0 && !isCountdownOver
                ? Text(
                  "$countdown",
                  style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold),
                )
                : Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_chewieController != null &&
                        _videoController.value.isInitialized)
                      AspectRatio(
                        aspectRatio: _videoController.value.aspectRatio,
                        child: Chewie(controller: _chewieController!),
                      ),
                    SizedBox(height: 20),
                    Text(
                      widget.exercise.name,
                      textAlign: TextAlign.center,
                      style: TextStyles.title,
                    ),
                    SizedBox(height: 20),
                    if (widget.exercise.type == "time" &&
                        widget.duration != null)
                      Text(
                        "Time Left: ${remainingTime}s",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (widget.exercise.type == "rep" && widget.reps != null)
                      Text(
                        "Perform ${widget.sets} sets of ${widget.reps} reps",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    Spacer(),
                    Row(
                      children: [
                        Gap(20),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: finishExercise,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 15,
                              ),
                              backgroundColor: Colors.red,
                            ),
                            child: Text("Skip"),
                          ),
                        ),
                        Gap(20),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: finishExercise,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 15,
                              ),
                            ),
                            child: Text("Finish"),
                          ),
                        ),
                        Gap(20),
                      ],
                    ),
                  ],
                ),
      ),
    );
  }
}
