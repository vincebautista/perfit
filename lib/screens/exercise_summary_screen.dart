import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/screens/form_correction/curl_up_screen.dart';
import 'package:perfit/widgets/text_styles.dart';

class ExerciseSummaryScreen extends StatelessWidget {
  final int correct;
  final int wrong;
  final List<String> feedbacks;

  const ExerciseSummaryScreen({
    super.key,
    required this.correct,
    required this.wrong,
    required this.feedbacks,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Exercise Summary")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          // crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.padding16,
              ),
              child: Card(
                color: AppColors.grey,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text("CORRECT", style: TextStyles.label),
                          Gap(6),
                          Text(
                            "$correct",
                            style: TextStyles.subtitle.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 40,
                        width: 1.2,
                        color: Colors.grey.shade300,
                      ),
                      Column(
                        children: [
                          Text("WRONG", style: TextStyles.label),
                          Gap(6),
                          Text(
                            "$wrong",
                            style: TextStyles.subtitle.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(width: double.infinity, child: Text("Feedback")),
            Expanded(
              child: ListView.builder(
                itemCount: feedbacks.length,
                itemBuilder:
                    (context, index) =>
                        Card(child: ListTile(title: Text(feedbacks[index]))),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap:
                      () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => CurlUpScreen()),
                      ),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.primary, // line color
                        width: 1.0, // line thickness
                      ),
                      borderRadius: BorderRadius.circular(
                        8,
                      ), // optional: rounded corners
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.padding16,
                      vertical: AppSizes.padding16 / 2,
                    ),
                    child: Text(
                      "Try Again",
                      style: TextStyles.body.copyWith(color: AppColors.primary),
                    ),
                  ),
                ),
                Gap(AppSizes.gap10),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.primary, // line color
                        width: 1.0, // line thickness
                      ),
                      borderRadius: BorderRadius.circular(
                        8,
                      ), // optional: rounded corners
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.padding16,
                      vertical: AppSizes.padding16 / 2,
                    ),
                    child: Text(
                      "Done",
                      style: TextStyles.body.copyWith(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
