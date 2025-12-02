import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/screens/assessment/daily_activity_level_screen.dart';
import 'package:perfit/widgets/assessment_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TrainingLevelScreen extends StatefulWidget {
  const TrainingLevelScreen({super.key, this.fromEdit = false});

  final bool fromEdit;

  @override
  State<TrainingLevelScreen> createState() => _TrainingLevelScreenState();
}

class _TrainingLevelScreenState extends State<TrainingLevelScreen> {
  String? selectedLevel;

  @override
  void initState() {
    super.initState();
    final assessment = Provider.of<AssessmentModel>(context, listen: false);
    selectedLevel = assessment.answers["trainingLevel"];
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
              if (!widget.fromEdit) AssessmentProgressBar(currentValue: 12),
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
                    buildLevelCard("Beginner"),
                    buildLevelCard("Intermediate"),
                    buildLevelCard("Advanced"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildLevelCard(String label) {
    final isSelected = selectedLevel == label;

    return Card(
      color: isSelected ? AppColors.primary : null,
      elevation: AppSizes.gap10,
      child: ListTile(
        onTap: () => saveToProvider(label),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.white : null,
          ),
        ),
        trailing:
            isSelected ? const Icon(Icons.check, color: AppColors.white) : null,
      ),
    );
  }

  void saveToProvider(String value) {
    if (!mounted) return;
    setState(() {
      selectedLevel = value;
    });

    Provider.of<AssessmentModel>(
      context,
      listen: false,
    ).updateAnswer("trainingLevel", value);

    if (widget.fromEdit) {
      Navigator.pop(context);
    } else {
      NavigationUtils.push(context, const DailyActivityLevelScreen());
    }
  }
}
