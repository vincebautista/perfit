import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/screens/main_navigation.dart';
import 'package:perfit/screens/onboarding/screen_two.dart';
import 'package:perfit/widgets/circle.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ScreenOne extends StatelessWidget {
  const ScreenOne({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/screen_one_bg.png"),
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
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
              Text(
                "Your All-in-One Fitness Companion",
                style: TextStyles.title,
              ),
              Gap(AppSizes.gap20),
              Text(
                "Crush your fitness goals—anytime, anywhere. Whether you’re working out at home or hitting the gym, get personalized support with expert guidance, trusted service recommendations, and tools built around your lifestyle.",
                style: TextStyles.caption,
              ),
              Gap(AppSizes.gap20),
              Row(
                children: [
                  Circle(
                    height: 10,
                    width: 10,
                    color: Theme.of(context).primaryColor,
                  ),
                  Gap(AppSizes.gap10),
                  Circle(height: 10, width: 10, color: AppColors.grey),
                  Gap(AppSizes.gap10),
                  Circle(height: 10, width: 10, color: AppColors.grey),
                  Spacer(),
                  ElevatedButton(
                    onPressed:
                        () =>
                            NavigationUtils.goTo(context, ScreenTwo(), "left"),
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
