import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/screens/main_navigation.dart';
import 'package:perfit/screens/onboarding/screen_one.dart';
import 'package:perfit/screens/onboarding/screen_three.dart';
import 'package:perfit/widgets/circle.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ScreenTwo extends StatelessWidget {
  const ScreenTwo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/screen_two_bg.png"),
            alignment: Alignment.topCenter,
            opacity: 0.9,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.padding16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed:
                        () =>
                            NavigationUtils.goTo(context, ScreenOne(), "right"),
                    icon: Icon(Icons.arrow_back),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed:
                        () => NavigationUtils.goTo(
                          context,
                          MainNavigation(),
                          "left",
                        ),
                    child: Text(
                      "Skip",
                      style: TextStyles.buttonSmall.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
              Spacer(),
              Text("AI-Powered Form Analysis", style: TextStyles.title),
              Gap(AppSizes.gap20),
              Text(
                "Train smarter with real-time posture tracking. Our AI detects your form and reps during workouts, giving you instant feedback and tips to improve performance while avoiding injuries—perfect for solo sessions at home or at the gym.",
                style: TextStyles.caption,
              ),
              Gap(AppSizes.gap20),
              Row(
                children: [
                  Circle(height: 10, width: 10, color: AppColors.grey),
                  Gap(AppSizes.gap10),
                  Circle(
                    height: 10,
                    width: 10,
                    color: Theme.of(context).primaryColor,
                  ),
                  Gap(AppSizes.gap10),
                  Circle(height: 10, width: 10, color: AppColors.grey),
                  Spacer(),
                  ElevatedButton(
                    onPressed:
                        () => NavigationUtils.goTo(
                          context,
                          ScreenThree(),
                          "left",
                        ),
                    style: ElevatedButton.styleFrom(
                      fixedSize: Size(150, AppSizes.buttonLarge),
                    ),
                    child: Text("Next", style: TextStyles.buttonLarge),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
