import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/goal.dart';
import '../domain/goal_progress.dart';
import '../domain/goal_repository.dart';
import '../../../core/services/providers.dart';
import '../../auth/presentation/auth_providers.dart';

// Stream of goals for the current user
final userGoalsProvider = StreamProvider<List<Goal>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const Stream.empty();
  
  final goalRepo = ref.watch(goalRepositoryProvider);
  return goalRepo.getGoals(user.uid);
});

// Stream of progress history for a goal
final goalProgressProvider = StreamProvider.family<List<GoalProgress>, String>((ref, goalId) {
  final goalRepo = ref.watch(goalRepositoryProvider);
  return goalRepo.getGoalProgressHistory(goalId);
});

// Goal Actions controller
class GoalController extends StateNotifier<AsyncValue<void>> {
  final GoalRepository _goalRepository;
  final Ref _ref;

  GoalController(this._goalRepository, this._ref) : super(const AsyncValue.data(null));

  Future<void> createGoal({
    required String title,
    required String category,
    required double targetValue,
    required String unit,
    required String frequency,
    DateTime? endDate,
    String? reminderTime,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(currentUserProvider).value;
      if (user == null) throw Exception("User not logged in");

      final goalId = 'goal_${DateTime.now().millisecondsSinceEpoch}';
      final goal = Goal(
        id: goalId,
        userId: user.uid,
        title: title,
        category: category,
        targetValue: targetValue,
        unit: unit,
        frequency: frequency,
        startDate: DateTime.now(),
        endDate: endDate,
        createdAt: DateTime.now(),
        reminderTime: reminderTime,
      );

      await _goalRepository.createGoal(goal);

      // Automatically register the goal in the smart matching cohort
      final leaderboardRepo = _ref.read(leaderboardRepositoryProvider);
      await leaderboardRepo.joinCohortForGoal(
        user.uid,
        goalId,
        category: category,
        targetValue: targetValue,
        unit: unit,
        frequency: frequency,
        title: title,
      );

      // Schedule local daily reminder
      final notificationService = _ref.read(notificationServiceProvider);
      await notificationService.scheduleGoalReminders(goal);

      // Award CustomCreator if category is custom
      final standardCategories = ['fitness', 'hydration', 'study', 'health', 'reading', 'water', 'exercise', 'learn'];
      if (!standardCategories.contains(category.toLowerCase())) {
        await _ref.read(authControllerProvider.notifier).awardBadge('CustomCreator', _ref);
      }

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteGoal(String goalId) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(currentUserProvider).value;
      if (user == null) throw Exception("User not logged in");

      // Leave the smart cohort first
      final leaderboardRepo = _ref.read(leaderboardRepositoryProvider);
      await leaderboardRepo.leaveCohortForGoal(user.uid, goalId);

      // Cancel local scheduled reminders
      final notificationService = _ref.read(notificationServiceProvider);
      await notificationService.cancelScheduledNotificationsForGoal(goalId);

      // Delete the goal itself
      await _goalRepository.deleteGoal(goalId);
      
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateGoal(Goal goal) async {
    state = const AsyncValue.loading();
    try {
      await _goalRepository.updateGoal(goal);

      // Update local scheduled notifications
      final notificationService = _ref.read(notificationServiceProvider);
      await notificationService.cancelScheduledNotificationsForGoal(goal.id);
      await notificationService.scheduleGoalReminders(goal);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logProgress(String goalId, double loggedValue) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(currentUserProvider).value;
      if (user == null) throw Exception("User not logged in");

      final goal = await _goalRepository.getGoalById(goalId);
      if (goal == null) throw Exception("Goal not found");

      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      
      // Fetch existing progress today if any
      final existingProgress = await _goalRepository.getGoalProgressForDate(goalId, today);
      
      final previousCompleted = existingProgress?.isCompleted ?? false;
      final newValue = (existingProgress?.value ?? 0.0) + loggedValue;
      final isCompleted = newValue >= goal.targetValue;

      final progress = GoalProgress(
        id: existingProgress?.id ?? 'prog_${goalId}_${DateTime.now().millisecondsSinceEpoch}',
        goalId: goalId,
        userId: user.uid,
        date: today,
        value: newValue,
        isCompleted: isCompleted,
        updatedAt: DateTime.now(),
      );

      // Save to repository
      await _goalRepository.updateGoalProgress(progress);

      // Reload goal to get latest streak details (calculated by repository update)
      final updatedGoal = await _goalRepository.getGoalById(goalId);
      if (updatedGoal != null) {
        // Sync with leaderboard/cohort members
        final leaderboardRepo = _ref.read(leaderboardRepositoryProvider);
        
        // Calculate user consistency
        final goalsStream = _ref.read(userGoalsProvider).value ?? [];
        final totalDaysTracked = DateTime.now().difference(updatedGoal.startDate).inDays + 1;
        
        // Fetch historical completed count
        final history = await _goalRepository.getGoalProgressHistory(goalId).first;
        final completedDaysCount = history.where((p) => p.isCompleted).length;
        final consistency = completedDaysCount / (totalDaysTracked > 0 ? totalDaysTracked : 1);

        await leaderboardRepo.syncProgressWithCohort(
          user.uid,
          goalId,
          newValue,
          isCompleted,
          updatedGoal.currentStreak,
          completedDaysCount,
          consistency,
        );

        // Gamification Engine - XP & Badges awarding
        if (isCompleted && !previousCompleted) {
          // Earn +50 XP for daily completion!
          await _ref.read(authControllerProvider.notifier).addXp(50, _ref);

          // Check streak badges
          if (updatedGoal.currentStreak >= 7) {
            await _ref.read(authControllerProvider.notifier).awardBadge('StreakMaster', _ref);
          }
          if (updatedGoal.currentStreak >= 30) {
            await _ref.read(authControllerProvider.notifier).awardBadge('StreakLegend', _ref);
          }

          // Check early bird: completed before 9:00 AM
          if (DateTime.now().hour < 9) {
            await _ref.read(authControllerProvider.notifier).awardBadge('EarlyBird', _ref);
          }

          // Check consistency king (90% consistency with at least 5 completed days)
          if (consistency >= 0.90 && completedDaysCount >= 5) {
            await _ref.read(authControllerProvider.notifier).awardBadge('ConsistencyKing', _ref);
          }

          // Check Milestone badge: completed 20 goals total
          final allGoals = goalsStream;
          int totalMilestoneCount = 0;
          for (var g in allGoals) {
            final h = await _goalRepository.getGoalProgressHistory(g.id).first;
            totalMilestoneCount += h.where((p) => p.isCompleted).length;
          }
          if (totalMilestoneCount >= 20) {
            await _ref.read(authControllerProvider.notifier).awardBadge('MilestoneAchiever', _ref);
          }

          // Check NightOwl badge: completed between 9:00 PM and 11:59 PM (21:00 to 23:59)
          if (DateTime.now().hour >= 21) {
            await _ref.read(authControllerProvider.notifier).awardBadge('NightOwl', _ref);
          }

          // Check WeekendWarrior badge: completed on Sat or Sun
          final weekday = DateTime.now().weekday;
          if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
            await _ref.read(authControllerProvider.notifier).awardBadge('WeekendWarrior', _ref);
          }

          // Check CustomCreator badge: completed custom category goal
          final standardCategories = ['fitness', 'hydration', 'study', 'health', 'reading', 'water', 'exercise', 'learn'];
          if (!standardCategories.contains(updatedGoal.category.toLowerCase())) {
            await _ref.read(authControllerProvider.notifier).awardBadge('CustomCreator', _ref);
          }

          // Category count milestones
          if (updatedGoal.category.toLowerCase() == 'hydration' || updatedGoal.category.toLowerCase() == 'water') {
            if (completedDaysCount >= 5) {
              await _ref.read(authControllerProvider.notifier).awardBadge('HydrationHero', _ref);
            }
          }

          if (updatedGoal.category.toLowerCase() == 'fitness' || updatedGoal.category.toLowerCase() == 'exercise') {
            if (completedDaysCount >= 5) {
              await _ref.read(authControllerProvider.notifier).awardBadge('FitnessFanatic', _ref);
            }
          }

          if (updatedGoal.category.toLowerCase() == 'health' || updatedGoal.category.toLowerCase() == 'meditation') {
            if (completedDaysCount >= 5) {
              await _ref.read(authControllerProvider.notifier).awardBadge('MindfulnessGuru', _ref);
            }
          }

          if (updatedGoal.category.toLowerCase() == 'study' || updatedGoal.category.toLowerCase() == 'learn' || updatedGoal.category.toLowerCase() == 'reading') {
            if (completedDaysCount >= 5) {
              await _ref.read(authControllerProvider.notifier).awardBadge('SuperScholar', _ref);
            }
          }

          // Check HabitStarter badge: log progress on 3 different goals in a single day
          int goalsLoggedToday = 0;
          for (var g in allGoals) {
            final prog = await _goalRepository.getGoalProgressForDate(g.id, today);
            if (prog != null && prog.value > 0) {
              goalsLoggedToday++;
            }
          }
          if (goalsLoggedToday >= 3) {
            await _ref.read(authControllerProvider.notifier).awardBadge('HabitStarter', _ref);
          }

          // Check PerfectWeek badge: maintain a 7-day streak on 2 or more different goals
          int goalsWith7DayStreak = 0;
          for (var g in allGoals) {
            final checkGoal = g.id == updatedGoal.id ? updatedGoal : g;
            if (checkGoal.currentStreak >= 7) {
              goalsWith7DayStreak++;
            }
          }
          if (goalsWith7DayStreak >= 2) {
            await _ref.read(authControllerProvider.notifier).awardBadge('PerfectWeek', _ref);
          }
        } else if (!isCompleted && loggedValue > 0 && (existingProgress == null || existingProgress.value == 0)) {
          // First log of the day (partial progress): earn +10 XP
          await _ref.read(authControllerProvider.notifier).addXp(10, _ref);
        }
      }

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final goalControllerProvider = StateNotifierProvider<GoalController, AsyncValue<void>>((ref) {
  final goalRepo = ref.watch(goalRepositoryProvider);
  return GoalController(goalRepo, ref);
});
