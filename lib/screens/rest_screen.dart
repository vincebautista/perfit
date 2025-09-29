import 'dart:async';
import 'package:flutter/material.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/screens/main_navigation.dart';

class RestScreen extends StatefulWidget {
  final int restSeconds;

  const RestScreen({super.key, this.restSeconds = 30});

  @override
  State<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<RestScreen> {
  late int remainingTime;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    remainingTime = widget.restSeconds;

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (remainingTime > 0) {
        setState(() => remainingTime--);
      } else {
        _navigateToWorkout();
        t.cancel();
      }
    });
  }

  void _navigateToWorkout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => MainNavigation(initialIndex: 2)),
      (route) => false,
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rest Time")),
      body: Center(
        child: Text(
          "$remainingTime",
          style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.gap20),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: _navigateToWorkout,
            child: const Text("Skip"),
          ),
        ),
      ),
    );
  }
}
