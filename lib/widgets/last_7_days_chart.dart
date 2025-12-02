import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:perfit/core/constants/colors.dart';

class Last7DaysStackedChart extends StatelessWidget {
  final List<Map<String, dynamic>> last7Workouts;

  const Last7DaysStackedChart({super.key, required this.last7Workouts});

  @override
  Widget build(BuildContext context) {
    if (last7Workouts.isEmpty) return const SizedBox.shrink();

    // Find max total exercises for y-axis scaling
    int maxY = last7Workouts
        .map((w) => (w['completed'] + w['skipped'] + w['fallback']) as int)
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 150, // original 250, divide by 2
      child: BarChart(
        BarChartData(
          borderData: FlBorderData(show: false),
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY.toDouble() + 1, // keep original maxY
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  int index = value.toInt();
                  if (index >= 0 && index < last7Workouts.length) {
                    final day = last7Workouts[index]['day'];
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Day $day',
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          barGroups:
              last7Workouts.asMap().entries.map((entry) {
                int index = entry.key;
                final workout = entry.value;

                if (workout['type'] == 'Rest') {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        width: 40, // reduce width
                        toY: maxY.toDouble(),
                        color: AppColors.primary,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(40),
                        ),
                      ),
                    ],
                  );
                }

                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      width: 40, // reduce width
                      toY:
                          (workout['completed'] +
                                  workout['skipped'] +
                                  workout['fallback'])
                              .toDouble(),
                      rodStackItems: [
                        BarChartRodStackItem(
                          0,
                          workout['skipped'].toDouble(),
                          Colors.red,
                        ),
                        BarChartRodStackItem(
                          workout['skipped'].toDouble(),
                          (workout['skipped'] + workout['completed'])
                              .toDouble(),
                          Colors.green,
                        ),
                        BarChartRodStackItem(
                          (workout['skipped'] + workout['completed'])
                              .toDouble(),
                          (workout['skipped'] +
                                  workout['completed'] +
                                  workout['fallback'])
                              .toDouble(),
                          Colors.grey,
                        ),
                      ],
                      borderRadius: const BorderRadius.all(Radius.circular(40)),
                    ),
                  ],
                );
              }).toList(),
        ),
      ),
    );
  }
}
