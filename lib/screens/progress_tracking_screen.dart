import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gap/gap.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/screens/completed_workout_screen.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:perfit/widgets/welcome_guest.dart';
import 'package:intl/intl.dart';

class ProgressTrackingScreen extends StatefulWidget {
  const ProgressTrackingScreen({super.key});

  @override
  State<ProgressTrackingScreen> createState() => _ProgressTrackingScreenState();
}

class _ProgressTrackingScreenState extends State<ProgressTrackingScreen> {
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  void _prevMonth() {
    setState(() {
      if (selectedMonth == 1) {
        selectedMonth = 12;
        selectedYear -= 1;
      } else {
        selectedMonth -= 1;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (selectedMonth == 12) {
        selectedMonth = 1;
        selectedYear += 1;
      } else {
        selectedMonth += 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Progress Tracking")),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            );
          }

          if (!authSnapshot.hasData) {
            return const WelcomeGuest();
          }

          final user = authSnapshot.data!;

          return FutureBuilder<DocumentSnapshot>(
            future:
                FirebaseFirestore.instance
                    .collection("users")
                    .doc(user.uid)
                    .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                  ),
                );
              }

              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                return const Center(child: Text("User data not found"));
              }

              final userData = userSnapshot.data!;
              final activeFitnessPlan = userData['activeFitnessPlan'];

              if (activeFitnessPlan == null) {
                return const Center(
                  child: Text("No active fitness plan selected"),
                );
              }

              return StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection("users")
                        .doc(user.uid)
                        .collection("fitnessPlan")
                        .doc(activeFitnessPlan)
                        .collection("weightLogs")
                        .snapshots(),
                builder: (context, logsSnapshot) {
                  if (logsSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).primaryColor,
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ===== Weight Logs =====
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Weight Logs", style: TextStyles.body),
                            TextButton(
                              onPressed:
                                  () => _showAddLogDialog(
                                    user.uid,
                                    activeFitnessPlan,
                                  ),
                              child: Text("Add Log", style: TextStyles.caption),
                            ),
                          ],
                        ),
                        Gap(AppSizes.gap10),
                        // ===== Month Selector =====
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _prevMonth,
                            ),
                            Text(
                              "${DateFormat.MMMM().format(DateTime(selectedYear, selectedMonth))} $selectedYear",
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _nextMonth,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        _buildMonthChart(
                          context,
                          logsSnapshot,
                          selectedMonth,
                          selectedYear,
                        ),

                        const SizedBox(height: 20),
                        Text("Completed Workouts", style: TextStyles.body),
                        Gap(AppSizes.gap10),
                        StreamBuilder<DocumentSnapshot>(
                          stream:
                              FirebaseFirestore.instance
                                  .collection("users")
                                  .doc(user.uid)
                                  .collection("fitnessPlan")
                                  .doc(activeFitnessPlan)
                                  .snapshots(),
                          builder: (context, planSnapshot) {
                            if (!planSnapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final planData =
                                planSnapshot.data!.data()
                                    as Map<String, dynamic>? ??
                                {};
                            final currentDay = planData["currentDay"] ?? 0;

                            return StreamBuilder<QuerySnapshot>(
                              stream:
                                  FirebaseFirestore.instance
                                      .collection("users")
                                      .doc(user.uid)
                                      .collection("fitnessPlan")
                                      .doc(activeFitnessPlan)
                                      .collection("workouts")
                                      .orderBy(
                                        FieldPath.documentId,
                                      )
                                      .snapshots(),
                              builder: (context, workoutSnapshot) {
                                if (!workoutSnapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                final workouts = workoutSnapshot.data!.docs;

                                final completed =
                                    workouts.where((doc) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final status = data["status"];
                                      final split = data["split"];
                                      return status == "completed" &&
                                          split != "Rest Day";
                                    }).toList();

                                final filtered =
                                    completed.where((doc) {
                                      final dayNum = int.tryParse(doc.id) ?? 0;
                                      return dayNum <= currentDay;
                                    }).toList();

                                filtered.sort((a, b) {
                                  final dayA = int.tryParse(a.id) ?? 0;
                                  final dayB = int.tryParse(b.id) ?? 0;
                                  return dayB.compareTo(dayA);
                                });
                                final limited = filtered.take(5).toList();

                                if (limited.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Text("No completed workouts yet"),
                                  );
                                }

                                return Column(
                                  children:
                                      limited.map((doc) {
                                        final data =
                                            doc.data() as Map<String, dynamic>;
                                        final dayNum =
                                            int.tryParse(doc.id) ?? 0;
                                        final split =
                                            data["split"] ?? "Workout";
                                        final dateCompleted =
                                            data["dateCompleted"] != null
                                                ? (data["dateCompleted"]
                                                        as Timestamp)
                                                    .toDate()
                                                : null;

                                        return Card(
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              child: Text(dayNum.toString()),
                                            ),
                                            title: Text("$split Day"),
                                            subtitle:
                                                dateCompleted != null
                                                    ? Text(
                                                      DateFormat(
                                                        "MMM d, yyyy – h:mm a",
                                                      ).format(dateCompleted),
                                                    )
                                                    : const Text(
                                                      "No completion date",
                                                    ),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (
                                                        _,
                                                      ) => CompletedWorkoutScreen(
                                                        userId: user.uid,
                                                        planId:
                                                            activeFitnessPlan,
                                                        workoutId: doc.id,
                                                        split: split,
                                                        dateCompleted:
                                                            dateCompleted,
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      }).toList(),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMonthChart(
    BuildContext context,
    AsyncSnapshot<QuerySnapshot> logsSnapshot,
    int month,
    int year,
  ) {
    final daysInMonth = DateTime(year, month + 1, 0).day;

    if (!logsSnapshot.hasData) {
      return SizedBox(
        width: double.infinity,
        height: 300,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final docs = logsSnapshot.data!.docs;

    final Map<int, double> dayToKg = {};
    for (var doc in docs) {
      final id = doc.id;
      final parts = id.split('-');
      if (parts.length != 3) continue;
      final m = int.tryParse(parts[0]);
      final d = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (m == null || d == null || y == null) continue;
      if (m == month && y == year) {
        final data = doc.data() as Map<String, dynamic>;
        double? kg;
        if (data.containsKey('kg')) {
          final raw = data['kg'];
          if (raw is num) kg = raw.toDouble();
        } else if (data.containsKey('weight')) {
          final raw = data['weight'];
          if (raw is num) kg = raw.toDouble();
        }
        if (kg != null) {
          dayToKg[d] = kg;
        }
      }
    }

    int maxY;
    double minY = 0;
    double maxWeight = 0;
    double minWeight = 0;

    if (dayToKg.isEmpty) {
      maxY = 100;
    } else {
      maxWeight = dayToKg.values.reduce((a, b) => a > b ? a : b);
      minWeight = dayToKg.values.reduce((a, b) => a < b ? a : b);
      maxY = ((maxWeight / 10).ceil()) * 10;
      if (maxY == 0) maxY = 10;
    }

    final spots =
        dayToKg.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList()
          ..sort((a, b) => a.x.compareTo(b.x));

    final perDayWidth = 36.0;
    final chartWidth = (daysInMonth * perDayWidth).clamp(
      MediaQuery.of(context).size.width,
      double.infinity,
    );

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: chartWidth,
                height: 300,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    top: 4,
                  ),
                  child: LineChart(
                    LineChartData(
                      minX: 1,
                      maxX: daysInMonth.toDouble(),
                      minY: minY.toDouble(),
                      maxY: maxY.toDouble(),
                      clipData: FlClipData.none(),
                      gridData: FlGridData(show: true, horizontalInterval: 10),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) {
                              final day = value.toInt();
                              if (day < 1 || day > daysInMonth)
                                return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  day.toString(),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 10,
                            reservedSize:
                                48, // 👈 more space for "100" or "110"
                            getTitlesWidget: (value, meta) {
                              if (value % 10 == 0) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 12),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Theme.of(context).primaryColor,
                          barWidth: 3,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (dayToKg.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text("Lightest: ${minWeight.toStringAsFixed(1)} kg"),
                  Text("Heaviest: ${maxWeight.toStringAsFixed(1)} kg"),
                ],
              )
            else
              const Text("No logs this month"),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddLogDialog(
    String userId,
    String activeFitnessPlan,
  ) async {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController weightController = TextEditingController();
    DateTime? selectedDate;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Weight Log"),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Weight"),
                    Gap(AppSizes.gap10),
                    TextFormField(
                      controller: weightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Enter your weight";
                        }
                        final num? val = num.tryParse(value);
                        if (val == null || val <= 0) {
                          return "Enter a valid number";
                        }
                        return null;
                      },
                    ),
                    Gap(AppSizes.gap10),
                    InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: DateTime(2000),
                          lastDate: now,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          selectedDate == null
                              ? "No date chosen"
                              : DateFormat("MMM d, yyyy").format(selectedDate!),
                        ),
                      ),
                    ),
                    Gap(AppSizes.gap10),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("Cancel"),
                        ),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate() &&
                                  selectedDate != null) {
                                final weight = double.parse(
                                  weightController.text,
                                );
                                final docId = DateFormat(
                                  "M-d-yyyy",
                                ).format(selectedDate!);

                                await FirebaseFirestore.instance
                                    .collection("users")
                                    .doc(userId)
                                    .collection("fitnessPlan")
                                    .doc(activeFitnessPlan)
                                    .collection("weightLogs")
                                    .doc(docId)
                                    .set({
                                      "kg": weight,
                                      "timestamp": FieldValue.serverTimestamp(),
                                    });

                                Navigator.of(context).pop();
                              }
                            },
                            child: const Text("Save"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
