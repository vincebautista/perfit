import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/services/gemini_api_service.dart';
import 'package:perfit/core/services/setting_service.dart';
import 'package:perfit/screens/completed_workout_screen.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:perfit/widgets/welcome_guest.dart';
import 'package:intl/intl.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ProgressTrackingScreen extends StatefulWidget {
  const ProgressTrackingScreen({super.key});

  @override
  State<ProgressTrackingScreen> createState() => _ProgressTrackingScreenState();
}

class _ProgressTrackingScreenState extends State<ProgressTrackingScreen> {
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  String? uid;

  Map<String, dynamic>? _cachedFitnessPlan;

  final geminiService = GeminiApiService();
  final SettingService _settingService = SettingService();

  bool isDarkMode = true;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    uid = user?.uid;
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final mode = await _settingService.loadThemeMode();
    if (!mounted) return;
    setState(() {
      isDarkMode = mode == ThemeMode.dark;
    });
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

  Future<void> generateProgressPdf({
    required Map<String, double> weightLogs,
    required String overviewText,
    required List<Map<String, dynamic>> completedWorkouts,
  }) async {
    final pdf = pw.Document();

    final pdfPrimary = PdfColor.fromInt(0xFFFF9000);
    final pdfSurface = PdfColor.fromInt(0xFF24262B);

    // LOAD LOGO
    final logo = pw.MemoryImage(
      (await rootBundle.load(
        'assets/images/perfit_logo.png',
      )).buffer.asUint8List(),
    );

    final profile = await fetchUserProfileAndAssessment();
    final fitnessPlan = await fetchActiveFitnessPlan();

    final nutrition = fitnessPlan['nutritionPlan'] ?? {};
    final currentDay = fitnessPlan['currentDay'] ?? 0;
    final planDuration = (fitnessPlan['planDuration'] ?? 1) * 7;
    final percentProgress = (currentDay / planDuration).clamp(0.0, 1.0);

    pw.Widget pageWrapper({required String title, required pw.Widget child}) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [child],
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header:
            (context) => pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Container(height: 40, child: pw.Image(logo)),
                      pw.Text(
                        "Progress Report",
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfSurface,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(height: 3, color: pdfPrimary),
                  pw.SizedBox(height: 18),
                ],
              ),
            ),
        footer:
            (context) => pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 24),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Perfit Generated Report",
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    "Page ${context.pageNumber}",
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
        build:
            (context) => [
              pageWrapper(
                title: "Fitness Plan",
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // --- BASIC INFO ---
                    pw.Container(
                      width: double.infinity,
                      padding: pw.EdgeInsets.all(14),
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(8),
                        color: PdfColors.grey200,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "Basic Information",
                            style: pw.TextStyle(
                              color: pdfSurface,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text("Name: ${profile['fullName']}"),
                          pw.Text("Age: ${profile['age']}"),
                          pw.Text("Gender: ${profile['gender']}"),
                          pw.Text("Height: ${profile['height']} cm"),
                          pw.Text("Weight: ${profile['weight']} kg"),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 18),

                    // --- FITNESS ASSESSMENT ---
                    pw.Container(
                      width: double.infinity,
                      padding: pw.EdgeInsets.all(14),
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(8),
                        color: PdfColors.grey200,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "Fitness Assessment",
                            style: pw.TextStyle(
                              color: pdfSurface,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text("Goal: ${profile['fitnessGoal']}"),
                          pw.Text("Body Type: ${profile['bodyType']}"),
                          pw.Text(
                            "Training Level: ${profile['trainingLevel']}",
                          ),
                          pw.Text(
                            "Activity Level: ${profile['activityLevel']}",
                          ),
                          pw.Text(
                            "Experience: ${profile['previousExperience']}",
                          ),
                          pw.Text(
                            "Workout Location: ${profile['workoutLocation']}",
                          ),
                          pw.Text(
                            "Commitment: ${profile['workoutCommitment']} days/week",
                          ),
                          pw.Text(
                            "Target Weight: ${profile['targetWeight']} kg",
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 18),

                    // --- MACRO TARGETS ---
                    pw.Container(
                      width: double.infinity,
                      padding: pw.EdgeInsets.all(14),
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(8),
                        color: PdfColors.grey200,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "Macro Targets",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: pdfSurface,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Bullet(
                            text:
                                "Calories: ${nutrition['calorieTarget'] ?? '—'}",
                          ),
                          pw.Bullet(
                            text: "Protein: ${nutrition['protein'] ?? '—'} g",
                          ),
                          pw.Bullet(
                            text: "Carbs: ${nutrition['carb'] ?? '—'} g",
                          ),
                          pw.Bullet(text: "Fat: ${nutrition['fat'] ?? '—'} g"),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 18),

                    // --- PROGRESS BAR ---
                    pw.Container(
                      padding: pw.EdgeInsets.all(14),
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(8),
                        color: PdfColors.grey200,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "Goal Progress",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: pdfSurface,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text("Day $currentDay of $planDuration days"),
                          pw.SizedBox(height: 12),
                          pw.Container(
                            decoration: pw.BoxDecoration(
                              borderRadius: pw.BorderRadius.circular(6),
                              border: pw.Border.all(
                                color: pdfSurface,
                                width: 1,
                              ),
                            ),
                            child: pw.Stack(
                              children: [
                                pw.Container(height: 14),
                                pw.Container(
                                  height: 14,
                                  width: (percentProgress * 400),
                                  decoration: pw.BoxDecoration(
                                    color: pdfPrimary,
                                    borderRadius: pw.BorderRadius.circular(6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // --- OVERVIEW TEXT ---
              pw.Text(formatGeminiExplanation(overviewText)),

              pw.SizedBox(height: 24),

              // --- WEIGHT LOGS ---
              pw.Header(level: 1, text: "Weight Logs"),
              pw.Table.fromTextArray(
                headers: ["Date", "Weight"],
                data:
                    weightLogs.entries
                        .map(
                          (e) => [formatWeightLogDate(e.key), "${e.value} kg"],
                        )
                        .toList(),
              ),

              pw.SizedBox(height: 24),

              // --- COMPLETED WORKOUTS ---
              pw.Header(level: 1, text: "Completed Workouts"),
              pw.Table.fromTextArray(
                headers: ["Day", "Workout", "Completed"],
                data:
                    completedWorkouts
                        .map(
                          (w) => [
                            w["day"],
                            w["split"],
                            formatCompletedDate(w["dateCompleted"]),
                          ],
                        )
                        .toList(),
              ),
            ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  String formatWeightLogDate(String raw) {
    final date = parseMDY(raw);
    return DateFormat("MMMM d, yyyy").format(date);
  }

  DateTime parseMDY(String date) {
    final parts = date.split("-");
    final month = int.parse(parts[0]);
    final day = int.parse(parts[1]);
    final year = int.parse(parts[2]);
    return DateTime(year, month, day);
  }

  String formatCompletedDate(String raw) {
    final date = parseWorkoutCompleted(raw);
    return DateFormat("MMM d, yyyy h:mm a").format(date);
  }

  DateTime parseWorkoutCompleted(String raw) {
    raw = cleanDateString(raw);

    // Pattern: "Nov 26, 2025 11:59 AM"
    final formatter = DateFormat("MMM d, yyyy h:mm a");
    return formatter.parse(raw);
  }

  String cleanDateString(String raw) {
    raw = raw.replaceAll("–", " "); // replace EN DASH with space
    raw = raw.replaceAll(RegExp(r'\s+'), ' '); // collapse multiple spaces
    return raw.trim();
  }

  Future<Map<String, dynamic>> fetchUserProfileAndAssessment() async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    // Full name available in user root
    final profile = {'fullName': userData['fullName'] ?? ''};

    // Load active fitness plan
    final activePlanId = userData['activeFitnessPlan'];
    if (activePlanId != null) {
      final planDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('fitnessPlan')
              .doc(activePlanId)
              .get();

      final planData = planDoc.data() ?? {};
      final assessment = planData['initialAssessment'] ?? {};

      profile.addAll({
        'age': assessment['age'],
        'gender': assessment['gender'],
        'height': assessment['height'],
        'weight': assessment['weight'],
        'bodyType': assessment['bodyType'],
        'fitnessGoal': assessment['fitnessGoal'],
        'trainingLevel': assessment['trainingLevel'],
        'activityLevel': assessment['activityLevel'],
        'previousExperience': assessment['previousExperience'],
        'workoutCommitment': assessment['workoutCommitment'],
        'workoutLocation': assessment['workoutLocation'],
        'targetWeight': assessment['targetWeight'],
      });
    }

    return profile;
  }

  Future<Map<String, dynamic>> fetchActiveFitnessPlan() async {
    if (_cachedFitnessPlan != null) return _cachedFitnessPlan!;
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final activeId = userDoc.data()?['activeFitnessPlan'];
    if (activeId == null) {
      _cachedFitnessPlan = {};
      return {};
    }
    final planDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('fitnessPlan')
            .doc(activeId)
            .get();
    final plan = planDoc.data() ?? {};

    _cachedFitnessPlan = {
      'name': plan['name'] ?? 'Active Plan',
      'nutritionPlan': plan['nutritionPlan'] ?? {},
      'currentDay': plan['currentDay'] ?? 0,
      'planDuration': plan['planDuration'] ?? 0,
    };
    return _cachedFitnessPlan!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Progress Tracking"),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              if (!mounted) return;
              QuickAlert.show(
                context: context,
                type: QuickAlertType.loading,
                title: 'Preparing PDF',
                text: 'Fetching your progress data...',
                barrierDismissible: false,
              );

              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;

                final userDoc =
                    await FirebaseFirestore.instance
                        .collection("users")
                        .doc(user.uid)
                        .get();

                final activeFitnessPlan = userDoc.data()?['activeFitnessPlan'];
                if (activeFitnessPlan == null) return;

                // Analyze progress to get weight logs & overview text
                final progressData = await analyzeFullProgress(
                  user.uid,
                  activeFitnessPlan,
                );
                final weightLogs = Map<String, double>.from(
                  progressData['allWeightLogs'] ?? {},
                );
                final overviewText = progressData['geminiExplanation'] ?? "";

                // Fetch completed workouts
                final workoutsSnapshot =
                    await FirebaseFirestore.instance
                        .collection("users")
                        .doc(user.uid)
                        .collection("fitnessPlan")
                        .doc(activeFitnessPlan)
                        .collection("workouts")
                        .get();

                final completedWorkouts =
                    workoutsSnapshot.docs
                        .where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final status = data['status'] as String?;
                          final split = data['split'] as String?;
                          return status == "completed" && split != "Rest Day";
                        })
                        .map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final dateCompleted =
                              data['dateCompleted'] != null
                                  ? (data['dateCompleted'] as Timestamp)
                                      .toDate()
                                  : null;
                          return {
                            'day': doc.id,
                            'split': data['split'] ?? "Workout",
                            'dateCompleted':
                                dateCompleted != null
                                    ? DateFormat(
                                      "MMM d, yyyy – h:mm a",
                                    ).format(dateCompleted)
                                    : "N/A",
                          };
                        })
                        .toList();

                await generateProgressPdf(
                  weightLogs: weightLogs,
                  overviewText: overviewText,
                  completedWorkouts: completedWorkouts,
                );
              } catch (e) {
                print("Error generating PDF: $e");
              } finally {
                if (!mounted) return;
                Navigator.of(
                  context,
                  rootNavigator: true,
                ).pop(); // close loading
              }
            },
            tooltip: 'Export PDF (All)',
          ),
        ],
      ),
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
                        FutureBuilder<Map<String, dynamic>>(
                          future: analyzeFullProgress(
                            user.uid,
                            activeFitnessPlan,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  "Failed to analyze progress: ${snapshot.error}",
                                  style: const TextStyle(color: Colors.red),
                                ),
                              );
                            }

                            if (!snapshot.hasData) {
                              return const SizedBox.shrink();
                            }

                            final geminiExplanation =
                                snapshot.data!['geminiExplanation'];

                            return Overview(
                              title: "Progress Overview",
                              text: formatGeminiExplanation(geminiExplanation),
                            );
                          },
                        ),
                        Gap(AppSizes.gap20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Weight Logs", style: TextStyles.body),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSizes.padding16,
                                vertical: AppSizes.padding16 - 8,
                              ),
                              child: GestureDetector(
                                onTap:
                                    () => _showAddLogDialog(
                                      user.uid,
                                      activeFitnessPlan,
                                    ),
                                child: Text(
                                  "Add Log",
                                  style: TextStyles.caption.copyWith(
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Gap(AppSizes.gap10),
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
                                      .orderBy(FieldPath.documentId)
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

                                        print(doc.id);

                                        return Card(
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor:
                                                  AppColors.primary,
                                              child: Text(
                                                dayNum.toString(),
                                                style: TextStyle(
                                                  color: AppColors.white,
                                                ),
                                              ),
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
              title: const Text(
                "Add Weight Log",
                style: TextStyle(color: AppColors.primary),
              ),
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
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            if (!mounted) return;
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              color:
                                  isDarkMode ? AppColors.white : AppColors.grey,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSizes.padding16,
                            vertical: AppSizes.padding16 - 8,
                          ),
                          child: GestureDetector(
                            onTap: () async {
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
                                if (!mounted) return;
                                Navigator.of(context).pop();
                              }
                            },
                            child: const Text(
                              "Save",
                              style: TextStyle(color: AppColors.white),
                            ),
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

  Future<Map<String, dynamic>> analyzeFullProgress(
    String userId,
    String activeFitnessPlan,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final userDoc =
        await FirebaseFirestore.instance.collection("users").doc(userId).get();

    final initialAssessment =
        userDoc.data()?['initialAssessment'] as Map<String, dynamic>? ?? {};

    final activityLevel = initialAssessment['activityLevel'] ?? "Unknown";
    final fitnessGoal = initialAssessment['fitnessGoal'] ?? "Unknown";
    final trainingLevel = initialAssessment['trainingLevel'] ?? "Beginner";
    final workoutCommitment = initialAssessment['workoutCommitment'] ?? "0";
    final workoutLocation = initialAssessment['workoutLocation'] ?? "home";
    final targetWeight = initialAssessment['targetWeight'] ?? "Unknown";
    final bodyType = initialAssessment['bodyType'] ?? "Unknown";

    // Fetch all weight logs
    final weightLogsSnapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(userId)
            .collection("fitnessPlan")
            .doc(activeFitnessPlan)
            .collection("weightLogs")
            .get();

    final Map<String, double> allWeightLogs = {};
    for (var doc in weightLogsSnapshot.docs) {
      final data = doc.data();
      if (data.containsKey('kg')) {
        allWeightLogs[doc.id] = (data['kg'] as num).toDouble();
      } else if (data.containsKey('weight')) {
        allWeightLogs[doc.id] = (data['weight'] as num).toDouble();
      }
    }

    // Fetch all workouts
    final workoutsSnapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(userId)
            .collection("fitnessPlan")
            .doc(activeFitnessPlan)
            .collection("workouts")
            .get();

    int totalCompletedWorkouts = 0;
    List<String> completedWorkoutsList = [];

    for (var doc in workoutsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String?;
      final split = data['split'] as String?;
      if (status == "completed" && split != "Rest Day") {
        totalCompletedWorkouts++;
        completedWorkoutsList.add("${doc.id} ($split)");
      }
    }

    // Check if we need to fetch new Gemini analysis
    final String todayString = getTodayDateString();
    final int? savedWeightCount = prefs.getInt('saved_total_weight_logs');
    final int? savedWorkoutCount = prefs.getInt(
      'saved_total_completed_workouts',
    );
    final String? savedExplanation = prefs.getString(
      'saved_full_progress_explanation',
    );

    if (savedWeightCount != allWeightLogs.length ||
        savedWorkoutCount != totalCompletedWorkouts ||
        savedExplanation == null) {
      final prompt = """
        You are a professional fitness coach. Analyze the user's overall progress based on all available data:

        - Initial Assessment:
          - Age: ${initialAssessment['age'] ?? 'Unknown'}
          - Gender: ${initialAssessment['gender'] ?? 'Unknown'}
          - Body Type: $bodyType
          - Fitness Goal: $fitnessGoal
          - Training Level: $trainingLevel
          - Workout Commitment: $workoutCommitment days/week
          - Workout Location: $workoutLocation
          - Target Weight: $targetWeight kg
          - Current Weight: ${allWeightLogs.isNotEmpty ? allWeightLogs.values.last.toStringAsFixed(1) : 'Unknown'} kg

        - Weight logs: ${allWeightLogs.isEmpty ? "No logs" : allWeightLogs.values.map((w) => w.toStringAsFixed(1)).join(", ")} kg
        - Completed workouts: $totalCompletedWorkouts (${completedWorkoutsList.join(", ")})  

        Provide your output **strictly in JSON** with:
        {
          "analyze": "1–2 sentence analysis summarizing trends in weight, workout consistency, and progress relative to the initial assessment.",
          "tip": "1–2 sentence practical improvement tip moving forward."
        }
        Keep it brief, motivational, and actionable.
      """;

      final summary = await geminiService.fetchFromGemini(prompt);

      // Save to preferences
      prefs.setInt('saved_total_weight_logs', allWeightLogs.length);
      prefs.setInt('saved_total_completed_workouts', totalCompletedWorkouts);
      prefs.setString(
        'saved_full_progress_explanation',
        summary ?? "No summary yet.",
      );

      return {
        "allWeightLogs": allWeightLogs,
        "totalCompletedWorkouts": totalCompletedWorkouts,
        "geminiExplanation": summary ?? "No summary yet.",
      };
    } else {
      return {
        "allWeightLogs": allWeightLogs,
        "totalCompletedWorkouts": totalCompletedWorkouts,
        "geminiExplanation": savedExplanation ?? "No summary yet.",
      };
    }
  }

  String getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Widget Overview({required String title, required String text}) {
    return Card(
      color: isDarkMode ? AppColors.grey : AppColors.lightgrey,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.padding16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyles.title),
            Gap(AppSizes.gap10),
            Text(text),
          ],
        ),
      ),
    );
  }

  String formatGeminiExplanation(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) {
      return "No explanation yet.";
    }

    String cleaned =
        rawJson.trim().replaceAll("```json", "").replaceAll("```", "").trim();

    if (cleaned.startsWith("json")) {
      cleaned = cleaned.substring(4).trim();
    }

    try {
      final parsed = jsonDecode(cleaned);
      if (parsed is Map) {
        final analyze = parsed["analyze"] ?? "";
        final tip = parsed["tip"] ?? "";

        String result = analyze + "\n\n" + tip;

        return result.isEmpty ? "No explanation yet." : result;
      }
    } catch (e) {
      print("Error formatting Gemini explanation: $e");
    }

    return "No explanation yet.";
  }
}
