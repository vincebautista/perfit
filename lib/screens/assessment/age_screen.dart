import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/core/utils/validation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/screens/assessment/weight_screen.dart';
import 'package:perfit/widgets/assessment_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AgeScreen extends StatefulWidget {
  const AgeScreen({super.key, this.fromEdit = false});

  final bool fromEdit;

  @override
  State<AgeScreen> createState() => _AgeScreenState();
}

class _AgeScreenState extends State<AgeScreen> {
  final ageCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    ageCtrl.text =
        Provider.of<AssessmentModel>(context, listen: false).getAnswer("age") ??
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
              AssessmentProgressBar(currentValue: 2),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSizes.gap20,
                  children: [
                    Text(
                      "What is your age?",
                      style: TextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                    TextField(
                      controller: ageCtrl,
                      keyboardType: TextInputType.number,
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (ageCtrl.text.isNotEmpty) {
                          Provider.of<AssessmentModel>(
                            context,
                            listen: false,
                          ).updateAnswer("age", ageCtrl.text);

                          if (widget.fromEdit) {
                            Navigator.pop(context);
                          } else {
                            NavigationUtils.push(context, const WeightScreen());
                          }
                        } else {
                          ValidationUtils.snackBar(
                            context,
                            "Please enter your age.",
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
