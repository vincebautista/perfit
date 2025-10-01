import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/screens/food_screen.dart';
import 'package:perfit/screens/home_screen.dart';
import 'package:perfit/screens/profile_screen.dart';
import 'package:perfit/screens/progress_tracking_screen.dart';
import 'package:perfit/screens/welcome_screen.dart';
import 'package:perfit/screens/workout_screen.dart';
import 'package:perfit/widgets/custom_navigation_bar.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key, this.initialIndex = 0});

  final initialIndex;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    _selectedIndex = widget.initialIndex;
  }

  final List _screens = [
    HomeScreen(),
    FoodScreen(),
    WorkoutScreen(),
    ProgressTrackingScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CircularProgressIndicator(color: AppColors.primary);
          }

          if (!snapshot.hasData) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppSizes.padding16,
                AppSizes.padding16,
                AppSizes.padding16,
                AppSizes.padding16,
              ),
              child: ElevatedButton(
                onPressed: () => NavigationUtils.push(context, WelcomeScreen()),
                child: Text("Start your journey"),
              ),
            );
          }

          return CustomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          );
        },
      ),
    );
  }
}
