import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/screens/assessment/answers_screen.dart';
import 'package:perfit/screens/assessment/rest_day_selection_screen.dart';
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
  int? selectedDays;
  List<String> restDays = [];

  final List<String> weekDays = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];

  @override
  void initState() {
    super.initState();

    // load previous answers
    final model = Provider.of<AssessmentModel>(context, listen: false);
    selectedDays = model.answers["workoutDays"];
    restDays = (model.answers["restDays"] as List?)?.cast<String>() ?? [];
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
              AssessmentProgressBar(currentValue: 13),
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

                    // 🔥 dynamic list from 1–7
                    for (int i = 1; i <= 7; i++) buildOption(i),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildOption(int value) {
    final isSelected = selectedDays == value;

    return Card(
      color: isSelected ? AppColors.primary : null,
      elevation: AppSizes.gap10,
      child: ListTile(
        onTap: () {
          if (!mounted) return;
          setState(() => selectedDays = value);

          // open rest day selector
          openRestDaySelector(value);
        },
        title: Text(
          "$value day${value == 1 ? '' : 's'}",
          style: TextStyles.body.copyWith(
            color: isSelected ? AppColors.white : null,
          ),
        ),
        trailing: isSelected ? Icon(Icons.check, color: AppColors.white) : null,
      ),
    );
  }

  Future<void> openRestDaySelector(int days) async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder:
            (_) => RestDaySelectionScreen(
              workoutDays: days,
              selectedRestDays: restDays,
            ),
      ),
    );

    if (result != null) {
      restDays = result;
      saveToProvider();
    }
  }

  void saveToProvider() {
    final provider = Provider.of<AssessmentModel>(context, listen: false);

    provider.updateAnswer("workoutDays", selectedDays);
    provider.updateAnswer("restDays", restDays);
    provider.updateAnswer("workoutCommitment", "$selectedDays");

    if (widget.fromEdit) {
      Navigator.pop(context);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AnswersScreen()),
      );
    }
  }
}
