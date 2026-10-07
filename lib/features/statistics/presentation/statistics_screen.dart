import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../goals/presentation/goal_providers.dart';
import '../../../core/constants/app_colors.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsState = ref.watch(userGoalsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
      ),
      body: SafeArea(
        child: goalsState.when(
          data: (goals) {
            if (goals.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart_outlined, size: 72, color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 16),
                      const Text(
                        'No Data Available',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add goals and record daily progress to view performance analytics.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            // Calculations
            int totalActiveGoals = goals.length;
            int maxStreak = 0;
            int completedToday = 0;
            
            final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
            final categoryCounts = <String, int>{};
            
            // Weekly completion calculation
            final weeklyActivity = List.filled(7, 0);
            
            for (var goal in goals) {
              if (goal.longestStreak > maxStreak) maxStreak = goal.longestStreak;
              categoryCounts[goal.category] = (categoryCounts[goal.category] ?? 0) + 1;
              
              final history = ref.watch(goalProgressProvider(goal.id)).value ?? [];
              
              if (history.any((p) => p.date.isAtSameMomentAs(today) && p.isCompleted)) {
                completedToday++;
              }

              // Compute activity for past 7 days (index 0 is 6 days ago, index 6 is today)
              for (int i = 0; i < 7; i++) {
                final day = today.subtract(Duration(days: 6 - i));
                final isDoneOnDay = history.any((p) => p.date.isAtSameMomentAs(day) && p.isCompleted);
                if (isDoneOnDay) {
                  weeklyActivity[i]++;
                }
              }
            }

            final successRate = totalActiveGoals > 0 ? (completedToday / totalActiveGoals) * 100 : 0.0;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Grid of numeric cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          'Success Rate',
                          '${successRate.toStringAsFixed(0)}%',
                          'Today',
                          Icons.insights,
                          AppColors.primary,
                          theme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          'Max Streak',
                          '$maxStreak Days',
                          'All Time',
                          Icons.local_fire_department,
                          AppColors.streakActive,
                          theme,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. Bar Chart: Weekly Activity
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Weekly Completions',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 180,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: totalActiveGoals.toDouble() + 1,
                                barTouchData: BarTouchData(enabled: true),
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (double value, TitleMeta meta) {
                                        final weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                                        // Find what day index maps to this x-axis value
                                        int index = value.toInt();
                                        if (index >= 0 && index < 7) {
                                          final targetDate = today.subtract(Duration(days: 6 - index));
                                          final label = weekdayLabels[targetDate.weekday - 1];
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                          );
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                ),
                                barGroups: List.generate(7, (i) {
                                  return BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: weeklyActivity[i].toDouble(),
                                        color: AppColors.primary,
                                        width: 14,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Pie Chart: Categories Breakdown
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Category Focus',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              // Pie Chart
                              Expanded(
                                flex: 3,
                                child: SizedBox(
                                  height: 140,
                                  child: PieChart(
                                    PieChartData(
                                      sectionsSpace: 4,
                                      centerSpaceRadius: 30,
                                      sections: _buildPieChartSections(categoryCounts, theme),
                                    ),
                                  ),
                                ),
                              ),
                              // Legends
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: _buildCategoryLegends(categoryCounts, theme),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(child: Text("Error: $err")),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(Map<String, int> counts, ThemeData theme) {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.info,
      AppColors.success,
      AppColors.streakActive,
    ];

    int i = 0;
    return counts.entries.map((entry) {
      final color = colors[i % colors.length];
      i++;
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${entry.value}',
        color: color,
        radius: 40,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  List<Widget> _buildCategoryLegends(Map<String, int> counts, ThemeData theme) {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.info,
      AppColors.success,
      AppColors.streakActive,
    ];

    int i = 0;
    return counts.entries.map((entry) {
      final color = colors[i % colors.length];
      i++;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }).toList();
  }
}
