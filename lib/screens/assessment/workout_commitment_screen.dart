import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/screens/assessment/answers_screen.dart';
import 'package:perfit/widgets/assessment_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WorkoutCommitmentScreen extends StatefulWidget {
  const WorkoutCommitmentScreen({super.key, this.fromEdit = false});

  final bool fromEdit;

  @override
  State<WorkoutCommitmentScreen> createState() =>
      _WorkoutCommitmentScreenState();
}

class _WorkoutCommitmentScreenState extends State<WorkoutCommitmentScreen> {
  String? selectedValue;

  @override
  void initState() {
    super.initState();
    // preload previous answer if editing
    final currentValue =
        Provider.of<AssessmentModel>(
          context,
          listen: false,
        ).answers["workoutCommitment"];
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
              AssessmentProgressBar(currentValue: 14),
              Expanded(
                child: Column(
                  spacing: AppSizes.gap10,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "How many days per week can you commit to working out?",
                      style: TextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                    buildOption("4", "4 days"),
                    buildOption("5", "5 days"),
                    buildOption("6", "6 days"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildOption(String value, String label) {
    final isSelected = selectedValue == value;
    return Card(
      color: isSelected ? AppColors.primary : null, // 🔹 highlight
      elevation: AppSizes.gap10,
      child: ListTile(
        onTap: () {
          if (!mounted) return;
          setState(() => selectedValue = value);
          saveToProvider(value);
        },
        title: Text(
          label,
          style: TextStyles.body.copyWith(
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
    ).updateAnswer("workoutCommitment", value);

    if (widget.fromEdit) {
      Navigator.pop(context);
    } else {
      NavigationUtils.push(context, AnswersScreen());
    }
  }
}
