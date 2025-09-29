import 'package:gap/gap.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:flutter/material.dart';
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
              FullWidthBorderText(text: "${answers["gender"]}"),
              Gap(AppSizes.gap10 - 5),
              Text("Age: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(text: "${answers["age"]}"),
              Gap(AppSizes.gap10 - 5),
              Text("Weight: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(text: "${answers["weight"]} kg"),
              Gap(AppSizes.gap10 - 5),
              Text("Height: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(text: "${answers["height"]} cm"),
              Gap(AppSizes.gap10 - 5),
              Text("Fitness Goal: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(text: "${answers["fitnessGoal"]}"),
              Gap(AppSizes.gap10 - 5),
              Text("Target Weight: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(text: "${answers["targetWeight"] ?? 0} kg"),
              Gap(AppSizes.gap10 - 5),
              Text("Body Type: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(text: "${answers["bodyType"]}"),
              Gap(AppSizes.gap10 - 5),
              Text("Fitness Experience: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(text: "${answers["previousExperience"]}"),
              Gap(AppSizes.gap10 - 5),
              Text("Workout Type: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(text: "${answers["workoutLocation"]}"),
              Gap(AppSizes.gap10 - 5),
              Text("Training Level: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(text: "${answers["trainingLevel"]}"),
              Gap(AppSizes.gap10 - 5),
              Text("Daily Activity Level: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(text: "${answers["activityLevel"]}"),
              Gap(AppSizes.gap10 - 5),
              Text("Workout Commitment: ", style: TextStyles.body),
              Gap(AppSizes.gap10 - 5),
              FullWidthBorderText(
                text: "${answers["workoutCommitment"]} days a week",
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
