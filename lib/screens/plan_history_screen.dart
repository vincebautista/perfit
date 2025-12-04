import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/screens/plan_information_screen.dart';
import 'package:perfit/widgets/walk_animation.dart';

class PlanHistoryScreen extends StatefulWidget {
  const PlanHistoryScreen({super.key});

  @override
  State<PlanHistoryScreen> createState() => _PlanHistoryScreenState();
}

class _PlanHistoryScreenState extends State<PlanHistoryScreen> {
  final user = FirebaseAuth.instance.currentUser;

  Future<List<QueryDocumentSnapshot>> getPlanHistory() async {
    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();

    final activePlanId = userDoc.data()?['activeFitnessPlan'];

    final plansSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('fitnessPlan')
            .get();

    // Exclude the active plan
    final history =
        plansSnapshot.docs.where((doc) => doc.id != activePlanId).toList();

    return history;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Plan History")),
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: getPlanHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: WalkAnimation());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No plan history available."));
          }

          final data = snapshot.data!;

          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (_, index) {
              final plan = data[index].data() as Map<String, dynamic>;
              print(plan);
              return ListTile(
                title: Text(plan['name'] ?? "Plan ${index + 1}"),
                onTap:
                    () => NavigationUtils.push(
                      context,
                      PlanInformationScreen(planId: data[index].id),
                    ),
              );
            },
          );
        },
      ),
    );
  }
}
