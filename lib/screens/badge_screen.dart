import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';

final List<Map<String, dynamic>> allBadges = [
  {
    "id": "firstWorkout",
    "title": "First Workout Completed",
    "requiredStats": 1,
    "image": "assets/images/badges/firstWorkout.png",
  },
  {
    "id": "7dayStreak",
    "title": "7 Days Streak",
    "requiredStats": 7,
    "image": "assets/images/badges/7dayStreak.png",
  },
  {
    "id": "30dayStreak",
    "title": "30 Days Streak",
    "requiredStats": 30,
    "image": "assets/images/badges/30dayStreak.png",
  },
  {
    "id": "10dayfoodlog",
    "title": "10 Day Food Logs Completed",
    "requiredStats": 10,
    "image": "assets/images/badges/10dayfoodlog.png",
  },
  {
    "id": "30dayfoodlog",
    "title": "30 Day Food Logs Completed",
    "requiredStats": 30,
    "image": "assets/images/badges/30dayfoodlog.png",
  },
  {
    "id": "100workouts",
    "title": "100 Workouts Completed",
    "requiredStats": 100,
    "image": "assets/images/badges/100workouts.png",
  },
];

class BadgeScreen extends StatelessWidget {
  const BadgeScreen({super.key});

  Future<String?> _getActiveFitnessPlan(String uid) async {
    final userDoc =
        await FirebaseFirestore.instance.collection("users").doc(uid).get();
    return userDoc.data()?["activeFitnessPlan"];
  }

  Future<void> _ensureBadgeExists(
    String uid,
    String fitnessPlanId,
    Map<String, dynamic> badge,
  ) async {
    final badgeRef = FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("fitnessPlan")
        .doc(fitnessPlanId)
        .collection("badges")
        .doc(badge["id"]);

    final snapshot = await badgeRef.get();
    if (!snapshot.exists) {
      print("Creating badge: ${badge['id']}");
      await badgeRef.set({
        "image": badge["image"],
        "title": badge["title"],
        "completed": false,
        "stat": 0,
        "requiredStats": badge["requiredStats"],
      });
    }
  }

  Future<Map<String, dynamic>> _prepareBadges(
    String uid,
    String fitnessPlanId,
  ) async {
    // Ensure all badges exist first
    for (var badge in allBadges) {
      print("Processing badge: ${badge['id']}");
      await _ensureBadgeExists(uid, fitnessPlanId, badge);
    }

    // Fetch badges after creation
    final query =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("fitnessPlan")
            .doc(fitnessPlanId)
            .collection("badges")
            .get();

    final Map<String, dynamic> earned = {};
    for (var doc in query.docs) {
      earned[doc.id] = doc.data();
    }

    return earned;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("User not logged in.")));
    }

    final uid = user.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Badges")),
      body: FutureBuilder<String?>(
        future: _getActiveFitnessPlan(uid),
        builder: (context, planSnap) {
          if (planSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!planSnap.hasData ||
              planSnap.data == null ||
              planSnap.data == "") {
            return const Center(child: Text("No active fitness plan found."));
          }

          final fitnessPlanId = planSnap.data!;

          return FutureBuilder<Map<String, dynamic>>(
            future: _prepareBadges(uid, fitnessPlanId),
            builder: (context, badgeSnap) {
              if (badgeSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final earnedBadges = badgeSnap.data ?? {};

              // Count how many badges are completed
              final int collectedCount =
                  allBadges
                      .where(
                        (badge) =>
                            earnedBadges[badge["id"]]?["completed"] == true,
                      )
                      .length;

              // Get only earned badges
              final collectedBadges =
                  allBadges
                      .where(
                        (badge) =>
                            earnedBadges[badge["id"]]?["completed"] == true,
                      )
                      .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: AppColors.grey,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.padding16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Collected Badges Header
                          Text(
                            "Collected Badges",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Collected: $collectedCount / ${allBadges.length}",
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          // Horizontal list of badge images
                          SizedBox(
                            height: 60,
                            child:
                                collectedBadges.isEmpty
                                    ? const Center(
                                      child: Text(
                                        "No badges collected yet",
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    )
                                    : ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: collectedBadges.length,
                                      separatorBuilder:
                                          (_, __) => const SizedBox(width: 12),
                                      itemBuilder: (context, index) {
                                        final badge = collectedBadges[index];
                                        return Image.asset(
                                          badge["image"],
                                          width: 50,
                                          height: 50,
                                        );
                                      },
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      "All Badges",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Detailed badge cards (existing code)
                  ...allBadges.map((badge) {
                    final badgeData = earnedBadges[badge["id"]];
                    final isEarned = badgeData?["completed"] ?? false;
                    final userValue = badgeData?["stat"] ?? 0;
                    final requiredValue = badge["requiredStats"] ?? 1;

                    double progress = userValue / requiredValue;
                    if (progress > 1) progress = 1;

                    return Card(
                      color: const Color(0xff1E1E1E),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Image.asset(
                                  badge["image"],
                                  width: 40,
                                  height: 40,
                                  color: isEarned ? null : Colors.grey,
                                  colorBlendMode: BlendMode.modulate,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    badge["title"],
                                    style: TextStyle(
                                      color:
                                          isEarned ? Colors.white : Colors.grey,
                                      fontWeight:
                                          isEarned
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                isEarned
                                    ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                    : const Icon(
                                      Icons.lock,
                                      color: AppColors.lightgrey,
                                    ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: AppColors.grey,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isEarned
                                  ? "Completed!"
                                  : "$userValue / $requiredValue",
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
