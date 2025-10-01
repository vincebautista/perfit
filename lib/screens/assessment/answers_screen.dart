import 'package:gap/gap.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:flutter/material.dart';
import 'package:perfit/screens/assessment/age_screen.dart';
import 'package:perfit/screens/assessment/body_type_screen.dart';
import 'package:perfit/screens/assessment/daily_activity_level_screen.dart';
import 'package:perfit/screens/assessment/fitness_goal_screen.dart';
import 'package:perfit/screens/assessment/gender_screen.dart';
import 'package:perfit/screens/assessment/height_screen.dart';
import 'package:perfit/screens/assessment/previous_experience_screen.dart';
import 'package:perfit/screens/assessment/target_weight_screen.dart';
import 'package:perfit/screens/assessment/training_level_screen.dart';
import 'package:perfit/screens/assessment/weight_screen.dart';
import 'package:perfit/screens/assessment/workout_commitment_screen.dart';
import 'package:perfit/screens/assessment/workout_type_screen.dart';
import 'package:perfit/screens/plan_summary_screen.dart';
import 'package:perfit/widgets/full_width_border_text.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:provider/provider.dart';

class AnswersScreen extends StatefulWidget {
  const AnswersScreen({super.key});

  @override
  State<AnswersScreen> createState() => _AnswersScreenState();
}

class _AnswersScreenState extends State<AnswersScreen> {
  Map<String, dynamic> answers = {};

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    answers = Provider.of<AssessmentModel>(context, listen: false).answers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.padding20,
            0,
            AppSizes.padding20,
            AppSizes.padding20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Your Answers", style: TextStyles.heading),
              Gap(AppSizes.gap10 - 5),
              Text("Gender: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(
                text: "${answers["gender"]}",
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GenderScreen(fromEdit: true),
                    ),
                  );

                  setState(() {
                    answers =
                        Provider.of<AssessmentModel>(
                          context,
                          listen: false,
                        ).answers;
                  });
                },
              ),
              Gap(AppSizes.gap10 - 5),
              Text("Age: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(
                text: "${answers["age"]}",
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AgeScreen(fromEdit: true),
                    ),
                  );

                  setState(() {
                    answers =
                        Provider.of<AssessmentModel>(
                          context,
                          listen: false,
                        ).answers;
                  });
                },
              ),
              Gap(AppSizes.gap10 - 5),
              Text("Weight: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(
                text: "${answers["weight"]} kg",
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WeightScreen(fromEdit: true),
                    ),
                  );

                  setState(() {
                    answers =
                        Provider.of<AssessmentModel>(
                          context,
                          listen: false,
                        ).answers;
                  });
                },
              ),
              Gap(AppSizes.gap10 - 5),
              Text("Height: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(
                text: "${answers["height"]} cm",
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HeightScreen(fromEdit: true),
                    ),
                  );

                  setState(() {
                    answers =
                        Provider.of<AssessmentModel>(
                          context,
                          listen: false,
                        ).answers;
                  });
                },
              ),
              Gap(AppSizes.gap10 - 5),
              Text("Fitness Goal: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(
                text: "${answers["fitnessGoal"]}",
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FitnessGoalScreen(fromEdit: true),
                    ),
                  );

                  setState(() {
                    answers =
                        Provider.of<AssessmentModel>(
                          context,
                          listen: false,
                        ).answers;
                  });
                },
              ),
              Gap(AppSizes.gap10 - 5),
              Text("Target Weight: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(
                text: "${answers["targetWeight"] ?? 0} kg",
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TargetWeightScreen(fromEdit: true),
                    ),
                  );

                  setState(() {
                    answers =
                        Provider.of<AssessmentModel>(
                          context,
                          listen: false,
                        ).answers;
                  });
                },
              ),
              Gap(AppSizes.gap10 - 5),
              Text("Body Type: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(
                text: "${answers["bodyType"]}",
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BodyTypeScreen(fromEdit: true),
                    ),
                  );

                  setState(() {
                    answers =
                        Provider.of<AssessmentModel>(
                          context,
                          listen: false,
                        ).answers;
                  });
                },
              ),
              Gap(AppSizes.gap10 - 5),
              Text("Fitness Experience: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(
                text: "${answers["previousExperience"]}",
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PreviousExperienceScreen(fromEdit: true),
                    ),
                  );

                  setState(() {
                    answers =
                        Provider.of<AssessmentModel>(
                          context,
                          listen: false,
                        ).answers;
                  });
                },
              ),
              Gap(AppSizes.gap10 - 5),
              Text("Workout Type: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(
                text: "${answers["workoutLocation"]}",
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WorkoutTypeScreen(fromEdit: true),
                    ),
                  );

                  setState(() {
                    answers =
                        Provider.of<AssessmentModel>(
                          context,
                          listen: false,
                        ).answers;
                  });
                },
              ),
              Gap(AppSizes.gap10 - 5),
              Text("Training Level: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(
                text: "${answers["trainingLevel"]}",
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TrainingLevelScreen(fromEdit: true),
                    ),
                  );

                  setState(() {
                    answers =
                        Provider.of<AssessmentModel>(
                          context,
                          listen: false,
                        ).answers;
                  });
                },
              ),
              Gap(AppSizes.gap10 - 5),
              Text("Daily Activity Level: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(
                text: "${answers["activityLevel"]}",
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DailyActivityLevelScreen(fromEdit: true),
                    ),
                  );

                  setState(() {
                    answers =
                        Provider.of<AssessmentModel>(
                          context,
                          listen: false,
                        ).answers;
                  });
                },
              ),
              Gap(AppSizes.gap10 - 5),
              Text("Workout Commitment: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(
                text: "${answers["workoutCommitment"]} days a week",
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WorkoutCommitmentScreen(fromEdit: true),
                    ),
                  );

                  setState(() {
                    answers =
                        Provider.of<AssessmentModel>(
                          context,
                          listen: false,
                        ).answers;
                  });
                },
              ),
              Gap(AppSizes.gap10),
              ElevatedButton(
                onPressed:
                    () => NavigationUtils.pushAndRemoveUntil(
                      context,
                      PlanSummaryScreen(),
                    ),
                child: Text("Generate Plan"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
