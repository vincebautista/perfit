import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/screens/assessment/workout_commitment_screen.dart';
import 'package:perfit/widgets/assessment_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DailyActivityLevelScreen extends StatefulWidget {
  const DailyActivityLevelScreen({super.key});

  @override
  State<DailyActivityLevelScreen> createState() =>
      _DailyActivityLevelScreenState();
}

class _DailyActivityLevelScreenState extends State<DailyActivityLevelScreen> {
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
              AssessmentProgressBar(currentValue: 13),
              Expanded(
                child: Column(
                  spacing: AppSizes.gap10,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "What is your daily activity level (outside of workouts)?",
                      style: TextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                    Card(
                      elevation: AppSizes.gap10,
                      child: ListTile(
                        onTap: () => saveToProvider("Sedentary"),
                        title: Text("Sedentary", style: TextStyles.body),
                        subtitle: Text("desk job, minimal movement"),
                      ),
                    ),
                    Card(
                      elevation: AppSizes.gap10,
                      child: ListTile(
                        onTap: () => saveToProvider("Lightly Active"),
                        title: Text("Lightly active", style: TextStyles.body),
                        subtitle: Text("some walking or standing"),
                      ),
                    ),
                    Card(
                      elevation: AppSizes.gap10,
                      child: ListTile(
                        onTap: () => saveToProvider("Active"),
                        title: Text("Active", style: TextStyles.body),
                        subtitle: Text("manual labor, regular walking"),
                      ),
                    ),
                    Card(
                      elevation: AppSizes.gap10,
                      child: ListTile(
                        onTap: () => saveToProvider("Very Active"),
                        title: Text("Very active", style: TextStyles.body),
                        subtitle: Text("athlete, physical job"),
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
    ).updateAnswer("activityLevel", value);

    NavigationUtils.push(context, WorkoutCommitmentScreen());
  }
}
