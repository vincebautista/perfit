import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:perfit/widgets/walk_animation.dart';
import 'package:perfit/widgets/welcome_guest.dart';

class PlanInformationScreen extends StatefulWidget {
  const PlanInformationScreen({super.key, required this.planId});

  final String planId;

  @override
  State<PlanInformationScreen> createState() => _PlanInformationScreenState();
}

class _PlanInformationScreenState extends State<PlanInformationScreen> {
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  String? uid;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    uid = user?.uid;
  }

  void _prevMonth() {
    if (!mounted) return;
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
    if (!mounted) return;
    setState(() {
      if (selectedMonth == 12) {
        selectedMonth = 1;
        selectedYear += 1;
      } else {
        selectedMonth += 1;
      }
    });
  }

  // Combined Future to fetch all necessary data
  Future<Map<String, dynamic>> loadAllPlanData() async {
    if (uid == null) return {};

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    // Use the planId passed from the history screen
    final planDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('fitnessPlan')
            .doc(widget.planId)
            .get();

    final planData = planDoc.data() ?? {};
    planData['status'] = planData['status'] ?? 'cancelled';

    final logsSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('fitnessPlan')
            .doc(widget.planId)
            .collection('weightLogs')
            .get();

    return {'user': userData, 'plan': planData, 'logs': logsSnapshot.docs};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Plan Information")),
      body: FutureBuilder<Map<String, dynamic>>(
        future: loadAllPlanData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: WalkAnimation());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const WelcomeGuest();
          }

          final data = snapshot.data!;
          // final userData = data['user'];
          final planData = data['plan'];
          final logs = data['logs'] as List<QueryDocumentSnapshot>? ?? [];

          if (planData == null || planData.isEmpty) {
            return const Center(child: Text("No active fitness plan selected"));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildPlanStatus(planData),
                const SizedBox(height: 12),
                buildMonthSelector(),
                const SizedBox(height: 12),
                _buildMonthChart(context, logs, selectedMonth, selectedYear),
                const SizedBox(height: 12),
                buildAssessment(planData),
                const SizedBox(height: 12),
                buildIntake(planData),
                const SizedBox(height: 12),
                FutureBuilder<List<String>>(
                  future: getCompletedExercises(planData),
                  builder: (context, exercisesSnapshot) {
                    if (exercisesSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final completedExercises = exercisesSnapshot.data ?? [];

                    if (completedExercises.isEmpty) {
                      return const Text("No exercises completed yet.");
                    }

                    return Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Completed Exercises",
                              style: TextStyles.subtitle.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...completedExercises.map((e) => Text("• $e")),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --------------------- Widgets ---------------------

  Widget buildPlanStatus(Map<String, dynamic> planData) {
    final status = planData['status'] ?? 'cancelled';
    Color color =
        status == 'active'
            ? Colors.green
            : status == 'completed'
            ? Colors.blue
            : Colors.red;

    return Card(
      color: AppColors.grey,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Plan Status",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            buildPlanProgress(planData),
          ],
        ),
      ),
    );
  }

  Widget buildPlanProgress(Map<String, dynamic> planData) {
    final planDuration = planData['planDuration'] ?? 0;
    final currentDay = planData['currentDay'] ?? 0;
    final totalDays = planDuration * 7;

    double progress = totalDays > 0 ? (currentDay / totalDays) : 0;
    progress = progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 10,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade300,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "${(progress * 100).toStringAsFixed(1)}%",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "Day $currentDay of $totalDays",
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildMonthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
        Text(
          "${DateFormat.MMMM().format(DateTime(selectedYear, selectedMonth))} $selectedYear",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _nextMonth,
        ),
      ],
    );
  }

  Widget buildAssessment(Map<String, dynamic> planData) {
    final assessment = planData['initialAssessment'] ?? {};
    if (assessment.isEmpty) {
      return const Text(
        "Initial assessment not available.",
        style: TextStyle(fontSize: 16),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Initial Assessment",
              style: TextStyles.subtitle.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _info("Age", assessment["age"]),
            _info("Gender", assessment["gender"]),
            _info("Height", assessment["height"]),
            _info("Weight", assessment["weight"]),
            _info("Body Type", assessment["bodyType"]),
            _info("Fitness Goal", assessment["fitnessGoal"]),
            _info("Training Level", assessment["trainingLevel"]),
            _info("Activity Level", assessment["activityLevel"]),
            _info("Previous Experience", assessment["previousExperience"]),
            _info("Commitment", assessment["workoutCommitment"]),
            _info("Location", assessment["workoutLocation"]),
            _info("Target Weight", assessment["targetWeight"]),
          ],
        ),
      ),
    );
  }

  Widget buildIntake(Map<String, dynamic> planData) {
    final intake = planData['nutritionPlan'] ?? {};
    if (intake.isEmpty) return const SizedBox();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Required Daily Intake",
              style: TextStyles.subtitle.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _info("Calories", intake["calorieTarget"]),
            _info("Protein (g)", intake["protein"]),
            _info("Carbs (g)", intake["carb"]),
            _info("Fat (g)", intake["fat"]),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120, // fixed width for labels
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value?.toString() ?? "-",
              softWrap: true,
              textAlign: TextAlign.right,
              overflow:
                  TextOverflow.visible, // will wrap instead of overflowing
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthChart(
    BuildContext context,
    List<QueryDocumentSnapshot> logs,
    int month,
    int year,
  ) {
    final daysInMonth = DateTime(year, month + 1, 0).day;

    if (logs.isEmpty) {
      return SizedBox(
        width: double.infinity,
        height: 300,
        child: const Center(child: Text("No logs this month")),
      );
    }

    final Map<int, double> dayToKg = {};
    for (var doc in logs) {
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
                            reservedSize: 48,
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

  Future<List<String>> getCompletedExercises(
    Map<String, dynamic> planData,
  ) async {
    if (uid == null) return [];

    final currentDay = planData['currentDay'] ?? 0;
    print("Current Day: $currentDay");

    final workoutsSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('fitnessPlan')
            .doc(widget.planId)
            .collection('workouts')
            .get(); // fetch all days

    final List<String> exercisesList = [];
    final Set<String> exercisesSet = {};

    for (var doc in workoutsSnapshot.docs) {
      final day = int.tryParse(doc.id) ?? 0;
      if (day > currentDay) break;

      final exercises = doc['exercises'] as List<dynamic>? ?? [];
      for (var exercise in exercises) {
        final name = exercise['name']?.toString() ?? '';
        final status = exercise['status']?.toString().toLowerCase() ?? '';
        print(exercises);
        if (name.isNotEmpty &&
            status == 'completed' &&
            !exercisesSet.contains(name)) {
          exercisesSet.add(name);
          exercisesList.add(name);
        }
      }
    }

    print("Completed Exercises: $exercisesList");
    return exercisesList;
  }
}
