import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class MealAnalyticsScreen extends StatefulWidget {
  const MealAnalyticsScreen({super.key});

  @override
  State<MealAnalyticsScreen> createState() => _MealAnalyticsScreenState();
}

class _MealAnalyticsScreenState extends State<MealAnalyticsScreen> {
  String? uid;

  int index = 0;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    uid = user!.uid;

    today();
  }

  Future<Map<String, dynamic>> today() async {
    final totalsSnapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("nutritionLogs")
            .doc(getTodayDateString())
            .get();

    final breakfastSnapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("nutritionLogs")
            .doc(getTodayDateString())
            .collection("meals")
            .doc("breakfast")
            .get();

    final lunchSnapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("nutritionLogs")
            .doc(getTodayDateString())
            .collection("meals")
            .doc("lunch")
            .get();

    final dinnerSnapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("nutritionLogs")
            .doc(getTodayDateString())
            .collection("meals")
            .doc("dinner")
            .get();

    final snacksSnapshot =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("nutritionLogs")
            .doc(getTodayDateString())
            .collection("meals")
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Analytics"),
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

  String getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Widget Today() {
    return FutureBuilder(
      future: today(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final data = snapshot.data;

        if (data == null || data.isEmpty) {
          return Center(child: Text("No data found."));
        }

        final double todayTotalCalories = data["todayTotalCalories"];

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
              children: [
                AspectRatio(
                  aspectRatio: 1,
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
                                  color: Colors.purple,
                                  radius: 150,
                                ),
                                PieChartSectionData(
                                  value: lunchPercent,
                                  title: "${lunchPercent.toStringAsFixed(2)}%",
                                  color: Colors.green,
                                  radius: 150,
                                ),
                                PieChartSectionData(
                                  value: dinnerPercent,
                                  title: "${dinnerPercent.toStringAsFixed(2)}%",
                                  color: Colors.blue,
                                  radius: 150,
                                ),
                                PieChartSectionData(
                                  value: snacksPercent,
                                  title: "${snacksPercent.toStringAsFixed(2)}%",
                                  color: Colors.red,
                                  radius: 150,
                                ),
                              ],
                    ),
                  ),
                ),
                Gap(AppSizes.gap10),
                Card(
                  child: ListTile(
                    leading: Container(
                      height: 25,
                      width: 25,
                      color: Colors.purple,
                    ),
                    title: Text("Breakfast"),
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
                      color: Colors.green,
                    ),
                    title: Text("Lunch"),
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
                      color: Colors.blue,
                    ),
                    title: Text("Dinner"),
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
                      color: Colors.red,
                    ),
                    title: Text("Snacks"),
                    subtitle: Text(
                      "${snacksPercent.toStringAsFixed(2)}% (${(data["snacksTotalCalories"] as num).toDouble().toStringAsFixed(1)} kcal)",
                    ),
                  ),
                ),
                Gap(AppSizes.gap10),
                ListTile(
                  title: Text("Total Calories"),
                  trailing: Text(
                    "${(data["todayTotalCalories"] as num).toDouble().toStringAsFixed(1)} / ${(data["targetCalories"] as num).toDouble().toStringAsFixed(1)}",
                  ),
                ),
                ListTile(
                  title: Text("Total Protein"),
                  trailing: Text(
                    "${(data["todayTotalProtein"] as num).toDouble().toStringAsFixed(1)} / ${(data["targetProtein"] as num).toDouble().toStringAsFixed(1)}",
                  ),
                ),
                ListTile(
                  title: Text("Total Carbs"),
                  trailing: Text(
                    "${(data["todayTotalCarbs"] as num).toDouble().toStringAsFixed(1)} / ${(data["targetCarbs"] as num).toDouble().toStringAsFixed(1)}",
                  ),
                ),
                ListTile(
                  title: Text("Total Fat"),
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

  List<String> getPast7DaysDates() {
    DateTime today = DateTime.now();
    List<String> dates = [];

    for (int i = 6; i >= 0; i--) {
      DateTime date = today.subtract(Duration(days: i));
      String formattedDate =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      dates.add(formattedDate);
    }

    return dates;
  }

  Widget Past7Days() {
    final dates = getPast7DaysDates();

    return FutureBuilder<Map<String, double>>(
      future: fetchDailyCalories(dates),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final dailyData = snapshot.data!;
        final maxRaw = (dailyData.values.reduce((a, b) => a > b ? a : b)) + 50;
        final maxY = (maxRaw / 100).round() * 100;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.gap20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text("Past 7 Days"),
                      Gap(AppSizes.gap20),
                      SizedBox(
                        width: double.infinity,
                        height: 300,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
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
                                    interval: 5,
                                    getTitlesWidget: (value, meta) {
                                      int dayIndex = value.toInt();
                                      if (dayIndex >= 0 &&
                                          dayIndex < dates.length) {
                                        final date = DateTime.parse(
                                          dates[dayIndex],
                                        );
                                        return Text(
                                          '${date.month}/${date.day}',
                                          style: TextStyle(fontSize: 10),
                                        );
                                      }
                                      return Text('');
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
        );
      },
    );
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

  Widget LastMonth() {
    final dates = getLastMonthDates();

    return FutureBuilder<Map<String, double>>(
      future: fetchDailyCalories(dates),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final dailyData = snapshot.data!;
        final maxRaw = (dailyData.values.reduce((a, b) => a > b ? a : b)) + 50;
        final maxY = (maxRaw / 100).round() * 100;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.gap20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text("${getPreviousMonthName()} Calorie Trends"),
                      Gap(AppSizes.gap20),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: dates.length * 25,
                          height: 300,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
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
                                            style: TextStyle(fontSize: 10),
                                          );
                                        }
                                        return Text('');
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
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
