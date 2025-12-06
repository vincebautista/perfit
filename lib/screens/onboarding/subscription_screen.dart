import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/screens/welcome_screen.dart'; // Imported WelcomeScreen
import 'package:perfit/widgets/text_styles.dart';
import 'package:flutter/material.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/screen_two_bg.png"),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Container(
          // Gradient overlay
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.1),
                Colors.black.withOpacity(0.6),
                Colors.black.withOpacity(0.9),
                Colors.black,
              ],
              stops: const [0.0, 0.4, 0.7, 1.0],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 24.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Spacer(),
                // Title
                Text(
                  "Premium Access",
                  style: TextStyles.title.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // Description
                Text(
                  "Train smarter with real-time posture tracking. Our AI detects your form and reps during workouts, giving you instant feedback and tips to improve performance.",
                  style: TextStyles.caption.copyWith(
                    color: AppColors.grey,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),

                // Pricing Cards Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPricingCard(
                      context,
                      title: "1 MONTH",
                      price: "\$5.99",
                      isHighlighted: false,
                    ),
                    const SizedBox(width: 8),
                    _buildPricingCard(
                      context,
                      title: "3 MONTHS",
                      price: "\$8.99",
                      tag: "POPULAR",
                      isHighlighted: true,
                    ),
                    const SizedBox(width: 8),
                    _buildPricingCard(
                      context,
                      title: "1 YEAR",
                      price: "\$30.99",
                      tag: "SAVE 20%",
                      isHighlighted: true,
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // Main Action Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed:
                        () => NavigationUtils.goTo(
                          context,
                          WelcomeScreen(), // Changed to WelcomeScreen
                          "left",
                        ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      "Start your 7-day free trial",
                      style: TextStyles.buttonLarge.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Footer Links
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFooterLink("Restore Purchase"),
                    _buildFooterLink("Term of Use"),
                    _buildFooterLink("Privacy Policy"),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return Text(
      text,
      style: TextStyles.caption.copyWith(color: AppColors.grey, fontSize: 12),
    );
  }

  Widget _buildPricingCard(
    BuildContext context, {
    required String title,
    required String price,
    String? tag,
    required bool isHighlighted,
  }) {
    return Expanded(
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: isHighlighted ? Border.all(color: Colors.transparent) : null,
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            const Spacer(),
            Text(
              title,
              style: TextStyles.caption.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: TextStyles.title.copyWith(
                fontSize: 18,
                color: AppColors.white,
              ),
            ),
            const Spacer(),
            if (tag != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.orange,
                alignment: Alignment.center,
                child: Text(
                  tag,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
