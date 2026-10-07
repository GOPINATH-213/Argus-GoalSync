import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'goal_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/domain/user_profile.dart';
import '../domain/goal.dart';
import '../domain/goal_progress.dart';
import '../../../core/services/providers.dart';
import '../../../core/constants/app_colors.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(currentUserProvider);
    final goalsState = ref.watch(userGoalsProvider);
    final theme = Theme.of(context);

    goalsState.whenData((goals) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkGoalCompletions(context, ref, goals);
      });
    });

    return Scaffold(
      body: SafeArea(
        child: userState.when(
          data: (user) {
            if (user == null) return const Center(child: Text("Loading profile..."));
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. User Header Details
                  _buildUserHeader(user, theme, ref),
                  const SizedBox(height: 20),

                  // 2. Goal completion dashboard summary card
                  goalsState.when(
                    data: (goals) => _buildSummaryCard(goals, theme, ref),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, st) => Text("Error: $err"),
                  ),
                  const SizedBox(height: 24),

                  // 3. Goal Listing Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Today\'s Goals',
                        style: theme.textTheme.titleMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: AppColors.primary),
                        onPressed: () => context.push('/create-goal'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 4. Goals list
                  Expanded(
                    child: goalsState.when(
                      data: (goals) {
                        if (goals.isEmpty) {
                          return _buildEmptyState(theme, context);
                        }
                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: goals.length,
                          itemBuilder: (context, index) {
                            final goal = goals[index];
                            return GoalItemCard(goal: goal, key: ValueKey(goal.id));
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, st) => Center(child: Text("Failed to load goals: $err")),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create-goal'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildUserHeader(UserProfile user, ThemeData theme, WidgetRef ref) {
            const nextLevelXp = 1000;
    final currentLevelXp = user.xp % 1000;
    final xpPercent = currentLevelXp / nextLevelXp;

    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 24,
          backgroundColor: theme.colorScheme.secondary,
          backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
              ? (user.photoUrl!.startsWith('http')
                  ? NetworkImage(user.photoUrl!) as ImageProvider
                  : FileImage(File(user.photoUrl!)) as ImageProvider)
              : null,
          child: user.photoUrl == null || user.photoUrl!.isEmpty
              ? Text(
                  user.displayName.substring(0, min(2, user.displayName.length)).toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                )
              : null,
        ),
        const SizedBox(width: 12),
        // Username and Level details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, ${user.displayName}',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.xpColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'LVL ${user.level}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: xpPercent,
                            minHeight: 6,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.xpColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$currentLevelXp/1000 XP',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(List<Goal> goals, ThemeData theme, WidgetRef ref) {
    if (goals.isEmpty) {
      return Container();
    }

    int completedCount = 0;
    int activeStreak = 0;

    for (var goal in goals) {
      final progressList = ref.watch(goalProgressProvider(goal.id)).value ?? [];
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final hasCompletedToday = progressList.any((p) => p.date.isAtSameMomentAs(today) && p.isCompleted);
      if (hasCompletedToday) {
        completedCount++;
      }
      if (goal.currentStreak > activeStreak) {
        activeStreak = goal.currentStreak;
      }
    }

    final double completionPercent = goals.isNotEmpty ? completedCount / goals.length : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(80),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          // Circular Progress Indicator
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: completionPercent,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withAlpha(60),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Text(
                '${(completionPercent * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Streak and summary numbers
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Sync',
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$completedCount of ${goals.length} goals completed today',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: AppColors.streakActive, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'Max Streak: $activeStreak days',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.track_changes, size: 72, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'No Goals Yet!',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a goal and get matched with competitors. Compete together to complete daily habits.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/create-goal'),
              child: const Text('Add Your First Goal'),
            ),
          ],
        ),
      ),
    );
  }

  void _checkGoalCompletions(BuildContext context, WidgetRef ref, List<Goal> goals) async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    for (var goal in goals) {
      if (goal.endDate != null && !goal.isCompletionPromptShown) {
        final goalEnd = DateTime(goal.endDate!.year, goal.endDate!.month, goal.endDate!.day);
        if (!today.isBefore(goalEnd)) {
          // Fetch progress history to check if successfully completed
          final goalRepo = ref.read(goalRepositoryProvider);
          final history = await goalRepo.getGoalProgressHistory(goal.id).first;
          final isCompleted = history.any((p) => p.isCompleted);

          if (isCompleted) {
            // Mark as shown first to prevent duplicate dialog triggers
            final updatedGoal = goal.copyWith(isCompletionPromptShown: true);
            await ref.read(goalControllerProvider.notifier).updateGoal(updatedGoal);

            if (context.mounted) {
              _showCompletionDialog(context, ref, updatedGoal);
            }
            break; // Show one dialog at a time to not overwhelm the user
          } else {
            // If not completed, we still mark it as shown so they aren't repeatedly prompted for failed goals
            final updatedGoal = goal.copyWith(isCompletionPromptShown: true);
            await ref.read(goalControllerProvider.notifier).updateGoal(updatedGoal);
          }
        }
      }
    }
  }

  void _showCompletionDialog(BuildContext context, WidgetRef ref, Goal goal) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Goal Completed!'),
          content: Text(
            'Congratulations! You have completed your goal "${goal.title}". Would you like to continue this goal?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close completion dialog
                _handleDeleteGoalData(context, ref, goal);
              },
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close completion dialog
                _selectNewEndDateForContinuedGoal(context, ref, goal);
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  void _handleDeleteGoalData(BuildContext context, WidgetRef ref, Goal goal) {
    ref.read(goalControllerProvider.notifier).deleteGoal(goal.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${goal.title}" marked as completed and data deleted.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _selectNewEndDateForContinuedGoal(BuildContext context, WidgetRef ref, Goal goal) async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final initialDate = today.add(
      goal.frequency == 'Weekly'
          ? const Duration(days: 7)
          : (goal.frequency == 'Monthly' ? const Duration(days: 30) : const Duration(days: 1)),
    );

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: DateTime(2030),
      selectableDayPredicate: (DateTime date) {
        if (date.isBefore(today)) return false;

        final cleanDate = DateTime(date.year, date.month, date.day);
        final cleanStart = DateTime(goal.startDate.year, goal.startDate.month, goal.startDate.day);
        final diffInDays = cleanDate.difference(cleanStart).inDays;

        if (goal.frequency == 'Weekly') {
          return diffInDays > 0 && diffInDays % 7 == 0;
        } else if (goal.frequency == 'Monthly') {
          return diffInDays > 0 && diffInDays % 30 == 0;
        }
        return true; // Daily
      },
    );

    if (picked != null) {
      final updatedGoal = goal.copyWith(
        endDate: picked,
        isCompletionPromptShown: false, // Reset so they are prompted again when they reach the new end date!
      );

      await ref.read(goalControllerProvider.notifier).updateGoal(updatedGoal);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${goal.title}" extended to ${picked.day}/${picked.month}/${picked.year % 100}!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  int min(int a, int b) => a < b ? a : b;
}

