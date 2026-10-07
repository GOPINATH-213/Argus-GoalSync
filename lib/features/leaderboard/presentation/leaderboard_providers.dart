import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/leaderboard_entry.dart';
import '../../../core/services/providers.dart';

// Stream of leaderboard entries for a specific goal (cohort)
final goalLeaderboardProvider = StreamProvider.family<List<LeaderboardEntry>, String>((ref, goalId) {
  final leaderboardRepo = ref.watch(leaderboardRepositoryProvider);
  return leaderboardRepo.getLeaderboardForGoal(goalId);
});
