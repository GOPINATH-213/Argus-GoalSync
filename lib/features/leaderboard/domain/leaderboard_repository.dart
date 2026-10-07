import 'leaderboard_entry.dart';

abstract class LeaderboardRepository {
  Stream<List<LeaderboardEntry>> getLeaderboardForGoal(String goalId);
  
  Future<void> joinCohortForGoal(
    String userId, 
    String goalId, {
    required String category, 
    required double targetValue, 
    required String unit, 
    required String frequency,
    required String title,
  });
  
  Future<void> leaveCohortForGoal(String userId, String goalId);
  
  Future<void> syncProgressWithCohort(
    String userId, 
    String goalId, 
    double value, 
    bool isCompleted,
    int currentStreak,
    int totalCompletedDays,
    double consistencyRate,
  );
}
