import 'package:perfit/core/constants/colors.dart';
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

                  // Macro colors
                  final caloriesClr = Color.fromARGB(255, 221, 192, 255);
                  final proteinClr = Color.fromARGB(255, 69, 197, 136);
                  final carbsClr = Color.fromARGB(255, 120, 180, 245);
                  final fatClr = Color.fromARGB(255, 255, 111, 67);

                  return Padding(
                    padding: const EdgeInsets.all(AppSizes.padding16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Meal Name
                        Text(
                          mealData['mealName'] ?? 'Unnamed Meal',
                          style: TextStyles.title.copyWith(fontSize: 22),
                          textAlign: TextAlign.start,
                        ),
                        const Gap(AppSizes.gap15),

                        // Macro Cards
                        Row(
                          children: [
                            Expanded(
                              child: buildCard(
                                "Calories",
                                (mealData['totalCalories'] ?? 0).toDouble(),
                                caloriesClr,
                              ),
                            ),
                            Expanded(
                              child: buildCard(
                                "Protein",
                                (mealData['totalProtein'] ?? 0).toDouble(),
                                proteinClr,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: buildCard(
                                "Carbs",
                                (mealData['totalCarbs'] ?? 0).toDouble(),
                                carbsClr,
                              ),
                            ),
                            Expanded(
                              child: buildCard(
                                "Fat",
                                (mealData['totalFat'] ?? 0).toDouble(),
                                fatClr,
                              ),
                            ),
                          ],
                        ),
                        const Gap(AppSizes.gap15),

                        // Tabs
                        Expanded(
                          child: DefaultTabController(
                            length: 2,
                            child: Column(
                              children: [
                                const TabBar(
                                  labelColor: AppColors.primary,
                                  unselectedLabelColor: Colors.grey,
                                  tabs: [
                                    Tab(text: "Meal Items"),
                                    Tab(text: "Instructions"),
                                  ],
                                ),
                                Expanded(
                                  child: TabBarView(
                                    children: [
                                      // Meal Items Tab
                                      ListView.builder(
                                        padding: const EdgeInsets.all(8),
                                        itemCount: foods.length,
                                        itemBuilder: (context, index) {
                                          final food = foods[index];
                                          return Card(
                                            color: AppColors.surface,
                                            child: ListTile(
                                              title: Text(
                                                "${food['quantity']} grams ${food['foodName']}",
                                              ),
                                              subtitle: Text(
                                                "${(food['calories'] ?? 0).toStringAsFixed(2)} kcal | Protein: ${(food['protein'] ?? 0).toStringAsFixed(2)}g | Carbs: ${(food['carbs'] ?? 0).toStringAsFixed(2)}g | Fat: ${(food['fat'] ?? 0).toStringAsFixed(2)}g",
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                      // Instructions Tab
                                      SingleChildScrollView(
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: _buildInstructionSteps(
                                            mealData['instructions'] ?? "",
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }

  Widget buildCard(String title, double value, Color clr) {
    return Card(
      color: clr,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.padding16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(title), Text(value.toStringAsFixed(2))],
        ),
      ),
    );
  }

  List<Widget> _buildInstructionSteps(String instructions) {
    final stepList =
        instructions
            .split(RegExp(r'(\d+\.)|\n'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

    return List.generate(
      stepList.length,
      (index) => Card(
        color: AppColors.surface,
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary,
            child: Text(
              "${index + 1}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(stepList[index], style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
