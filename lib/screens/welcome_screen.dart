import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/widgets/button_styles.dart';
import 'package:perfit/widgets/login.dart';
import 'package:perfit/widgets/register.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int num = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          "assets/images/perfit_logo.png",
          height: 80,
          width: 80,
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.padding20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Gap(AppSizes.gap20 * 2),
            Text("Welcome!", style: TextStyles.heading),
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
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.grey, width: 2),
                borderRadius: BorderRadius.all(
                  Radius.circular(AppSizes.circleRadius),
                ),
              ),
              padding: EdgeInsets.all(2),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => displayPage("login"),
                      style: ButtonStyles.customButton.copyWith(
                        backgroundColor: WidgetStatePropertyAll(
                          num == 0
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).scaffoldBackgroundColor,
                        ),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.circleRadius,
                            ),
                          ),
                        ),
                      ),
                      child: Text("Login", style: TextStyles.body),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => displayPage("register"),
                      style: ButtonStyles.customButton.copyWith(
                        backgroundColor: WidgetStatePropertyAll(
                          num == 1
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).scaffoldBackgroundColor,
                        ),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.circleRadius,
                            ),
                          ),
                        ),
                      ),
                      child: Text("Register", style: TextStyles.body),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: num == 0 ? Login() : Register(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void displayPage(String page) {
    if (page == "login") {
      setState(() {
        num = 0;
      });
    }

    if (page == "register") {
      setState(() {
        num = 1;
      });
    }
  }
}
