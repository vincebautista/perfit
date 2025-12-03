import 'package:gap/gap.dart';
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/services/setting_service.dart';
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
  final SettingService _settingService = SettingService();

  bool isDarkMode = true;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    answers = Provider.of<AssessmentModel>(context, listen: false).answers;

    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final mode = await _settingService.loadThemeMode();
    if (!mounted) return;
    setState(() {
      isDarkMode = mode == ThemeMode.dark;
    });
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
                style: TextStyles.caption.copyWith(
                  color: isDarkMode ? AppColors.white : AppColors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GenderScreen(fromEdit: true),
                    ),
                  );
                  if (!mounted) return;
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
                style: TextStyles.caption.copyWith(
                  color: isDarkMode ? AppColors.white : AppColors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AgeScreen(fromEdit: true),
                    ),
                  );
                  if (!mounted) return;
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
                style: TextStyles.caption.copyWith(
                  color: isDarkMode ? AppColors.white : AppColors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WeightScreen(fromEdit: true),
                    ),
                  );
                  if (!mounted) return;
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
                style: TextStyles.caption.copyWith(
                  color: isDarkMode ? AppColors.white : AppColors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HeightScreen(fromEdit: true),
                    ),
                  );
                  if (!mounted) return;
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
                style: TextStyles.caption.copyWith(
                  color: isDarkMode ? AppColors.white : AppColors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FitnessGoalScreen(fromEdit: true),
                    ),
                  );
                  if (!mounted) return;
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
                style: TextStyles.caption.copyWith(
                  color: isDarkMode ? AppColors.white : AppColors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TargetWeightScreen(fromEdit: true),
                    ),
                  );
                  if (!mounted) return;
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
                style: TextStyles.caption.copyWith(
                  color: isDarkMode ? AppColors.white : AppColors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BodyTypeScreen(fromEdit: true),
                    ),
                  );
                  if (!mounted) return;
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
                style: TextStyles.caption.copyWith(
                  color: isDarkMode ? AppColors.white : AppColors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PreviousExperienceScreen(fromEdit: true),
                    ),
                  );
                  if (!mounted) return;
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
                style: TextStyles.caption.copyWith(
                  color: isDarkMode ? AppColors.white : AppColors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WorkoutTypeScreen(fromEdit: true),
                    ),
                  );
                  if (!mounted) return;
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
                style: TextStyles.caption.copyWith(
                  color: isDarkMode ? AppColors.white : AppColors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TrainingLevelScreen(fromEdit: true),
                    ),
                  );
                  if (!mounted) return;
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
                style: TextStyles.caption.copyWith(
                  color: isDarkMode ? AppColors.white : AppColors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DailyActivityLevelScreen(fromEdit: true),
                    ),
                  );
                  if (!mounted) return;
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
                text:
                    "${answers["workoutDays"] ?? 0} day${(answers["workoutDays"] ?? 0) > 1 ? 's' : ''} a week"
                    "${(answers["restDays"] != null && (answers["restDays"] as List).isNotEmpty) ? ' (Rest: ${(answers["restDays"] as List).join(', ')})' : ''}",
                style: TextStyles.caption.copyWith(
                  color: isDarkMode ? AppColors.white : AppColors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WorkoutCommitmentScreen(fromEdit: true),
                    ),
                  );
                  if (!mounted) return;
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
                onPressed: () async {
                  bool proceed =
                      await showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder:
                            (context) => AlertDialog(
                              title: Text(
                                "Important Notice",
                                style: TextStyles.caption.copyWith(
                                  color:
                                      isDarkMode
                                          ? AppColors.white
                                          : AppColors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              content: Text(
                                "If you have any illness, injuries, or disabilities, please consult a professional.",
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(true),
                                  child: Text("OK"),
                                ),
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(false),
                                  child: Text("Cancel"),
                                ),
                              ],
                            ),
                      ) ??
                      false;
                  if (proceed) {
                    NavigationUtils.pushAndRemoveUntil(
                      context,
                      PlanSummaryScreen(),
                    );
                  }
                },
                child: Text("Generate Plan"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
