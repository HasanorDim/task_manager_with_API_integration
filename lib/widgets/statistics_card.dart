import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:task_manager/model/task.dart';
import '../utils/app_styles.dart';

class StatisticsCard extends StatelessWidget {
  final List<Task> tasks;
  final bool isDarkMode;

  const StatisticsCard({
    super.key,
    required this.tasks,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((t) => t.completed).length;
    final total = tasks.length;
    final percentage = total > 0
        ? (completed / total * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.cardDecoration(isDarkMode),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task Completion',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.darkText : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 60,
                sections: [
                  PieChartSectionData(
                    value: completed.toDouble(),
                    title: '$completed',
                    color: AppColors.success,
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: (total - completed).toDouble(),
                    title: '${total - completed}',
                    color: AppColors.warning,
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '$percentage% Complete',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UserActivityChart extends StatelessWidget {
  final List<Task> tasks;
  final bool isDarkMode;

  const UserActivityChart({
    super.key,
    required this.tasks,
    required this.isDarkMode,
  });

  Map<int, int> _getUserTaskCounts() {
    final Map<int, int> counts = {};
    for (var task in tasks) {
      counts[task.userId] = (counts[task.userId] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final userCounts = _getUserTaskCounts();
    final sortedEntries = userCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topUsers = sortedEntries.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.cardDecoration(isDarkMode),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Most Active Users',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.darkText : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY:
                    (topUsers.isNotEmpty
                        ? topUsers.first.value.toDouble()
                        : 10) +
                    2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < topUsers.length) {
                          return Text(
                            'User ${topUsers[value.toInt()].key}',
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: topUsers.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.value.toDouble(),
                        color: AppColors.primary,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
