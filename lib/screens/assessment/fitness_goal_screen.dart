import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/screens/assessment/body_type_screen.dart';
import 'package:perfit/screens/assessment/target_weight_screen.dart';
import 'package:perfit/widgets/assessment_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FitnessGoalScreen extends StatefulWidget {
  const FitnessGoalScreen({super.key, this.fromEdit = false});

  final bool fromEdit;

  @override
  State<FitnessGoalScreen> createState() => _FitnessGoalScreenState();
}

class _FitnessGoalScreenState extends State<FitnessGoalScreen> {
  String? selectedGoal;

  @override
  void initState() {
    super.initState();

    final assessment = Provider.of<AssessmentModel>(context, listen: false);

    selectedGoal = assessment.getAnswer("fitnessGoal");
  }

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
              AssessmentProgressBar(currentValue: 5),
              Expanded(
                child: Column(
                  spacing: AppSizes.gap10,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "What is your fitness goal?",
                      style: TextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                    buildGoalCard("Lose fat"),
                    buildGoalCard("Build muscle"),
                    buildGoalCard("General health and fitness"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildGoalCard(String goal) {
    final isSelected = selectedGoal == goal;

    return Card(
      color: isSelected ? AppColors.primary : null,
      child: ListTile(
        onTap: () => saveToProvider(goal),
        title: Text(
          goal,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.white : null,
          ),
        ),
        trailing: isSelected ? Icon(Icons.check, color: AppColors.white) : null,
      ),
    );
  }

  void saveToProvider(String value) {
    Provider.of<AssessmentModel>(
      context,
      listen: false,
    ).updateAnswer("fitnessGoal", value);

    if (widget.fromEdit) {
      Navigator.pop(context);
    } else {
      if (value == "Lose fat" || value == "Build muscle") {
        NavigationUtils.push(context, TargetWeightScreen());
      } else {
        NavigationUtils.push(context, BodyTypeScreen());
      }
    }
  }
}
