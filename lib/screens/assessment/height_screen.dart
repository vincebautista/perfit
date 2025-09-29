import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/core/utils/validation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/screens/assessment/fitness_goal_screen.dart';
import 'package:perfit/widgets/assessment_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HeightScreen extends StatefulWidget {
  const HeightScreen({super.key});

  @override
  State<HeightScreen> createState() => _HeightScreenState();
}

class _HeightScreenState extends State<HeightScreen> {
  final heightCtrl = TextEditingController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    heightCtrl.text =
        Provider.of<AssessmentModel>(
          context,
          listen: false,
        ).getAnswer("height") ??
        "";
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
              AssessmentProgressBar(currentValue: 4),
              Expanded(
                child: Column(
                  spacing: AppSizes.gap20,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "What is your height(cm)?",
                      style: TextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                    TextField(
                      controller: heightCtrl,
                      keyboardType: TextInputType.number,
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (heightCtrl.text.isNotEmpty) {
                          Provider.of<AssessmentModel>(
                            context,
                            listen: false,
                          ).updateAnswer("height", heightCtrl.text);

                          NavigationUtils.push(context, FitnessGoalScreen());
                        } else {
                          ValidationUtils.snackBar(
                            context,
                            "Please enter your height.",
                          );
                        }
                      },
                      child: Text("Continue"),
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
}
