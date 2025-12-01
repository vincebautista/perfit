import 'dart:async';
import 'package:flutter/material.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/services/firebase_firestore_service.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/exercise_model.dart';
import 'package:perfit/data/models/exercise_metrics_model.dart';
import 'package:perfit/screens/exercise_start_screen.dart';
import 'package:perfit/screens/main_navigation.dart';

class RestScreen extends StatefulWidget {
  final int restSeconds;
  final int currentSet;
  final int totalSets;
  final ExerciseModel exercise;
  final int? reps;
  final int? duration;
  final String planId;
  final String day;
  final List<ExerciseMetricsModel> exercises;
  final bool skip;

  const RestScreen({
    super.key,
    this.restSeconds = 30,
    required this.currentSet,
    required this.totalSets,
    required this.exercise,
    this.reps,
    this.duration,
    required this.planId,
    required this.day,
    required this.exercises,
    this.skip = false,
  });

  @override
  State<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<RestScreen> {
  late int remainingTime;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    remainingTime = widget.restSeconds;

    timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (remainingTime > 0) {
        if (!mounted) return;
        setState(() => remainingTime--);
      } else {
        t.cancel();
        if (!mounted) return;

        await _handleNext();
      }
    });
  }

  Future<void> _handleNext() async {
    if (widget.skip || widget.currentSet >= widget.totalSets) {
      // Skip or last set → save to Firebase and go to MainNavigation
      if (!widget.skip) {
        await FirebaseFirestoreService().markExerciseCompleted(
          widget.planId,
          widget.day,
          widget.exercise.name,
          extraData: {"elapsedTime": 0},
        );
        await FirebaseFirestoreService().updateWorkoutDayCompletion(
          widget.planId,
          int.parse(widget.day),
        );
      }

      if (!mounted) return;
      NavigationUtils.pushAndRemoveUntil(
        context,
        MainNavigation(initialIndex: 2),
      );
    } else {
      // Next set → back to ExerciseStartScreen
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => ExerciseStartScreen(
                exercise: widget.exercise,
                sets: widget.totalSets,
                reps: widget.reps,
                duration: widget.duration,
                planId: widget.planId,
                day: widget.day,
                exercises: widget.exercises,
                currentIndex: widget.currentSet - 1,
                currentSet: widget.currentSet,
                skipCountdown: true, // skip countdown after rest
              ),
        ),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rest Time")),
      body: Center(
        child: Text(
          "$remainingTime",
          style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.gap20),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () async {
              timer?.cancel();
              await _handleNext();
            },
            child: const Text("Skip"),
          ),
        ),
      ),
    );
  }
}
