import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/screens/welcome_screen.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class WelcomeGuest extends StatelessWidget {
  const WelcomeGuest({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.padding16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Welcome!",
              textAlign: TextAlign.center,
              style: TextStyles.heading,
            ),
            Gap(AppSizes.gap10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Text(
                "Ready to perfect your form and build strength the right way?",
                style: TextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ),
            Gap(AppSizes.gap20 * 2),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 50),
              child: ElevatedButton(
                onPressed: () => NavigationUtils.push(context, WelcomeScreen()),
                child: Text("Get Started!"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
