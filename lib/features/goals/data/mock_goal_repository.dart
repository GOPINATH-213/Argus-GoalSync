import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/goal.dart';
import '../domain/goal_progress.dart';
import '../domain/goal_repository.dart';
import '../../../core/services/storage_service.dart';

class MockGoalRepository implements GoalRepository {
  final StorageService _storageService;
  
  // Cache of broadcast stream controllers by goalId/userId to ensure hot updates
  final _goalsStreamController = StreamController<List<Goal>>.broadcast();
  final Map<String, StreamController<List<GoalProgress>>> _progressStreamControllers = {};

  MockGoalRepository(this._storageService);

  String _dateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  @override
  Stream<List<Goal>> getGoals(String userId) {
    // Initial fetch and trigger stream
    _updateGoalsStream(userId);
    return _goalsStreamController.stream;
  }

  void _updateGoalsStream(String userId) {
    try {
      final box = _storageService.getBox(StorageService.boxGoals);
      final list = <Goal>[];
      for (var key in box.keys) {
        final map = Map<String, dynamic>.from(box.get(key) as Map);
        if (map['userId'] == userId) {
          list.add(Goal.fromMap(map));
        }
      }
      // Sort goals by creation date
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _goalsStreamController.add(list);
    } catch (e) {
      debugPrint("Error updating mock goals stream: $e");
    }
  }

  @override
  Future<Goal?> getGoalById(String goalId) async {
    final box = _storageService.getBox(StorageService.boxGoals);
    final map = box.get(goalId);
    if (map != null) {
      return Goal.fromMap(Map<String, dynamic>.from(map));
    }
    return null;
  }

  @override
  Future<void> createGoal(Goal goal) async {
    final box = _storageService.getBox(StorageService.boxGoals);
    await box.put(goal.id, goal.toMap());
    _updateGoalsStream(goal.userId);
  }

  @override
  Future<void> updateGoal(Goal goal) async {
    final box = _storageService.getBox(StorageService.boxGoals);
    await box.put(goal.id, goal.toMap());
    _updateGoalsStream(goal.userId);
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    final box = _storageService.getBox(StorageService.boxGoals);
    final goalMap = box.get(goalId);
    if (goalMap != null) {
      final userId = goalMap['userId'];
      await box.delete(goalId);
      
      // Clean up progress entries
      final progBox = _storageService.getBox(StorageService.boxProgress);
      final keysToDelete = <String>[];
      for (var key in progBox.keys) {
        if (key.toString().startsWith("${goalId}_")) {
          keysToDelete.add(key.toString());
        }
      }
      await progBox.deleteAll(keysToDelete);
      
      _updateGoalsStream(userId);
    }
  }

  @override
  Stream<List<GoalProgress>> getGoalProgressHistory(String goalId) {
    if (!_progressStreamControllers.containsKey(goalId)) {
      _progressStreamControllers[goalId] = StreamController<List<GoalProgress>>.broadcast();
    }
    _updateProgressStream(goalId);
    return _progressStreamControllers[goalId]!.stream;
  }

  void _updateProgressStream(String goalId) {
    try {
      final box = _storageService.getBox(StorageService.boxProgress);
      final list = <GoalProgress>[];
      for (var key in box.keys) {
        if (key.toString().startsWith("${goalId}_")) {
          final map = Map<String, dynamic>.from(box.get(key) as Map);
          list.add(GoalProgress.fromMap(map));
        }
      }
      // Sort progress by date
      list.sort((a, b) => b.date.compareTo(a.date));
      if (_progressStreamControllers.containsKey(goalId)) {
        _progressStreamControllers[goalId]!.add(list);
      }
    } catch (e) {
      debugPrint("Error updating mock progress stream: $e");
    }
  }

  @override
  Future<GoalProgress?> getGoalProgressForDate(String goalId, DateTime date) async {
    final box = _storageService.getBox(StorageService.boxProgress);
    final key = "${goalId}_${_dateKey(date)}";
    final map = box.get(key);
    if (map != null) {
      return GoalProgress.fromMap(Map<String, dynamic>.from(map));
    }
    return null;
  }

  @override
  Future<void> updateGoalProgress(GoalProgress progress) async {
    final box = _storageService.getBox(StorageService.boxProgress);
    final key = "${progress.goalId}_${_dateKey(progress.date)}";
    await box.put(key, progress.toMap());
    
    // Update goal streak calculations on complete
    final goal = await getGoalById(progress.goalId);
    if (goal != null) {
      // Re-evaluate current streak and longest streak based on progress history
      final progressList = <GoalProgress>[];
      for (var k in box.keys) {
        if (k.toString().startsWith("${progress.goalId}_")) {
          progressList.add(GoalProgress.fromMap(Map<String, dynamic>.from(box.get(k) as Map)));
        }
      }
      
      // Calculate streaks
      final streaks = _calculateStreaks(progressList);
      final updatedGoal = goal.copyWith(
        currentStreak: streaks.current,
        longestStreak: streaks.longest,
        lastCompletedDate: progress.isCompleted && (goal.lastCompletedDate == null || progress.date.isAfter(goal.lastCompletedDate!)) 
            ? progress.date 
            : goal.lastCompletedDate,
      );
      
      final goalBox = _storageService.getBox(StorageService.boxGoals);
      await goalBox.put(goal.id, updatedGoal.toMap());
      _updateGoalsStream(goal.userId);
    }
    
    _updateProgressStream(progress.goalId);
  }

  _StreakResult _calculateStreaks(List<GoalProgress> history) {
    if (history.isEmpty) return _StreakResult(0, 0);

    // Filter to only completed dates and sort ascending
    final completedDates = history
        .where((p) => p.isCompleted)
        .map((p) => DateTime(p.date.year, p.date.month, p.date.day))
        .toSet()
        .toList();
    
    completedDates.sort();

    if (completedDates.isEmpty) return _StreakResult(0, 0);

    int maxStreak = 0;
    int currentStreak = 0;
    
    DateTime? prevDate;
    
    for (var date in completedDates) {
      if (prevDate == null) {
        currentStreak = 1;
      } else {
        final diff = date.difference(prevDate).inDays;
        if (diff == 1) {
          currentStreak++;
        } else if (diff > 1) {
          if (currentStreak > maxStreak) maxStreak = currentStreak;
          currentStreak = 1;
        }
      }
      prevDate = date;
    }
    if (currentStreak > maxStreak) maxStreak = currentStreak;

    // Check if the current streak is still active today or yesterday
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final lastCompleted = completedDates.last;
    final daysSinceLastComplete = today.difference(lastCompleted).inDays;
    
    int activeStreak = 0;
    if (daysSinceLastComplete <= 1) {
      activeStreak = currentStreak; // Streak active today or was active yesterday and today is still open
    } else {
      activeStreak = 0; // Streak broken
    }

    return _StreakResult(activeStreak, maxStreak);
  }
}

class _StreakResult {
  final int current;
  final int longest;
  _StreakResult(this.current, this.longest);
}
