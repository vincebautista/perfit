import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:perfit/widgets/walk_animation.dart';

class CompletedWorkoutScreen extends StatelessWidget {
  final String userId;
  final String planId;
  final String workoutId;
  final String split;
  final DateTime? dateCompleted;

  const CompletedWorkoutScreen({
    super.key,
    required this.userId,
    required this.planId,
    required this.workoutId,
    required this.split,
    this.dateCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Day $workoutId – $split")),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection("users")
                .doc(userId)
                .collection("fitnessPlan")
                .doc(planId)
                .collection("workouts")
                .doc(workoutId)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: WalkAnimation());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null || !data.containsKey("exercises")) {
            return const Center(child: Text("No exercises found"));
          }

          final exercises = List<Map<String, dynamic>>.from(data["exercises"]);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              final name = exercise["name"] ?? "Exercise";
              final sets = exercise["sets"] ?? 0;
              final reps = exercise["reps"] ?? 0;
              final status = exercise["status"] ?? "pending";

              print(exercise);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: Icon(
                    Icons.radio_button_checked,
                    color:
                        status == "completed"
                            ? Colors.green
                            : status == "skipped"
                            ? Colors.red
                            : Colors.grey,
                  ),
                  title: Text(name),
                  subtitle: Text("$sets sets × $reps reps"),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar:
          dateCompleted != null
              ? Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  "Completed on ${DateFormat("MMM d, yyyy – h:mm a").format(dateCompleted!)}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              )
              : null,
    );
  }
}
