import 'dart:convert';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:perfit/core/services/gemini_api_service.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:printing/printing.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MealAnalyticsScreen extends StatefulWidget {
  const MealAnalyticsScreen({super.key});

  @override
  State<MealAnalyticsScreen> createState() => _MealAnalyticsScreenState();
}

class _MealAnalyticsScreenState extends State<MealAnalyticsScreen> {
  String? uid;
  final geminiService = GeminiApiService();

  // Chart capture keys
  final GlobalKey todayChartKey = GlobalKey();
  final GlobalKey past7ChartKey = GlobalKey();
  final GlobalKey monthChartKey = GlobalKey();

  final pdfPrimary = PdfColor.fromInt(0xFFFF9000);
  final pdfSurface = PdfColor.fromInt(0xFF24262B);

  // Cached profile/plan
  Map<String, dynamic>? _cachedFitnessPlan;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    uid = user?.uid;
    // preload something if needed
    today();
  }

  List<String> getPast7DaysDates({bool excludeToday = false}) {
    DateTime today = DateTime.now();
    List<String> dates = [];

    int start = excludeToday ? 7 : 6;

    for (int i = start; i >= 0; i--) {
      DateTime date = today.subtract(Duration(days: i));
      String formattedDate =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      dates.add(formattedDate);
    }

    return dates;
  }

  Future<Map<String, dynamic>> _getPast7DaysWithGeminiCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final dates = getPast7DaysDates(excludeToday: true);
    final dailyCalories = await fetchDailyCalories(dates);

    double weeklyCalories = dailyCalories.values.fold(0.0, (a, b) => a + b);
    final int fetchedTotal = weeklyCalories.toInt();

    final String? savedDate = prefs.getString('saved_weekly_date');
    final int? savedTotal = prefs.getInt('saved_weekly_total_calories');
    final String? savedExplanation = prefs.getString(
      'saved_weekly_explanation',
    );

    final String todayString = getTodayDateString();

    if (savedDate != todayString ||
        savedTotal != fetchedTotal ||
        savedExplanation == null) {
      final prompt = """
      You are a professional nutrition coach. Analyze the user's nutrition pattern for the past 7 days (excluding today).

      Data:
      - Total Calories (7 days): ${weeklyCalories.toStringAsFixed(1)} kcal
      - Average Calories per Day: ${(weeklyCalories / 7).toStringAsFixed(1)} kcal/day

      Provide your output **strictly in JSON** with:
      {
        "analyze": "1–2 sentence analysis of the last 7 days.",
        "tip": "1–2 sentence practical improvement tip for next week."
      }
      Keep it brief and motivational.
    """;

      final summary = await geminiService.fetchFromGemini(prompt);

      prefs.setString('saved_weekly_date', todayString);
      prefs.setInt('saved_weekly_total_calories', fetchedTotal);
      prefs.setString('saved_weekly_explanation', summary ?? "No summary yet.");

      return {
        "dailyCalories": dailyCalories,
        "geminiExplanation": summary ?? "No summary yet.",
      };
    } else {
      return {
        "dailyCalories": dailyCalories,
        "geminiExplanation": savedExplanation ?? "No summary yet.",
      };
    }
  }

  Future<Map<String, double>> fetchDailyCalories(List<String> dateList) async {
    Map<String, double> dailyCalories = {};

    for (String date in dateList) {
      final snapshot =
          await FirebaseFirestore.instance
              .collection("users")
              .doc(uid)
              .collection("nutritionLogs")
              .doc(date)
              .get();

      if (snapshot.exists && snapshot.data()?["totalCalories"] != null) {
        dailyCalories[date] =
            (snapshot.data()?["totalCalories"] as num).toDouble();
      } else {
        dailyCalories[date] = 0.0;
      }
    }

    return dailyCalories;
  }

  Widget Past7Days() {
    final dates = getPast7DaysDates(excludeToday: true);

    return FutureBuilder<Map<String, dynamic>>(
      future: _getPast7DaysWithGeminiCheck(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final data = snapshot.data!;
        final dailyData = data["dailyCalories"] as Map<String, double>;
        final geminiExplanation =
            data["geminiExplanation"] ?? "No summary yet.";

        final maxRaw =
            (dailyData.values.isEmpty
                ? 0
                : dailyData.values.reduce((a, b) => a > b ? a : b)) +
            50;
        final maxY = (maxRaw / 100).round() * 100;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Overview(
                  title: "Past 7 Days Overview",
                  text: formatGeminiExplanation(geminiExplanation),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.gap20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Calorie Trends",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Gap(AppSizes.gap10),
                        SizedBox(
                          width: double.infinity,
                          height: 300,
                          child: RepaintBoundary(
                            key: past7ChartKey,
                            child: BarChart(
                              BarChartData(
                                maxY: maxY.toDouble(),
                                gridData: FlGridData(show: false),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 60,
                                    ),
                                  ),
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        int dayIndex = value.toInt();
                                        if (dayIndex >= 0 &&
                                            dayIndex < dates.length) {
                                          final date = DateTime.parse(
                                            dates[dayIndex],
                                          );
                                          return Text(
                                            '${date.month}/${date.day}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          );
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                ),
                                barGroups: List.generate(dates.length, (index) {
                                  final date = dates[index];
                                  final value = dailyData[date] ?? 0.0;
                                  return BarChartGroupData(
                                    x: index,
                                    barRods: [
                                      BarChartRodData(
                                        toY: value,
                                        color: AppColors.primary,
                                        width: 12,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> generateAnalyticsPdf(
    BuildContext context, {
    String period = 'all',
  }) async {
    try {
      final pdf = pw.Document();

      // BRAND COLORS
      final pdfPrimary = PdfColor.fromInt(0xFFFF9000);
      final pdfSurface = PdfColor.fromInt(0xFF24262B);

      // LOAD LOGO
      final logo = pw.MemoryImage(
        (await rootBundle.load(
          'assets/images/perfit_logo.png',
        )).buffer.asUint8List(),
      );

      // ---------------------------------------------------------
      // UNIVERSAL PAGE THEME
      // ---------------------------------------------------------
      pw.Widget pageWrapper({required String title, required pw.Widget child}) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Container(height: 40, child: pw.Image(logo)),
                  pw.Text(
                    title,
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

              // Main content wrapped in Flexible to handle long content
              pw.Flexible(child: child),

              // Footer
              pw.SizedBox(height: 12),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "Perfit Generated Report",
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ),
            ],
          ),
        );
      }

      // FETCH DATA (unchanged)
      final profile = await fetchUserProfileAndAssessment();
      final fitnessPlan = await fetchActiveFitnessPlan();

      Map<String, dynamic>? todayData;
      Map<String, dynamic>? past7Data;
      Map<String, dynamic>? lastMonthData;

      if (period == 'today' || period == 'all')
        todayData = await _getTodayWithGeminiCheck();
      if (period == 'weekly' || period == 'all')
        past7Data = await _getPast7DaysWithGeminiCheck();
      if (period == 'monthly' || period == 'all')
        lastMonthData = await _getLastMonthWithGeminiCheck();

      // =========================================================
      // FITNESS PLAN PAGE
      // =========================================================
      pdf.addPage(
        pw.Page(
          build: (_) {
            final nutrition = fitnessPlan['nutritionPlan'] ?? {};
            final currentDay = fitnessPlan['currentDay'];
            final planDuration = fitnessPlan['planDuration'] * 7;
            final percentProgress = (currentDay / planDuration).clamp(0.0, 1.0);

            return pageWrapper(
              title: 'Fitness Plan',
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
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
                        pw.Text("Training Level: ${profile['trainingLevel']}"),
                        pw.Text("Activity Level: ${profile['activityLevel']}"),
                        pw.Text("Experience: ${profile['previousExperience']}"),
                        pw.Text(
                          "Workout Location: ${profile['workoutLocation']}",
                        ),
                        pw.Text(
                          "Commitment: ${profile['workoutCommitment']} days/week",
                        ),
                        pw.Text("Target Weight: ${profile['targetWeight']} kg"),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 18),
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
                        pw.Bullet(text: "Carbs: ${nutrition['carb'] ?? '—'} g"),
                        pw.Bullet(text: "Fat: ${nutrition['fat'] ?? '—'} g"),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 18),
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
                            border: pw.Border.all(color: pdfSurface, width: 1),
                          ),
                          child: pw.Stack(
                            children: [
                              pw.Container(height: 14, width: double.infinity),
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
            );
          },
        ),
      );

      // =========================================================
      // TODAY PAGE
      // =========================================================
      if (todayData != null) {
        pdf.addPage(
          pw.Page(
            build:
                (_) => pageWrapper(
                  title: "Today's Summary",
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        formatGeminiExplanation(
                          todayData!['geminiExplanation'],
                        ),
                      ),
                      pw.SizedBox(height: 16),

                      pw.Text(
                        "Totals",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),

                      pw.SizedBox(height: 6),

                      pw.Table(
                        border: pw.TableBorder.all(
                          color: PdfColors.grey400,
                          width: 0.5,
                        ),
                        columnWidths: {
                          0: pw.FlexColumnWidth(2),
                          1: pw.FlexColumnWidth(1),
                        },
                        children: [
                          // Header row
                          pw.TableRow(
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey300,
                            ),
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(
                                  "Nutrient",
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(
                                  "Total",
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Data rows
                          pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text("Calories"),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(
                                  "${todayData['todayTotalCalories']}",
                                ),
                              ),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text("Protein (g)"),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(
                                  "${todayData['todayTotalProtein']}",
                                ),
                              ),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text("Carbs (g)"),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(
                                  "${todayData['todayTotalCarbs']}",
                                ),
                              ),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text("Fat (g)"),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text("${todayData['todayTotalFat']}"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          ),
        );
      }

      // =========================================================
      // WEEKLY PAGE
      // =========================================================
      if (past7Data != null) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (ctx) {
              final daily = Map<String, double>.from(
                past7Data!['dailyCalories'] ?? {},
              );

              // Decode Gemini explanation safely
              String weekAnalyze = '';
              try {
                final geminiJson = past7Data['geminiExplanation'];
                if (geminiJson is String) {
                  final decoded = jsonDecode(geminiJson);
                  weekAnalyze = decoded['analyze'] ?? geminiJson;
                } else if (geminiJson is Map) {
                  weekAnalyze = geminiJson['analyze'] ?? jsonEncode(geminiJson);
                } else {
                  weekAnalyze = geminiJson?.toString() ?? '';
                }
              } catch (e) {
                weekAnalyze = past7Data['geminiExplanation']?.toString() ?? '';
              }

              return pageWrapper(
                title: "Past 7 Days",
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(formatGeminiExplanation(weekAnalyze)),

                    pw.SizedBox(height: 12),
                    pw.Text('Daily breakdown:'),
                    pw.SizedBox(height: 6),
                    pw.Table(
                      border: pw.TableBorder.all(
                        color: PdfColors.grey400,
                        width: 0.5,
                      ),
                      defaultVerticalAlignment:
                          pw.TableCellVerticalAlignment.middle,
                      columnWidths: {
                        0: pw.FlexColumnWidth(2),
                        1: pw.FlexColumnWidth(1),
                      },
                      children: [
                        // Header row
                        pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey300,
                          ),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                "Date",
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                "Calories",
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Data rows with formatted dates
                        ...daily.entries.map((e) {
                          String formattedDate;
                          try {
                            final date = DateTime.parse(e.key);
                            formattedDate = DateFormat(
                              'MMMM d, yyyy',
                            ).format(date); // November 1, 2025
                          } catch (_) {
                            formattedDate = e.key; // fallback
                          }

                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(formattedDate),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(e.value.toStringAsFixed(2)),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }

      if (lastMonthData != null) {
        final daily = Map<String, double>.from(
          lastMonthData['dailyCalories'] ?? {},
        );

        final dailyList = daily.entries.toList();

        // Build styled rows
        final rows =
            dailyList.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              String formattedDate;

              try {
                final date = DateTime.parse(e.key);
                formattedDate = DateFormat('MMMM d, yyyy').format(date);
              } catch (_) {
                formattedDate = e.key;
              }

              return pw.Container(
                decoration: pw.BoxDecoration(
                  color: i % 2 == 0 ? PdfColors.grey100 : PdfColors.white,
                  border: pw.Border(
                    left: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                    right: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                    bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                  ),
                ),
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 8,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(formattedDate),
                    pw.Text(e.value.toStringAsFixed(2)),
                  ],
                ),
              );
            }).toList();

        // Decode Gemini explanation safely
        String monthAnalyze = '';
        try {
          final geminiJson = lastMonthData['geminiExplanation'];
          if (geminiJson is String) {
            final decoded = jsonDecode(geminiJson);
            monthAnalyze = decoded['analyze'] ?? geminiJson;
          } else if (geminiJson is Map) {
            monthAnalyze = geminiJson['analyze'] ?? jsonEncode(geminiJson);
          } else {
            monthAnalyze = geminiJson?.toString() ?? '';
          }
        } catch (e) {
          monthAnalyze = lastMonthData['geminiExplanation']?.toString() ?? '';
        }

        // --------- First page ---------
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (ctx) {
              return pageWrapper(
                title: "Last Month Summary",
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(formatGeminiExplanation(monthAnalyze)),
                    pw.SizedBox(height: 12),
                    pw.Text('Daily breakdown:'),
                    pw.SizedBox(height: 6),

                    // Header row
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey300,
                        border: pw.Border.all(
                          color: PdfColors.grey400,
                          width: 0.5,
                        ),
                      ),
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Date',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            'Calories',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                    ...rows.take(13), // first 13 rows
                    pw.SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        );

        // --------- Second page ---------
        if (rows.length > 13) {
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (ctx) {
                return pageWrapper(
                  title: "Last Month Sumary", // no title/analysis
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Header row
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey300,
                          border: pw.Border.all(
                            color: PdfColors.grey400,
                            width: 0.5,
                          ),
                        ),
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Date',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              'Calories',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      ...rows.skip(13), // remaining rows
                      pw.SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
          );
        }
      }

      // SAVE & PRINT
      final bytes = await pdf.save();
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes);
    } catch (e) {
      debugPrint('generateAnalyticsPdf error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to generate PDF')));
      }
    }
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

  Future<Uint8List?> _captureChart(GlobalKey key) async {
    try {
      await Future.delayed(Duration(milliseconds: 200)); // <<< force paint

      if (key.currentContext == null) return null;

      RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;

      if (boundary.debugNeedsPaint) {
        await Future.delayed(Duration(milliseconds: 200));
        return _captureChart(key);
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Chart capture failed: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Analytics"),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () async {
                // Show loading alert
                QuickAlert.show(
                  context: context,
                  type: QuickAlertType.loading,
                  title: 'Preparing PDF',
                  text: 'Fetching your analytics data...',
                  barrierDismissible: false, // prevents dismissal while loading
                );

                try {
                  await generateAnalyticsPdf(context, period: 'all');
                } finally {
                  // Close the loading alert
                  Navigator.of(context, rootNavigator: true).pop();
                }
              },
              tooltip: 'Export PDF (All)',
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            tabs: [
              Tab(text: "Today"),
              Tab(text: "Past 7 Days"),
              Tab(text: "Last Month"),
            ],
          ),
        ),
        body: TabBarView(children: [Today(), Past7Days(), LastMonth()]),
      ),
    );
  }

  Future<Map<String, dynamic>> _getTodayWithGeminiCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final todayData = await today();
    final todayString = getTodayDateString();

    final int fetchedCalories = todayData["todayTotalCalories"].toInt();
    final String? savedDate = prefs.getString('saved_today_date');
    String? savedJson = prefs.getString('saved_today_explanation');

    if (savedDate != todayString ||
        savedJson == null ||
        fetchedCalories != prefs.getInt('saved_today_calories')) {
      final prompt = """
        You are a professional nutrition coach. Analyze today's meal summary based on the following data:
        - Total Calories: ${todayData["todayTotalCalories"]} / ${todayData["targetCalories"]}
        - Protein: ${todayData["todayTotalProtein"]} / ${todayData["targetProtein"]}
        - Carbs: ${todayData["todayTotalCarbs"]} / ${todayData["targetCarbs"]}
        - Fat: ${todayData["todayTotalFat"]} / ${todayData["targetFat"]}

        Provide your output **strictly in JSON format**:
        {
          "analyze": "A short 1-2 sentence explanation of what’s happening with the user’s nutrition today.",
          "tip": "A short 1-2 improvement tip for tomorrow."
        }
        Keep it concise and motivational.
      """;

      final response = await geminiService.fetchFromGemini(prompt);

      print(response);

      prefs.setString('saved_today_date', todayString);
      prefs.setInt('saved_today_calories', fetchedCalories);
      prefs.setString(
        'saved_today_explanation',
        response ?? '{"analyze": "No analysis yet.", "tip": ""}',
      );

      savedJson = response ?? '{"analyze": "No analysis yet.", "tip": ""}';
    }

    todayData["geminiExplanation"] = savedJson;
    return todayData;
  }

  Future<Map<String, dynamic>> today() async {
    final totalsSnapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("nutritionLogs")
            .doc(getTodayDateString())
            .collection("foods")
            .doc("totals")
            .get();

    final breakfastSnapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("nutritionLogs")
            .doc(getTodayDateString())
            .collection("foods")
            .doc("breakfast")
            .get();

    final lunchSnapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("nutritionLogs")
            .doc(getTodayDateString())
            .collection("foods")
            .doc("lunch")
            .get();

    final dinnerSnapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("nutritionLogs")
            .doc(getTodayDateString())
            .collection("foods")
            .doc("dinner")
            .get();

    final snacksSnapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("nutritionLogs")
            .doc(getTodayDateString())
            .collection("foods")
            .doc("snacks")
            .get();

    final activeFitnessPlanSnapshot =
        await FirebaseFirestore.instance.collection("users").doc(uid).get();

    final activeFitnessPlan =
        activeFitnessPlanSnapshot.data()!["activeFitnessPlan"];

    final fitnessPlanSnapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("fitnessPlan")
            .doc(activeFitnessPlan)
            .get();

    final breakfast = breakfastSnapshot.data();
    final lunch = lunchSnapshot.data();
    final dinner = dinnerSnapshot.data();
    final snacks = snacksSnapshot.data();
    final total = totalsSnapshot.data();
    final nutritionPlan = fitnessPlanSnapshot.data()!["nutritionPlan"];

    double breakfastTotalCalories;
    double lunchTotalCalories;
    double dinnerTotalCalories;
    double snacksTotalCalories;
    double todayTotalCalories;
    double todayTotalProtein;
    double todayTotalCarbs;
    double todayTotalFat;
    double targetCalories;
    double targetProtein;
    double targetCarbs;
    double targetFat;

    if (breakfast == null || breakfast.isEmpty) {
      breakfastTotalCalories = 0;
    } else {
      breakfastTotalCalories = breakfast["totalCalories"];
    }

    if (lunch == null || lunch.isEmpty) {
      lunchTotalCalories = 0;
    } else {
      lunchTotalCalories = lunch["totalCalories"];
    }

    if (dinner == null || dinner.isEmpty) {
      dinnerTotalCalories = 0;
    } else {
      dinnerTotalCalories = dinner["totalCalories"];
    }

    if (snacks == null || snacks.isEmpty) {
      snacksTotalCalories = 0;
    } else {
      snacksTotalCalories = snacks["totalCalories"];
    }

    if (total == null || total.isEmpty) {
      todayTotalCalories = 0;
      todayTotalProtein = 0;
      todayTotalCarbs = 0;
      todayTotalFat = 0;
    } else {
      todayTotalCalories = total["totalCalories"];
      todayTotalProtein = total["totalProtein"];
      todayTotalCarbs = total["totalCarbs"];
      todayTotalFat = total["totalFat"];
    }

    if (nutritionPlan == null) {
      targetCalories = 0;
      targetProtein = 0;
      targetCarbs = 0;
      targetFat = 0;
    } else {
      targetCalories = (nutritionPlan["calorieTarget"] as num).toDouble();
      targetProtein = (nutritionPlan["protein"] as num).toDouble();
      targetCarbs = (nutritionPlan["carb"] as num).toDouble();
      targetFat = (nutritionPlan["fat"] as num).toDouble();
    }

    return {
      "breakfastTotalCalories": breakfastTotalCalories,
      "lunchTotalCalories": lunchTotalCalories,
      "dinnerTotalCalories": dinnerTotalCalories,
      "snacksTotalCalories": snacksTotalCalories,
      "todayTotalCalories": todayTotalCalories,
      "todayTotalProtein": todayTotalProtein,
      "todayTotalCarbs": todayTotalCarbs,
      "todayTotalFat": todayTotalFat,
      "targetCalories": targetCalories,
      "targetProtein": targetProtein,
      "targetCarbs": targetCarbs,
      "targetFat": targetFat,
    };
  }

  String getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
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

  Widget Today() {
    return FutureBuilder(
      future: _getTodayWithGeminiCheck(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final data = snapshot.data;

        if (data == null || data.isEmpty) {
          return const Center(child: Text("No data found."));
        }

        final double todayTotalCalories = data["todayTotalCalories"];
        final String geminiExplanation = data["geminiExplanation"] ?? "";

        final breakfastPercent =
            todayTotalCalories == 0
                ? 0
                : (data["breakfastTotalCalories"] / todayTotalCalories) * 100;
        final lunchPercent =
            todayTotalCalories == 0
                ? 0
                : (data["lunchTotalCalories"] / todayTotalCalories) * 100;
        final dinnerPercent =
            todayTotalCalories == 0
                ? 0
                : (data["dinnerTotalCalories"] / todayTotalCalories) * 100;
        final snacksPercent =
            todayTotalCalories == 0
                ? 0
                : (data["snacksTotalCalories"] / todayTotalCalories) * 100;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.padding20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Overview(
                  title: "Today's Overview",
                  text: formatGeminiExplanation(geminiExplanation),
                ),
                AspectRatio(
                  aspectRatio: 1,
                  child: RepaintBoundary(
                    key: todayChartKey,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 0,
                        sections:
                            data["todayTotalCalories"] == 0
                                ? [
                                  PieChartSectionData(
                                    value: 100,
                                    color: AppColors.grey,
                                    showTitle: false,
                                    radius: 100,
                                  ),
                                ]
                                : [
                                  PieChartSectionData(
                                    value: breakfastPercent,
                                    title:
                                        "${breakfastPercent.toStringAsFixed(2)}%",
                                    color: AppColors.primary,
                                    radius: 150,
                                  ),
                                  PieChartSectionData(
                                    value: lunchPercent,
                                    title:
                                        "${lunchPercent.toStringAsFixed(2)}%",
                                    color: AppColors.green,
                                    radius: 150,
                                  ),
                                  PieChartSectionData(
                                    value: dinnerPercent,
                                    title:
                                        "${dinnerPercent.toStringAsFixed(2)}%",
                                    color: AppColors.red,
                                    radius: 150,
                                  ),
                                  PieChartSectionData(
                                    value: snacksPercent,
                                    title:
                                        "${snacksPercent.toStringAsFixed(2)}%",
                                    color: AppColors.surfaceLight,
                                    radius: 150,
                                  ),
                                ],
                      ),
                    ),
                  ),
                ),
                const Gap(AppSizes.gap10),
                Card(
                  child: ListTile(
                    leading: Container(
                      height: 25,
                      width: 25,
                      color: AppColors.primary,
                    ),
                    title: const Text("Breakfast"),
                    subtitle: Text(
                      "${breakfastPercent.toStringAsFixed(2)}% (${(data["breakfastTotalCalories"] as num).toDouble().toStringAsFixed(1)} kcal)",
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: Container(
                      height: 25,
                      width: 25,
                      color: AppColors.green,
                    ),
                    title: const Text("Lunch"),
                    subtitle: Text(
                      "${lunchPercent.toStringAsFixed(2)}% (${(data["lunchTotalCalories"] as num).toDouble().toStringAsFixed(1)} kcal)",
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: Container(
                      height: 25,
                      width: 25,
                      color: AppColors.red,
                    ),
                    title: const Text("Dinner"),
                    subtitle: Text(
                      "${dinnerPercent.toStringAsFixed(2)}% (${(data["dinnerTotalCalories"] as num).toDouble().toStringAsFixed(1)} kcal)",
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: Container(
                      height: 25,
                      width: 25,
                      color: AppColors.surfaceLight,
                    ),
                    title: const Text("Snacks"),
                    subtitle: Text(
                      "${snacksPercent.toStringAsFixed(2)}% (${(data["snacksTotalCalories"] as num).toDouble().toStringAsFixed(1)} kcal)",
                    ),
                  ),
                ),
                const Gap(AppSizes.gap10),
                ListTile(
                  title: const Text("Total Calories"),
                  trailing: Text(
                    "${(data["todayTotalCalories"] as num).toDouble().toStringAsFixed(1)} / ${(data["targetCalories"] as num).toDouble().toStringAsFixed(1)}",
                  ),
                ),
                ListTile(
                  title: const Text("Total Protein"),
                  trailing: Text(
                    "${(data["todayTotalProtein"] as num).toDouble().toStringAsFixed(1)} / ${(data["targetProtein"] as num).toDouble().toStringAsFixed(1)}",
                  ),
                ),
                ListTile(
                  title: const Text("Total Carbs"),
                  trailing: Text(
                    "${(data["todayTotalCarbs"] as num).toDouble().toStringAsFixed(1)} / ${(data["targetCarbs"] as num).toDouble().toStringAsFixed(1)}",
                  ),
                ),
                ListTile(
                  title: const Text("Total Fat"),
                  trailing: Text(
                    "${(data["todayTotalFat"] as num).toDouble().toStringAsFixed(1)} / ${(data["targetFat"] as num).toDouble().toStringAsFixed(1)}",
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget LastMonth() {
    final dates = getLastMonthDates();

    return FutureBuilder<Map<String, dynamic>>(
      future: _getLastMonthWithGeminiCheck(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final data = snapshot.data!;
        final dailyData = data["dailyCalories"] as Map<String, double>;
        final geminiJson = data["geminiExplanation"] ?? "{}";

        String tips = "";
        try {
          final decoded =
              geminiJson is String ? jsonDecode(geminiJson) : geminiJson;
          if (decoded is Map && decoded.containsKey('tip')) {
            tips = decoded['tip'] ?? '';
          } else {
            tips = geminiJson.toString();
          }
        } catch (e) {
          tips = geminiJson.toString();
        }

        final maxRaw =
            (dailyData.values.isEmpty
                ? 0
                : dailyData.values.reduce((a, b) => a > b ? a : b)) +
            50;
        final maxY = (maxRaw / 100).round() * 100;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Overview(
                  title: "Last Month Overview",
                  text: formatGeminiExplanation(tips),
                ),
                const Gap(AppSizes.gap20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.gap20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${getPreviousMonthName()} Calorie Trends",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Gap(AppSizes.gap20),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: dates.length * 25,
                            height: 300,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: RepaintBoundary(
                                key: monthChartKey,
                                child: BarChart(
                                  BarChartData(
                                    maxY: maxY.toDouble(),
                                    gridData: FlGridData(show: false),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 60,
                                        ),
                                      ),
                                      rightTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      topTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          interval: 5,
                                          getTitlesWidget: (value, meta) {
                                            int dayIndex = value.toInt();
                                            if (dayIndex >= 0 &&
                                                dayIndex < dates.length) {
                                              final day =
                                                  DateTime.parse(
                                                    dates[dayIndex],
                                                  ).day;
                                              return Text(
                                                '$day',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                ),
                                              );
                                            }
                                            return const Text('');
                                          },
                                        ),
                                      ),
                                    ),
                                    barGroups: List.generate(dates.length, (
                                      index,
                                    ) {
                                      final date = dates[index];
                                      final value = dailyData[date] ?? 0.0;
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: value,
                                            color: AppColors.primary,
                                            width: 12,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<String> getLastMonthDates() {
    DateTime now = DateTime.now();
    DateTime lastMonth = DateTime(now.year, now.month - 1, 1);
    DateTime nextMonth = DateTime(now.year, now.month, 1);

    int daysInLastMonth = nextMonth.difference(lastMonth).inDays;
    List<String> dates = [];

    for (int i = 0; i < daysInLastMonth; i++) {
      DateTime date = lastMonth.add(Duration(days: i));
      String formattedDate =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      dates.add(formattedDate);
    }

    return dates;
  }

  Future<Map<String, dynamic>> _getLastMonthWithGeminiCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final dates = getLastMonthDates();
    final dailyCalories = await fetchDailyCalories(dates);

    // optional: clear saved monthly data on each call (you had this in your code)
    await prefs.remove('saved_monthly_total_calories');
    await prefs.remove('saved_monthly_explanation');

    double monthlyCalories = dailyCalories.values.fold(0.0, (a, b) => a + b);
    double avgPerDay = monthlyCalories / (dates.isNotEmpty ? dates.length : 1);

    final int fetchedTotal = monthlyCalories.toInt();
    final int? savedTotal = prefs.getInt('saved_monthly_total_calories');
    String? savedJson = prefs.getString('saved_monthly_explanation');

    if (savedTotal == null || fetchedTotal != savedTotal) {
      final prompt = """
        You are a professional nutrition coach. Analyze the user's eating habits for the last month.

        Data:
        - Total Calories (last month): ${monthlyCalories.toStringAsFixed(1)} kcal
        - Average per day: ${avgPerDay.toStringAsFixed(1)} kcal/day

        Provide your output **strictly in JSON format** as follows:
        {
          "analyze": "Brief and concise (1-2 sentences) analyzation of the data provided.",
          "tip": "One short (1-2 sentences) and practical nutrition tip to improve next month"
        }
        Keep it short and motivational, suitable for app display.
      """;

      final response = await geminiService.fetchFromGemini(prompt);

      prefs.setInt('saved_monthly_total_calories', fetchedTotal);
      prefs.setString('saved_monthly_explanation', response ?? "{}");

      return {
        "dailyCalories": dailyCalories,
        "geminiExplanation": response ?? "{}",
      };
    } else {
      return {
        "dailyCalories": dailyCalories,
        "geminiExplanation": savedJson ?? "{}",
      };
    }
  }

  String getPreviousMonthName() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    return months[lastMonth.month - 1];
  }

  Widget Overview({required String title, required String text}) {
    return Card(
      color: AppColors.surface,
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
}
