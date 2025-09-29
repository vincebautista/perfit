import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/core/utils/validation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/screens/assessment/height_screen.dart';
import 'package:perfit/widgets/assessment_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  final weightCtrl = TextEditingController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    weightCtrl.text =
        Provider.of<AssessmentModel>(
          context,
          listen: false,
        ).getAnswer("weight") ??
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
              AssessmentProgressBar(currentValue: 3),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSizes.gap20,
                  children: [
                    Text(
                      "What is your weight(kg)?",
                      style: TextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                    TextField(
                      controller: weightCtrl,
                      keyboardType: TextInputType.number,
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (weightCtrl.text.isNotEmpty) {
                          Provider.of<AssessmentModel>(
                            context,
                            listen: false,
                          ).updateAnswer("weight", weightCtrl.text);

                          NavigationUtils.push(context, HeightScreen());
                        } else {
                          ValidationUtils.snackBar(
                            context,
                            "Please enter your weight.",
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
