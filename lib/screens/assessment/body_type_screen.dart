import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/screens/assessment/previous_experience_screen.dart';
import 'package:perfit/widgets/assessment_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BodyTypeScreen extends StatefulWidget {
  const BodyTypeScreen({super.key, this.fromEdit = false});

  final bool fromEdit;

  @override
  State<BodyTypeScreen> createState() => _BodyTypeScreenState();
}

class _BodyTypeScreenState extends State<BodyTypeScreen> {
  String? selectedBodyType;
  String? gender;

  @override
  void initState() {
    super.initState();

    final assessment = Provider.of<AssessmentModel>(context, listen: false);
    selectedBodyType = assessment.answers["bodyType"];
    gender = assessment.answers["gender"];
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
              AssessmentProgressBar(currentValue: 7),
              Expanded(
                child: Column(
                  spacing: AppSizes.gap10,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "What is your current body type?",
                      style: TextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                    buildBodyCard("Medium"),
                    buildBodyCard("Flabby"),
                    buildBodyCard("Skinny"),
                    buildBodyCard("Toned"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildBodyCard(String label) {
    final isSelected = selectedBodyType == label;

    final imagePath =
        gender == "Female"
            ? "assets/images/female_${label.toLowerCase()}.png"
            : "assets/images/male_${label.toLowerCase()}.png";

    return GestureDetector(
      onTap: () => saveToProvider(label),
      child: AspectRatio(
        aspectRatio: 3 / 1,
        child: Card(
          color: isSelected ? AppColors.primary : null,
          elevation: AppSizes.gap10,
          child: Stack(
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
    setState(() {
      selectedBodyType = value;
    });

    Provider.of<AssessmentModel>(
      context,
      listen: false,
    ).updateAnswer("bodyType", value);

    if (widget.fromEdit) {
      Navigator.pop(context);
    } else {
      NavigationUtils.push(context, PreviousExperienceScreen());
    }
  }
}
