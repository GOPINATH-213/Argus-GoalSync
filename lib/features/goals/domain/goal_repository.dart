import 'goal.dart';
import 'goal_progress.dart';

abstract class GoalRepository {
  Stream<List<Goal>> getGoals(String userId);
  
  Future<Goal?> getGoalById(String goalId);
  
  Future<void> createGoal(Goal goal);
  
  Future<void> updateGoal(Goal goal);
  
  Future<void> deleteGoal(String goalId);
  
  Stream<List<GoalProgress>> getGoalProgressHistory(String goalId);
  
  Future<GoalProgress?> getGoalProgressForDate(String goalId, DateTime date);
  
  Future<void> updateGoalProgress(GoalProgress progress);
}
