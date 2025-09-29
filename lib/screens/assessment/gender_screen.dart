import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/core/utils/validation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/screens/assessment/age_screen.dart';
import 'package:perfit/widgets/assessment_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GenderScreen extends StatefulWidget {
  const GenderScreen({super.key});

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> {
  String? selectedGender;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    selectedGender = Provider.of<AssessmentModel>(
      context,
      listen: false,
    ).getAnswer("gender");
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppSizes.padding16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AssessmentProgressBar(currentValue: 1),
              Expanded(
                child: Column(
                  spacing: AppSizes.gap20,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "What is your gender?",
                      style: TextStyles.title,
                      textAlign: TextAlign.center,
                    ),
                    AspectRatio(
                      aspectRatio: 4 / 2,
                      child: Card(
                        elevation: AppSizes.gap10,
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                "assets/images/male.png",
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: AppSizes.padding16,
                              left: AppSizes.padding16,
                              child: Text("Male", style: TextStyles.body),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: RadioListTile(
                                value: "Male",
                                groupValue: selectedGender,
                                activeColor: Theme.of(context).primaryColor,
                                onChanged: (value) {
                                  setState(() {
                                    selectedGender = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AspectRatio(
                      aspectRatio: 4 / 2,
                      child: Card(
                        elevation: AppSizes.gap10,
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                "assets/images/female.png",
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: AppSizes.padding16,
                              left: AppSizes.padding16,
                              child: Text("Female", style: TextStyles.body),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: RadioListTile(
                                value: "Female",
                                groupValue: selectedGender,
                                activeColor: Theme.of(context).primaryColor,
                                onChanged: (value) {
                                  setState(() {
                                    selectedGender = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (selectedGender != null) {
                          Provider.of<AssessmentModel>(
                            context,
                            listen: false,
                          ).updateAnswer("gender", selectedGender!);

                          NavigationUtils.push(context, AgeScreen());
                        } else {
                          ValidationUtils.snackBar(
                            context,
                            "Please select your gender.",
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
