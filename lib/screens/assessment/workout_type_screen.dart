import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/screens/assessment/training_level_screen.dart';
import 'package:perfit/widgets/assessment_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WorkoutTypeScreen extends StatefulWidget {
  const WorkoutTypeScreen({super.key});

  @override
  State<WorkoutTypeScreen> createState() => _WorkoutTypeScreenState();
}

class _WorkoutTypeScreenState extends State<WorkoutTypeScreen> {
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
              AssessmentProgressBar(currentValue: 11),
              Expanded(
                child: Column(
                  spacing: AppSizes.gap10,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Preferred Workout Type",
                      style: TextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                    GestureDetector(
                      onTap: () => saveToProvider("home"),
                      child: AspectRatio(
                        aspectRatio: 3 / 1,
                        child: Card(
                          elevation: AppSizes.gap10,
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                right: 0,
                                child: Image.asset(
                                  "assets/images/home_based.png",
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Positioned(
                                left: AppSizes.padding16,
                                child: Text(
                                  "Home-based",
                                  style: TextStyles.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => saveToProvider("gym"),
                      child: AspectRatio(
                        aspectRatio: 3 / 1,
                        child: Card(
                          elevation: AppSizes.gap10,
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                right: 0,
                                child: Image.asset(
                                  "assets/images/gym_based.png",
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Positioned(
                                left: AppSizes.padding16,
                                child: Text(
                                  "Gym-based",
                                  style: TextStyles.body,
                                ),
                              ),
                            ],
                          ),
                        ),
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
    ).updateAnswer("workoutLocation", value);

    NavigationUtils.push(context, TrainingLevelScreen());
  }
}
