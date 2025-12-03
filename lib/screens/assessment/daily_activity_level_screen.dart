import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/screens/assessment/workout_commitment_screen.dart';
import 'package:perfit/widgets/assessment_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DailyActivityLevelScreen extends StatefulWidget {
  const DailyActivityLevelScreen({super.key, this.fromEdit = false});

  final bool fromEdit;

  @override
  State<DailyActivityLevelScreen> createState() =>
      _DailyActivityLevelScreenState();
}

class _DailyActivityLevelScreenState extends State<DailyActivityLevelScreen> {
  String? selectedValue;

  @override
  void initState() {
    super.initState();
    // preload the value if editing
    final currentValue =
        Provider.of<AssessmentModel>(
          context,
          listen: false,
        ).answers["activityLevel"];
    selectedValue = currentValue;
  }

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
                      "What is your daily activity level (outside of workouts)?",
                      style: TextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                    buildOption("Sedentary", "desk job, minimal movement"),
                    buildOption("Lightly Active", "some walking or standing"),
                    buildOption("Active", "manual labor, regular walking"),
                    buildOption("Very Active", "athlete, physical job"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildOption(String value, String subtitle) {
    final isSelected = selectedValue == value;
    return Card(
      color: isSelected ? AppColors.primary : null,
      elevation: AppSizes.gap10,
      child: ListTile(
        onTap: () {
          if (!mounted) return;
          setState(() => selectedValue = value);
          saveToProvider(value);
        },
        title: Text(
          value,
          style: TextStyles.body.copyWith(
            color: isSelected ? AppColors.white : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyles.caption.copyWith(
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
    ).updateAnswer("activityLevel", value);

    if (widget.fromEdit) {
      Navigator.pop(context);
    } else {
      NavigationUtils.push(context, WorkoutCommitmentScreen());
    }
  }
}
