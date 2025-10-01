import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/screens/assessment/workout_type_screen.dart';
import 'package:perfit/widgets/assessment_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PreviousExperienceScreen extends StatefulWidget {
  const PreviousExperienceScreen({super.key, this.fromEdit = false});

  final bool fromEdit;

  @override
  State<PreviousExperienceScreen> createState() =>
      _PreviousExperienceScreenState();
}

class _PreviousExperienceScreenState extends State<PreviousExperienceScreen> {
  String? selectedExperience;

  @override
  void initState() {
    super.initState();
    final assessment = Provider.of<AssessmentModel>(context, listen: false);
    selectedExperience = assessment.answers["previousExperience"];
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
              if (!widget.fromEdit) AssessmentProgressBar(currentValue: 8),
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
                    buildExperienceCard("Yes, consistent past workout routine"),
                    buildExperienceCard("Some, but inconsistent"),
                    buildExperienceCard("No experience"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildExperienceCard(String label) {
    final isSelected = selectedExperience == label;

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
    setState(() {
      selectedExperience = value;
    });

    Provider.of<AssessmentModel>(
      context,
      listen: false,
    ).updateAnswer("previousExperience", value);

    if (widget.fromEdit) {
      Navigator.pop(context);
    } else {
      NavigationUtils.push(context, WorkoutTypeScreen());
    }
  }
}
