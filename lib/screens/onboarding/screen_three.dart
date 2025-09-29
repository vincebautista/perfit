import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/screens/main_navigation.dart';
import 'package:perfit/screens/onboarding/screen_two.dart';
import 'package:perfit/widgets/circle.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScreenThree extends StatefulWidget {
  const ScreenThree({super.key});

  @override
  State<ScreenThree> createState() => _ScreenThreeState();
}

class _ScreenThreeState extends State<ScreenThree> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/screen_three_bg.png"),
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
                            NavigationUtils.goTo(context, ScreenTwo(), "right"),
                    icon: Icon(Icons.arrow_back),
                  ),
                ],
              ),
              Spacer(),
              Text("Meal Plans & Progress Tracking", style: TextStyles.title),
              Gap(AppSizes.gap20),
              Text(
                "Stay on top of your fitness journey. Track your workouts, monitor weight, and follow personalized meal plans tailored to your goals—whether you’re aiming to build muscle, lose weight, or maintain a healthy routine.",
                style: TextStyles.caption,
              ),
              Gap(AppSizes.gap20),
              Row(
                children: [
                  Circle(height: 10, width: 10, color: AppColors.grey),
                  Gap(AppSizes.gap10),
                  Circle(height: 10, width: 10, color: AppColors.grey),
                  Gap(AppSizes.gap10),
                  Circle(
                    height: 10,
                    width: 10,
                    color: Theme.of(context).primaryColor,
                  ),
                  Spacer(),
                  ElevatedButton(
                    onPressed: completeOnboarding,
                    style: ElevatedButton.styleFrom(
                      fixedSize: Size(150, AppSizes.buttonLarge),
                    ),
                    child: Text("Get Started", style: TextStyles.buttonLarge),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool("onboarding_complete", true);

    NavigationUtils.pushAndRemoveUntil(context, MainNavigation());
  }
}
