import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/screens/assessment/workout_type_screen.dart';
import 'package:perfit/widgets/assessment_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PreviousExperienceScreen extends StatefulWidget {
  const PreviousExperienceScreen({super.key});

  @override
  State<PreviousExperienceScreen> createState() =>
      _PreviousExperienceScreenState();
}

class _PreviousExperienceScreenState extends State<PreviousExperienceScreen> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(AppSizes.padding16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AssessmentProgressBar(currentValue: 8),
              Expanded(
                child: Column(
                  spacing: AppSizes.gap10,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Do you have previous fitness experience?",
                      style: TextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                    Card(
                      elevation: AppSizes.gap10,
                      child: ListTile(
                        onTap:
                            () => saveToProvider(
                              "Yes, consistent past workout routine",
                            ),
                        title: Text(
                          "Yes, consistent past workout routine",
                          style: TextStyles.body,
                        ),
                      ),
                    ),
                    Card(
                      elevation: AppSizes.gap10,
                      child: ListTile(
                        onTap: () => saveToProvider("Some, but inconsistent"),
                        title: Text(
                          "Some, but inconsistent",
                          style: TextStyles.body,
                        ),
                      ),
                    ),
                    Card(
                      elevation: AppSizes.gap10,
                      child: ListTile(
                        onTap: () => saveToProvider("No experience"),
                        title: Text("No experience", style: TextStyles.body),
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
    ).updateAnswer("previousExperience", value);

    NavigationUtils.push(context, WorkoutTypeScreen());
  }
}
