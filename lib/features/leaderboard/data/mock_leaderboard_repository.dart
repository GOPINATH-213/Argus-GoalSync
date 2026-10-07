import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../domain/leaderboard_entry.dart';
import '../domain/leaderboard_repository.dart';
import '../../../core/services/storage_service.dart';
import '../../goals/domain/goal.dart';
import '../../goals/domain/goal_progress.dart';
import '../../auth/domain/user_profile.dart';

class MockLeaderboardRepository implements LeaderboardRepository {
  final StorageService _storageService;
  
  // Track streams per goalId
  final Map<String, StreamController<List<LeaderboardEntry>>> _streams = {};
  
  MockLeaderboardRepository(this._storageService);

  @override
  Stream<List<LeaderboardEntry>> getLeaderboardForGoal(String goalId) {
    if (!_streams.containsKey(goalId)) {
      _streams[goalId] = StreamController<List<LeaderboardEntry>>.broadcast();
    }
    _triggerLeaderboardUpdate(goalId);
    return _streams[goalId]!.stream;
  }

  void _triggerLeaderboardUpdate(String goalId) {
    try {
      final box = _storageService.getBox(StorageService.boxCohorts);
      final cohortKey = 'cohort_$goalId';
      
      // Fetch or generate competitors
      var cohortData = box.get(cohortKey);
      if (cohortData == null) {
        // Fallback: if we haven't joined yet, return empty or wait
        if (_streams.containsKey(goalId)) {
          _streams[goalId]!.add([]);
        }
        return;
      }

      final cohortMap = Map<String, dynamic>.from(cohortData);
      final competitors = List<Map<String, dynamic>>.from(cohortMap['competitors'] ?? []);
      
      // Get the user's details
      final userBox = _storageService.getBox(StorageService.boxUser);
      final currentUserMap = userBox.get('current_user');
      if (currentUserMap == null) return;
      final currentUserProfile = UserProfile.fromMap(Map<String, dynamic>.from(currentUserMap));
      
      // Get the goal details
      final goalBox = _storageService.getBox(StorageService.boxGoals);
      final goalMap = goalBox.get(goalId);
      if (goalMap == null) return;
      final goal = Goal.fromMap(Map<String, dynamic>.from(goalMap));
      
      // Get the user's progress for today
      final progressBox = _storageService.getBox(StorageService.boxProgress);
      final todayKey = "${goalId}_${_dateKey(DateTime.now())}";
      final todayProgressMap = progressBox.get(todayKey);
      
      double userCurrentValue = 0.0;
      bool userIsCompleted = false;
      
      if (todayProgressMap != null) {
        final progress = GoalProgress.fromMap(Map<String, dynamic>.from(todayProgressMap));
        userCurrentValue = progress.value;
        userIsCompleted = progress.isCompleted;
      }

      // Calculate user consistency (completed days/total days)
      double userConsistency = 0.0;
      int userCompletedDaysCount = 0;
      final totalDaysTracked = max(1, DateTime.now().difference(goal.startDate).inDays + 1);
      
      for (var key in progressBox.keys) {
        if (key.toString().startsWith("${goalId}_")) {
          final progress = GoalProgress.fromMap(Map<String, dynamic>.from(progressBox.get(key) as Map));
          if (progress.isCompleted) {
            userCompletedDaysCount++;
          }
        }
      }
      userConsistency = userCompletedDaysCount / totalDaysTracked;

      // Map competitors to LeaderboardEntries
      final entries = <LeaderboardEntry>[];
      
      // Add user entry
      final userCompletionPct = goal.targetValue > 0 ? (userCurrentValue / goal.targetValue) * 100 : 0.0;
      final userScore = _calculateScore(
        completionPercentage: userCompletionPct,
        streak: goal.currentStreak,
        totalCompletedDays: userCompletedDaysCount,
        consistencyRate: userConsistency,
      );

      entries.add(LeaderboardEntry(
        userId: currentUserProfile.uid,
        username: currentUserProfile.username,
        displayName: currentUserProfile.displayName,
        photoUrl: currentUserProfile.photoUrl,
        currentValue: userCurrentValue,
        targetValue: goal.targetValue,
        unit: goal.unit,
        completionPercentage: min(100.0, userCompletionPct),
        currentStreak: goal.currentStreak,
        totalCompletedDays: userCompletedDaysCount,
        consistencyRate: userConsistency,
        score: userScore,
        todayStatus: userIsCompleted 
            ? 'Completed' 
            : (userCurrentValue > 0 ? 'Pending' : 'Missed'),
      ));

      // Add competitor entries
      for (var comp in competitors) {
        // Dynamic daily simulation: Roll if competitor completes today based on their consistency
        var currentValue = (comp['currentValue'] as num).toDouble();
        var streak = comp['currentStreak'] as int;
        var totalCompleted = comp['totalCompletedDays'] as int;
        var consistency = (comp['consistencyRate'] as num).toDouble();
        var targetValue = (comp['targetValue'] as num).toDouble();
        var status = comp['todayStatus'] as String;

        // Simple simulation: if pending, roll chance to mark as complete today
        if (status == 'Pending' && Random().nextDouble() < 0.2) {
          status = 'Completed';
          currentValue = targetValue;
          streak += 1;
          totalCompleted += 1;
          
          // Save back simulation state so it persists
          comp['currentValue'] = currentValue;
          comp['currentStreak'] = streak;
          comp['totalCompletedDays'] = totalCompleted;
          comp['todayStatus'] = status;
        }

        final completionPct = targetValue > 0 ? (currentValue / targetValue) * 100 : 0.0;
        final score = _calculateScore(
          completionPercentage: completionPct,
          streak: streak,
          totalCompletedDays: totalCompleted,
          consistencyRate: consistency,
        );

        entries.add(LeaderboardEntry(
          userId: comp['userId'],
          username: comp['username'],
          displayName: comp['displayName'],
          photoUrl: comp['photoUrl'],
          currentValue: currentValue,
          targetValue: targetValue,
          unit: goal.unit,
          completionPercentage: min(100.0, completionPct),
          currentStreak: streak,
          totalCompletedDays: totalCompleted,
          consistencyRate: consistency,
          score: score,
          todayStatus: status,
        ));
      }

      // Save cohort state updates (for competitor simulation persistence)
      box.put(cohortKey, cohortMap);

      // Sort entries by score descending
      entries.sort((a, b) => b.score.compareTo(a.score));

      if (_streams.containsKey(goalId)) {
        _streams[goalId]!.add(entries);
      }
    } catch (e) {
      debugPrint("Error loading mock leaderboard: $e");
    }
  }

