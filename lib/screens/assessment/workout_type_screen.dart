import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/screens/assessment/training_level_screen.dart';
import 'package:perfit/widgets/assessment_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WorkoutTypeScreen extends StatefulWidget {
  const WorkoutTypeScreen({super.key, this.fromEdit = false});

  final bool fromEdit;

  @override
  State<WorkoutTypeScreen> createState() => _WorkoutTypeScreenState();
}

class _WorkoutTypeScreenState extends State<WorkoutTypeScreen> {
  String? selectedType;

  @override
  void initState() {
    super.initState();
    final assessment = Provider.of<AssessmentModel>(context, listen: false);
    selectedType = assessment.answers["workoutLocation"];
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
              if (!widget.fromEdit) AssessmentProgressBar(currentValue: 9),
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
                    buildWorkoutCard(
                      "home",
                      "Home-based",
                      "assets/images/home_based.png",
                    ),
                    buildWorkoutCard(
                      "gym",
                      "Gym-based",
                      "assets/images/gym_based.png",
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

  Widget buildWorkoutCard(String value, String label, String imagePath) {
    final isSelected = selectedType == value;

    return GestureDetector(
      onTap: () => saveToProvider(value),
      child: AspectRatio(
        aspectRatio: 3 / 1,
        child: Card(
          color: isSelected ? AppColors.primary : null,
          elevation: AppSizes.gap10,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            alignment: Alignment.center,
            children: [
              Positioned(
                right: 0,
                child: Image.asset(imagePath, fit: BoxFit.contain),
              ),
              Positioned(
                left: AppSizes.padding16,
                child: Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.white : null,
                      ),
                    ),
                    if (isSelected)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.check, color: AppColors.white),
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
    if (!mounted) return;
    setState(() {
      selectedType = value;
    });

    Provider.of<AssessmentModel>(
      context,
      listen: false,
    ).updateAnswer("workoutLocation", value);

    if (widget.fromEdit) {
      Navigator.pop(context);
    } else {
      NavigationUtils.push(context, const TrainingLevelScreen());
    }
  }
}