class GoalItemCard extends ConsumerWidget {
  final Goal goal;
  const GoalItemCard({super.key, required this.goal});

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fitness':
      case 'exercise':
      case 'run':
        return Icons.directions_run;
      case 'reading':
      case 'study':
      case 'learn':
        return Icons.menu_book;
      case 'hydration':
      case 'water':
        return Icons.local_drink;
      case 'health':
      case 'meditation':
        return Icons.spa;
      default:
        return Icons.track_changes;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressState = ref.watch(goalProgressProvider(goal.id));
    final theme = Theme.of(context);

    return progressState.when(
      data: (progressHistory) {
        final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        
        // Find today's progress log
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

        final completionRate = goal.targetValue > 0 ? todayProgress.value / goal.targetValue : 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => context.push('/goal-details/${goal.id}'),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getCategoryIcon(goal.category),
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                decoration: todayProgress.isCompleted ? TextDecoration.lineThrough : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Target: ${goal.targetValue.toStringAsFixed(0)} ${goal.unit} (${goal.frequency})',
                              style: theme.textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Checkmark Action
                      GestureDetector(
                        onTap: todayProgress.isCompleted
                            ? null
                            : () => _showQuickLogDialog(context, ref, goal, todayProgress),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: todayProgress.isCompleted 
                                ? AppColors.success 
                                : theme.colorScheme.surfaceContainerHighest,
                            border: Border.all(
                              color: todayProgress.isCompleted 
                                  ? AppColors.success 
                                  : theme.colorScheme.outlineVariant,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.check,
                            size: 20,
                            color: todayProgress.isCompleted ? Colors.white : Colors.transparent,
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Progress and Streak Indicator
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: minDouble(1.0, completionRate),
                                minHeight: 6,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  todayProgress.isCompleted ? AppColors.success : theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Progress: ${todayProgress.value.toStringAsFixed(1)} / ${goal.targetValue.toStringAsFixed(0)} ${goal.unit}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Streak Flame
                      Row(
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            color: goal.currentStreak > 0 ? AppColors.streakActive : theme.colorScheme.outlineVariant,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${goal.currentStreak}d',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: goal.currentStreak > 0 ? AppColors.streakActive : theme.colorScheme.outlineVariant,
                            ),
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
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, st) => Text("Error: $err"),
    );
  }

  void _showQuickLogDialog(BuildContext context, WidgetRef ref, Goal goal, GoalProgress todayProgress) {
    final remaining = goal.targetValue - todayProgress.value;
    final controller = TextEditingController(text: remaining.clamp(0.0, goal.targetValue).toStringAsFixed(0));
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Log Progress for "${goal.title}"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter completed value in ${goal.unit}:'),
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
                final value = double.tryParse(controller.text);
                if (value != null && value > 0) {
                  if (value > remaining) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cannot log more than the remaining value (${remaining.toStringAsFixed(1)} ${goal.unit})'),
                        backgroundColor: AppColors.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  ref.read(goalControllerProvider.notifier).logProgress(goal.id, value);
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

  double minDouble(double a, double b) => a < b ? a : b;
}
