import 'package:flutter/material.dart';
import 'package:perfit/screens/main_navigation.dart';
import 'package:perfit/screens/onboarding/screen_one.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    );

    _controller.forward().whenComplete(() async {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnBoarding = prefs.getBool('hasSeenOnboarding') ?? false;

      if (!mounted) return;

      if (hasSeenOnBoarding) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => MainNavigation()));
      } else {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => ScreenOne()));
      }
    });
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, childWidget) {
            return Opacity(opacity: _controller.value, child: childWidget);
          },
          child: Image.asset('assets/images/perfit_logo.png'),
        ),
      ),
    );
  }
}
