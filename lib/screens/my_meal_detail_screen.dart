import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/core/utils/validation_utils.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:perfit/widgets/walk_animation.dart';

class MyMealDetailScreen extends StatefulWidget {
  final String id;

  const MyMealDetailScreen({super.key, required this.id});

  @override
  State<MyMealDetailScreen> createState() => _MyMealDetailScreenState();
}

class _MyMealDetailScreenState extends State<MyMealDetailScreen> {
  String? uid;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<Map<String, dynamic>?> getMealData() async {
    if (uid == null) return null;

    final doc =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("myMeals")
            .doc(widget.id)
            .get();

    return doc.data();
  }

  Future<List<Map<String, dynamic>>> getMealFoods() async {
    if (uid == null) return [];

    final snapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("myMeals")
            .doc(widget.id)
            .collection("foods")
            .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Meal Details"),
        actions: [
          TextButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;

              await FirebaseFirestore.instance
                  .collection("users")
                  .doc(user!.uid)
                  .collection("myMeals")
                  .doc(widget.id)
                  .delete();
              if (!mounted) return;
              NavigationUtils.pop(context);
              if (!mounted) return;
              ValidationUtils.snackBar(context, "Meal has been deleted.");
            },
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
      body:
          uid == null
              ? const Center(child: Text("User not logged in."))
              : FutureBuilder(
                future: Future.wait([getMealData(), getMealFoods()]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: WalkAnimation());
                  }

                  if (!snapshot.hasData || snapshot.data == null) {
                    return const Center(child: Text("Meal not found."));
                  }

                  final mealData = snapshot.data![0] as Map<String, dynamic>?;
                  final foods = snapshot.data![1] as List<Map<String, dynamic>>;

                  if (mealData == null) {
                    return const Center(child: Text("Meal not found."));
                  }

                  return Padding(
                    padding: const EdgeInsets.all(AppSizes.padding16),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 🔹 Meal Name
                          Text(
                            mealData['mealName'] ?? 'Unnamed Meal',
                            style: TextStyles.title.copyWith(fontSize: 22),
                          ),
                          const Gap(AppSizes.gap10),

                          // 🔹 Macros Section
                          Row(
                            children: [
                              Expanded(
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      AppSizes.padding16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text("Total Calories"),
                                        Text(
                                          "${(mealData['totalCalories'] ?? 0).toStringAsFixed(1)} kcal",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      AppSizes.padding16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text("Total Protein"),
                                        Text(
                                          "${(mealData['totalProtein'] ?? 0).toStringAsFixed(1)} g",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      AppSizes.padding16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text("Total Carbs"),
                                        Text(
                                          "${(mealData['totalCarbs'] ?? 0).toStringAsFixed(1)} g",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      AppSizes.padding16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text("Total Fat"),
                                        Text(
                                          "${(mealData['totalFat'] ?? 0).toStringAsFixed(1)} g",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const Gap(AppSizes.gap20),

                          // 🔹 Instructions Section
                          if (mealData['instructions'] != null &&
                              (mealData['instructions'] as String).isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Instructions",
                                  style: TextStyles.body.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Gap(AppSizes.gap10),
                                Text(
                                  mealData['instructions'],
                                  style: const TextStyle(height: 1.5),
                                ),
                                const Gap(AppSizes.gap20),
                              ],
                            ),

                          // 🔹 Meal Items
                          Text(
                            "Meal Items",
                            style: TextStyles.body.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Gap(AppSizes.gap10),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: foods.length,
                            itemBuilder: (context, index) {
                              final food = foods[index];
                              return Card(
                                child: ListTile(
                                  title: Text(
                                    "${food['quantity']} grams ${food['foodName']}",
                                  ),
                                  subtitle: Text(
                                    "${(food['calories'] ?? 0).toStringAsFixed(1)} kcal | "
                                    "Protein: ${(food['protein'] ?? 0).toStringAsFixed(1)}g | "
                                    "Carbs: ${(food['carbs'] ?? 0).toStringAsFixed(1)}g | "
                                    "Fat: ${(food['fat'] ?? 0).toStringAsFixed(1)}g",
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
