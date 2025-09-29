import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/screens/assessment/daily_activity_level_screen.dart';
import 'package:perfit/widgets/assessment_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TrainingLevelScreen extends StatefulWidget {
  const TrainingLevelScreen({super.key});

  @override
  State<TrainingLevelScreen> createState() => _TrainingLevelScreenState();
}

class _TrainingLevelScreenState extends State<TrainingLevelScreen> {
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
              AssessmentProgressBar(currentValue: 12),
              Expanded(
                child: Column(
                  spacing: AppSizes.gap10,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "What is your training level?",
                      style: TextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                    Card(
                      elevation: AppSizes.gap10,
                      child: ListTile(
                        onTap: () => saveToProvider("Beginner"),
                        title: Text("Beginner", style: TextStyles.body),
                      ),
                    ),
                    Card(
                      elevation: AppSizes.gap10,
                      child: ListTile(
                        onTap: () => saveToProvider("Intermediate"),
                        title: Text("Intermediate", style: TextStyles.body),
                      ),
                    ),
                    Card(
                      elevation: AppSizes.gap10,
                      child: ListTile(
                        onTap: () => saveToProvider("Advanced"),
                        title: Text("Advanced", style: TextStyles.body),
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
    ).updateAnswer("trainingLevel", value);

    NavigationUtils.push(context, DailyActivityLevelScreen());
  }
}
