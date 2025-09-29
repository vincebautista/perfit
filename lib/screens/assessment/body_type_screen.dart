import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/data/models/assessment_model.dart';
import 'package:perfit/screens/assessment/previous_experience_screen.dart';
import 'package:perfit/widgets/assessment_progress_bar.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BodyTypeScreen extends StatefulWidget {
  const BodyTypeScreen({super.key});

  @override
  State<BodyTypeScreen> createState() => _BodyTypeScreenState();
}

class _BodyTypeScreenState extends State<BodyTypeScreen> {
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
                    GestureDetector(
                      onTap: () => saveToProvider("Medium"),
                      child: AspectRatio(
                        aspectRatio: 3 / 1,
                        child: Card(
                          elevation: AppSizes.gap10,
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                right: 0,
                                child: Image.asset(
                                  "assets/images/medium.png",
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Positioned(
                                left: AppSizes.padding16,
                                child: Text("Medium", style: TextStyles.body),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => saveToProvider("Flabby"),
                      child: AspectRatio(
                        aspectRatio: 3 / 1,
                        child: Card(
                          elevation: AppSizes.gap10,
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                right: 0,
                                child: Image.asset(
                                  "assets/images/flabby.png",
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Positioned(
                                left: AppSizes.padding16,
                                child: Text("Flabby", style: TextStyles.body),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => saveToProvider("Skinny"),
                      child: AspectRatio(
                        aspectRatio: 3 / 1,
                        child: Card(
                          elevation: AppSizes.gap10,
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                right: 0,
                                child: Image.asset(
                                  "assets/images/skinny.png",
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Positioned(
                                left: AppSizes.padding16,
                                child: Text("Skinny", style: TextStyles.body),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => saveToProvider("Toned"),
                      child: AspectRatio(
                        aspectRatio: 3 / 1,
                        child: Card(
                          elevation: AppSizes.gap10,
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                right: 0,
                                child: Image.asset(
                                  "assets/images/tonned.png",
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Positioned(
                                left: AppSizes.padding16,
                                child: Text("Toned", style: TextStyles.body),
                              ),
                            ],
                          ),
                        ),
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
    Provider.of<AssessmentModel>(
      context,
      listen: false,
    ).updateAnswer("bodyType", value);

    NavigationUtils.push(context, PreviousExperienceScreen());
  }
}
