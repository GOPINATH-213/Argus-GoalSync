import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'goal_providers.dart';
import '../../leaderboard/presentation/leaderboard_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/goal.dart';
import '../domain/goal_progress.dart';
import '../../../core/constants/app_colors.dart';

class GoalDetailScreen extends ConsumerWidget {
  final String goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsState = ref.watch(userGoalsProvider);
    final theme = Theme.of(context);

    return goalsState.when(
      data: (goals) {
        final goal = goals.firstWhere(
          (g) => g.id == goalId,
          orElse: () => Goal(
            id: '',
            userId: '',
            title: 'Not Found',
            category: '',
            targetValue: 0,
            unit: '',
            frequency: '',
            startDate: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        );

        if (goal.id.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Goal Not Found')),
            body: const Center(child: Text('This goal does not exist.')),
          );
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(goal.title),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_active),
                  onPressed: () => _changeReminderTime(context, ref, goal),
                  tooltip: 'Set/Change Reminder',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => _confirmDelete(context, ref, goal),
                  tooltip: 'Delete Goal',
                ),
              ],
              bottom: const TabBar(
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(icon: Icon(Icons.emoji_events), text: 'Leaderboard'),
                  Tab(icon: Icon(Icons.query_stats), text: 'Dashboard'),
                  Tab(icon: Icon(Icons.history), text: 'History'),
                ],
              ),
            ),
            body: Column(
              children: [
                // Top header card showing quick stats
                _buildGoalHeaderStats(context, ref, goal, theme),
                
                // Tab views
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Leaderboard
                      _buildLeaderboardTab(context, ref, goal, theme),
                      
                      // Tab 2: Dashboard
                      _buildDashboardTab(context, ref, goal, theme),
                      
                      // Tab 3: History
                      _buildHistoryTab(context, ref, goal, theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, st) => Scaffold(body: Center(child: Text("Error: $err"))),
    );
  }

  Widget _buildGoalHeaderStats(BuildContext context, WidgetRef ref, Goal goal, ThemeData theme) {
    final progressHistory = ref.watch(goalProgressProvider(goal.id)).value ?? [];
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final todayProgress = progressHistory.firstWhere(
      (p) => p.date.isAtSameMomentAs(today),
      orElse: () => GoalProgress(
        id: '',
        goalId: goal.id,
        userId: goal.userId,
        date: today,
        value: 0,
        isCompleted: false,
        updatedAt: DateTime.now(),
      ),
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${goal.frequency} Target',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${goal.targetValue.toStringAsFixed(0)} ${goal.unit}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Active Streak'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: AppColors.streakActive, size: 20),
                      Text(
                        '${goal.currentStreak} Days',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.streakActive,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Progress: ${todayProgress.value.toStringAsFixed(1)} ${goal.unit}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                icon: Icon(todayProgress.isCompleted ? Icons.check : Icons.add, size: 16),
                label: Text(todayProgress.isCompleted ? 'Completed' : 'Log'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: todayProgress.isCompleted ? AppColors.success : theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: todayProgress.isCompleted ? null : () => _showLogDialog(context, ref, goal, todayProgress),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab(BuildContext context, WidgetRef ref, Goal goal, ThemeData theme) {
    final leaderboardState = ref.watch(goalLeaderboardProvider(goal.id));

    return leaderboardState.when(
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(child: Text("Waiting for competitors..."));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final isSelf = entry.userId == ref.read(currentUserProvider).value?.uid;
            
            // Medals or Rank Icon
            Widget rankIcon;
            if (index == 0) {
              rankIcon = const Icon(Icons.workspace_premium, color: AppColors.streakGold);
            } else if (index == 1) {
              rankIcon = const Icon(Icons.workspace_premium, color: Color(0xFFC0C0C0)); // Silver
            } else if (index == 2) {
              rankIcon = const Icon(Icons.workspace_premium, color: Color(0xFFCD7F32)); // Bronze
            } else {
              rankIcon = Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold));
            }

            // Today Status Badge
            Color statusColor;
            IconData statusIcon;
            switch (entry.todayStatus) {
              case 'Completed':
                statusColor = AppColors.success;
                statusIcon = Icons.check_circle;
                break;
              case 'Pending':
                statusColor = AppColors.pending;
                statusIcon = Icons.timelapse;
                break;
              default:
                statusColor = AppColors.danger;
                statusIcon = Icons.cancel_outlined;
            }

            return Card(
              color: isSelf ? theme.colorScheme.primaryContainer.withAlpha(50) : null,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelf ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                  width: isSelf ? 1.5 : 0.8,
                ),
              ),
              child: ListTile(
                leading: SizedBox(
                  width: 50,
                  child: Row(
                    children: [
                      rankIcon,
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: isSelf ? theme.colorScheme.primary : theme.colorScheme.secondary,
                        backgroundImage: entry.photoUrl != null && entry.photoUrl!.isNotEmpty
                            ? (entry.photoUrl!.startsWith('http')
                                ? NetworkImage(entry.photoUrl!) as ImageProvider
                                : FileImage(File(entry.photoUrl!)) as ImageProvider)
                            : null,
                        child: entry.photoUrl == null || entry.photoUrl!.isEmpty
                            ? Text(
                                entry.displayName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
                title: Text(
                  entry.displayName,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${entry.currentValue.toStringAsFixed(1)} / ${entry.targetValue.toStringAsFixed(0)} ${entry.unit} | 🔥 ${entry.currentStreak}d',
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Tooltip(
                  message: entry.todayStatus,
                  child: Icon(statusIcon, color: statusColor),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text("Error: $err")),
    );
  }

  Widget _buildDashboardTab(BuildContext context, WidgetRef ref, Goal goal, ThemeData theme) {
    final leaderboardState = ref.watch(goalLeaderboardProvider(goal.id));
    final user = ref.read(currentUserProvider).value;

    return leaderboardState.when(
      data: (entries) {
        if (entries.isEmpty || user == null) {
          return const Center(child: Text("Dashboard requires competitors to sync."));
        }

        // Find user data
        final userEntry = entries.firstWhere(
          (e) => e.userId == user.uid,
          orElse: () => entries.first,
        );

        // Calculate competitor averages
        final competitors = entries.where((e) => e.userId != user.uid).toList();
        
        double avgCompletion = 0.0;
        double avgStreak = 0.0;
        double avgConsistency = 0.0;

        if (competitors.isNotEmpty) {
          final compSumCompletion = competitors.map((e) => e.completionPercentage).reduce((a, b) => a + b);
          final compSumStreak = competitors.map((e) => e.currentStreak).reduce((a, b) => a + b);
          final compSumConsistency = competitors.map((e) => e.consistencyRate).reduce((a, b) => a + b);
          
          avgCompletion = compSumCompletion / competitors.length;
          avgStreak = compSumStreak / competitors.length;
          avgConsistency = compSumConsistency / competitors.length;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Weekly Performance Chart',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('Comparing your completion rate against competitors\' averages', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 24),
              
              // fl_chart bar representation
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceEvenly,
                    maxY: 100,
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
                          reservedSize: 28,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            switch (value.toInt()) {
                              case 0:
                                return const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text('You'),
                                );
                              case 1:
                                return const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text('Cohort'),
                                );
                              default:
                                return const Text('');
                            }
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      BarChartGroupData(
                        x: 0,
                        barRods: [
                          BarChartRodData(
                            toY: userEntry.completionPercentage.clamp(0.0, 100.0),
                            color: theme.colorScheme.primary,
                            width: 32,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 1,
                        barRods: [
                          BarChartRodData(
                            toY: avgCompletion.clamp(0.0, 100.0),
                            color: theme.colorScheme.secondary,
                            width: 32,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Analytical Breakdown Cards
              Text(
                'Stats Comparison',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: _buildComparisonCard(
                      'Consistency',
                      '${(userEntry.consistencyRate * 100).round()}%',
                      '${(avgConsistency * 100).round()}%',
                      userEntry.consistencyRate >= avgConsistency,
                      theme,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildComparisonCard(
                      'Active Streak',
                      '${userEntry.currentStreak}d',
                      '${avgStreak.toStringAsFixed(1)}d',
                      userEntry.currentStreak >= avgStreak,
                      theme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.campaign, color: AppColors.pending),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          userEntry.completionPercentage >= avgCompletion
                              ? 'Keep it up! You are outperforming the group average today.'
                              : 'Catch up! Competitors are ahead in completion rates today.',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text("Error: $err")),
    );
  }

  Widget _buildComparisonCard(
    String metricName,
    String userVal,
    String compVal,
    bool isUserAhead,
    ThemeData theme,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(metricName, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('You', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      userVal,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isUserAhead ? AppColors.success : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Cohort', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      compVal,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab(BuildContext context, WidgetRef ref, Goal goal, ThemeData theme) {
    final progressState = ref.watch(goalProgressProvider(goal.id));

    return progressState.when(
      data: (history) {
        if (history.isEmpty) {
          return const Center(child: Text("No progress recorded yet. Log daily values to see history."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final log = history[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  log.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: log.isCompleted ? AppColors.success : theme.colorScheme.outline,
                ),
                title: Text(
                  '${log.value.toStringAsFixed(1)} / ${goal.targetValue.toStringAsFixed(0)} ${goal.unit}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Date: ${log.date.year}-${log.date.month}-${log.date.day}',
                ),
                trailing: Text(
                  log.isCompleted ? 'Completed' : 'Incomplete',
                  style: TextStyle(
                    color: log.isCompleted ? AppColors.success : AppColors.pending,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text("Error: $err")),
    );
  }

  void _showLogDialog(BuildContext context, WidgetRef ref, Goal goal, GoalProgress todayProg) {
    final controller = TextEditingController(text: (goal.targetValue - todayProg.value).clamp(0, goal.targetValue).toStringAsFixed(0));
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log progress for today'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How much ${goal.unit} did you complete?'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  suffixText: goal.unit,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(controller.text);
                if (val != null && val > 0) {
                  final remaining = goal.targetValue - todayProg.value;
                  if (val > remaining) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cannot log more than the remaining value (${remaining.toStringAsFixed(1)} ${goal.unit})'),
                        backgroundColor: AppColors.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  ref.read(goalControllerProvider.notifier).logProgress(goal.id, val);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Goal goal) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Goal'),
          content: Text('Are you sure you want to delete "${goal.title}"? This will delete all history and remove you from the smart competitor cohort.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
              onPressed: () {
                ref.read(goalControllerProvider.notifier).deleteGoal(goal.id);
                Navigator.pop(context); // Close dialog
                context.pop(); // Close detail screen
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changeReminderTime(BuildContext context, WidgetRef ref, Goal goal) async {
    final hasReminder = goal.reminderTime != null;
    TimeOfDay initialTime = const TimeOfDay(hour: 8, minute: 0);
    
    if (hasReminder) {
      final parts = goal.reminderTime!.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 8;
        final minute = int.tryParse(parts[1]) ?? 0;
        initialTime = TimeOfDay(hour: hour, minute: minute);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Goal Reminders'),
          content: Text(hasReminder 
              ? 'Currently scheduled daily at ${goal.reminderTime}.' 
              : 'Daily reminders are currently disabled for this goal.'),
          actions: [
            if (hasReminder)
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final updatedGoal = goal.copyWith(reminderTime: null);
                  await ref.read(goalControllerProvider.notifier).updateGoal(updatedGoal);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reminders disabled for this goal.'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text('Disable', style: TextStyle(color: AppColors.danger)),
              ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: initialTime,
                );
                if (picked != null) {
                  final timeStr = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                  final updatedGoal = goal.copyWith(reminderTime: timeStr);
                  await ref.read(goalControllerProvider.notifier).updateGoal(updatedGoal);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Reminder set daily at $timeStr.'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: Text(hasReminder ? 'Change Time' : 'Enable & Set Time'),
            ),
          ],
        );
      },
    );
  }
}