  double _calculateScore({
    required double completionPercentage,
    required int streak,
    required int totalCompletedDays,
    required double consistencyRate,
  }) {
    // Score = (Completion% * 0.5) + (Streak * 0.3) + (TotalCompletedDays * 0.2)
    // Adjust streak weight to normalized range or linear multiplier
    final streakPoints = streak * 10.0; // 10 points per streak day
    final completedDaysPoints = totalCompletedDays * 5.0; // 5 points per completed day
    return (completionPercentage * 0.5) + (streakPoints * 0.3) + (completedDaysPoints * 0.2) + (consistencyRate * 100 * 0.1);
  }

  String _dateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  @override
  Future<void> joinCohortForGoal(
    String userId, 
    String goalId, {
    required String category, 
    required double targetValue, 
    required String unit, 
    required String frequency,
    required String title,
  }) async {
    final box = _storageService.getBox(StorageService.boxCohorts);
    final cohortKey = 'cohort_$goalId';
    
    // Check if cohort already generated
    if (box.containsKey(cohortKey)) return;

    // Generate 4 mock competitors within range +/- 20%
    final random = Random();
    final names = [
      _CompetitorProfile('RunnerPro99', 'Alex Stride', 0.88),
      _CompetitorProfile('DailyStreak', 'Jamie Pace', 0.72),
      _CompetitorProfile('AgileAki', 'Akira Sato', 0.82),
      _CompetitorProfile('MindfulStep', 'Elena Vance', 0.60),
    ];

    final competitorsList = <Map<String, dynamic>>[];
    for (var profile in names) {
      // Calculate target variation (+/- 20%)
      final variationFactor = 0.8 + (random.nextDouble() * 0.4); // 0.8 to 1.2
      final competitorTarget = (targetValue * variationFactor);
      
      // Clean target rounding
      final roundedTarget = double.parse(competitorTarget.toStringAsFixed(1));
      
      // Simulate historical completion counts (over e.g. 14 days)
      const totalSimulatedDays = 14;
      final completedSimulatedDays = (totalSimulatedDays * profile.baseConsistency).round();
      final streak = (completedSimulatedDays / 2).round(); // Approximate streak
      
      // Today status simulation
      final completedToday = random.nextDouble() < profile.baseConsistency;
      final status = completedToday ? 'Completed' : (random.nextBool() ? 'Pending' : 'Missed');
      final currentValue = status == 'Completed' 
          ? roundedTarget 
          : (status == 'Pending' ? (roundedTarget * 0.5) : 0.0);

      competitorsList.add({
        'userId': 'mock_competitor_${profile.username}',
        'username': profile.username,
        'displayName': profile.displayName,
        'photoUrl': null,
        'currentValue': currentValue,
        'targetValue': roundedTarget,
        'currentStreak': streak,
        'totalCompletedDays': completedSimulatedDays,
        'consistencyRate': profile.baseConsistency,
        'todayStatus': status,
      });
    }

    final cohortMap = {
      'goalId': goalId,
      'title': title,
      'category': category,
      'frequency': frequency,
      'competitors': competitorsList,
      'createdAt': DateTime.now().toIso8601String(),
    };

    await box.put(cohortKey, cohortMap);
    _triggerLeaderboardUpdate(goalId);
  }

  @override
  Future<void> leaveCohortForGoal(String userId, String goalId) async {
    final box = _storageService.getBox(StorageService.boxCohorts);
    final cohortKey = 'cohort_$goalId';
    await box.delete(cohortKey);
    _streams.remove(goalId);
  }

  @override
  Future<void> syncProgressWithCohort(
    String userId, 
    String goalId, 
    double value, 
    bool isCompleted,
    int currentStreak,
    int totalCompletedDays,
    double consistencyRate,
  ) async {
    // In mock mode, the user's progress is fetched dynamically from their own repositories,
    // so we just trigger a refreshed stream broadcast to sync the view!
    _triggerLeaderboardUpdate(goalId);
  }
}

class _CompetitorProfile {
  final String username;
  final String displayName;
  final double baseConsistency;
  _CompetitorProfile(this.username, this.displayName, this.baseConsistency);
}
