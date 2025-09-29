import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/screens/assessment/answers_screen.dart';
import 'package:perfit/widgets/assessment_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WorkoutCommitmentScreen extends StatefulWidget {
  const WorkoutCommitmentScreen({super.key});

  @override
  State<WorkoutCommitmentScreen> createState() =>
      _WorkoutCommitmentScreenState();
}

class _WorkoutCommitmentScreenState extends State<WorkoutCommitmentScreen> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: EdgeInsets.all(AppSizes.padding16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AssessmentProgressBar(currentValue: 14),
              Expanded(
                child: Column(
                  spacing: AppSizes.gap10,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "How many days per week can you commit to working out?",
                      style: TextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                    Card(
                      elevation: AppSizes.gap10,
                      child: ListTile(
                        onTap: () => saveToProvider("4"),
                        title: Text("4 days", style: TextStyles.body),
                      ),
                    ),
                    Card(
                      elevation: AppSizes.gap10,
                      child: ListTile(
                        onTap: () => saveToProvider("5"),
                        title: Text("5 days", style: TextStyles.body),
                      ),
                    ),
                    Card(
                      elevation: AppSizes.gap10,
                      child: ListTile(
                        onTap: () => saveToProvider("6"),
                        title: Text("6 days", style: TextStyles.body),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void saveToProvider(String value) {
    Provider.of<AssessmentModel>(
      context,
      listen: false,
    ).updateAnswer("workoutCommitment", value);

    NavigationUtils.push(context, AnswersScreen());
  }
}
