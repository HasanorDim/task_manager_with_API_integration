import 'package:flutter/material.dart';
import 'package:task_manager/model/task.dart';
import '../utils/app_styles.dart';
import '../widgets/statistics_card.dart';

class StatisticsScreen extends StatelessWidget {
  final List<Task> tasks;
  final bool isDarkMode;

  const StatisticsScreen({
    super.key,
    required this.tasks,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((t) => t.completed).length;
    final pending = tasks.length - completed;
    final userCounts = <int, int>{};

    for (var task in tasks) {
      userCounts[task.userId] = (userCounts[task.userId] ?? 0) + 1;
    }

    return Scaffold(
      body: Container(
        decoration: isDarkMode
            ? AppStyles.darkGradientBackground
            : AppStyles.gradientBackground,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.darkBackground
                        : Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _buildQuickStats(completed, pending),
                        const SizedBox(height: 20),
                        StatisticsCard(tasks: tasks, isDarkMode: isDarkMode),
                        const SizedBox(height: 20),
                        UserActivityChart(tasks: tasks, isDarkMode: isDarkMode),
                        const SizedBox(height: 20),
                        _buildUserBreakdown(userCounts),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Text(
            'Statistics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(int completed, int pending) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Tasks',
            tasks.length.toString(),
            Icons.task_alt,
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Completed',
            completed.toString(),
            Icons.check_circle,
            AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Pending',
            pending.toString(),
            Icons.pending,
            AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.cardDecoration(isDarkMode),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.darkText : AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUserBreakdown(Map<int, int> userCounts) {
    final sortedUsers = userCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.cardDecoration(isDarkMode),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tasks by User',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.darkText : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...sortedUsers.map((entry) {
            final percentage = (entry.value / tasks.length * 100)
                .toStringAsFixed(0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'User ${entry.key}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? AppColors.darkText
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${entry.value} tasks ($percentage%)',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: entry.value / tasks.length,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
