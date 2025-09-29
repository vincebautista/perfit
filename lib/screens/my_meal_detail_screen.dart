import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/core/utils/validation_utils.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class MyMealDetailScreen extends StatefulWidget {
  final String id;

  const MyMealDetailScreen({super.key, required this.id});

  @override
  State<MyMealDetailScreen> createState() => _MyMealDetailScreenState();
}

class _MyMealDetailScreenState extends State<MyMealDetailScreen> {
  String? uid;
  final nameCtrl = TextEditingController();

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
        title: Text("Meal Details"),
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

              NavigationUtils.pop(context);

              ValidationUtils.snackBar(context, "Meal has been deleted.");
            },
            child: Text("Delete"),
          ),
        ],
      ),
      body:
          uid == null
              ? Center(child: Text("User not logged in."))
              : FutureBuilder(
                future: Future.wait([getMealData(), getMealFoods()]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data == null) {
                    return Center(child: Text("Meal not found."));
                  }

                  final mealData = snapshot.data![0] as Map<String, dynamic>?;
                  final foods = snapshot.data![1] as List<Map<String, dynamic>>;

                  if (mealData == null) {
                    return Center(child: Text("Meal not found."));
                  }

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          mealData['mealName'] ?? 'Unnamed Meal',
                          style: TextStyles.title,
                        ),
                        Gap(AppSizes.gap10),
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
                                      Text("Total Calories"),
                                      Text(
                                        "${mealData['totalCalories']?.toStringAsFixed(1) ?? '0'} kcal",
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
                                      Text("Total Protein"),
                                      Text(
                                        "${mealData['totalProtein']?.toStringAsFixed(1) ?? '0'} g",
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
                                      Text("Total Carbs"),
                                      Text(
                                        "${mealData['totalCarbs']?.toStringAsFixed(1) ?? '0'} g",
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
                                      Text("Total Fat"),
                                      Text(
                                        "${mealData['totalFat']?.toStringAsFixed(1) ?? '0'} g",
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Gap(AppSizes.gap10),
                        Text("Meal Items", style: TextStyles.body),
                        Expanded(
                          child: ListView.builder(
                            itemCount: foods.length,
                            itemBuilder: (context, index) {
                              final food = foods[index];
                              return Card(
                                child: ListTile(
                                  title: Text(
                                    "${food['quantity']} ${food['unit']} ${food['foodName']}",
                                  ),
                                  subtitle: Text(
                                    "${food['calories']?.toStringAsFixed(1) ?? '?'} kcal | "
                                    "Protein: ${food['protein']?.toStringAsFixed(1) ?? '?'}g | "
                                    "Carbs: ${food['carbs']?.toStringAsFixed(1) ?? '?'}g | "
                                    "Fat: ${food['fat']?.toStringAsFixed(1) ?? '?'}g",
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
