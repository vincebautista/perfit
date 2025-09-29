import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/core/utils/validation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/screens/assessment/body_type_screen.dart';
import 'package:perfit/widgets/assessment_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TargetWeightScreen extends StatefulWidget {
  const TargetWeightScreen({super.key});

  @override
  State<TargetWeightScreen> createState() => _TargetWeightScreenState();
}

class _TargetWeightScreenState extends State<TargetWeightScreen> {
  final targetWeightCtrl = TextEditingController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    targetWeightCtrl.text =
        Provider.of<AssessmentModel>(
          context,
          listen: false,
        ).getAnswer("targetWeight") ??
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
              AssessmentProgressBar(currentValue: 6),
              Expanded(
                child: Column(
                  spacing: AppSizes.gap20,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "What is your target weight(kg)?",
                      style: TextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                    TextField(
                      controller: targetWeightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(border: OutlineInputBorder()),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (targetWeightCtrl.text.isNotEmpty) {
                          Provider.of<AssessmentModel>(
                            context,
                            listen: false,
                          ).updateAnswer("targetWeight", targetWeightCtrl.text);

                          NavigationUtils.push(context, BodyTypeScreen());
                        } else {
                          ValidationUtils.snackBar(
                            context,
                            "Please enter your target weight.",
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
