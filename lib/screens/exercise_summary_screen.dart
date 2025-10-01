import 'package:flutter/material.dart';

class ExerciseSummaryScreen extends StatelessWidget {
  final int correct;
  final int wrong;
  final List<String> feedback;

  const ExerciseSummaryScreen({
    super.key,
    required this.correct,
    required this.wrong,
    required this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Exercise Summary")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("✅ Correct reps: $correct",
                style: const TextStyle(fontSize: 20)),
            Text("❌ Wrong reps: $wrong",
                style: const TextStyle(fontSize: 20, color: Colors.red)),
            const SizedBox(height: 20),
            const Text("Corrections:", style: TextStyle(fontSize: 18)),
            Expanded(
              child: ListView.builder(
                itemCount: feedback.length,
                itemBuilder: (context, index) =>
                    Text("- ${feedback[index]}"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
