import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config_service.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/data/mock_auth_repository.dart';
import '../../features/auth/data/firebase_auth_repository.dart';
import '../../features/goals/domain/goal_repository.dart';
import '../../features/goals/data/mock_goal_repository.dart';
import '../../features/goals/data/firestore_goal_repository.dart';
import '../../features/leaderboard/domain/leaderboard_repository.dart';
import '../../features/leaderboard/data/mock_leaderboard_repository.dart';
import '../../features/leaderboard/data/firestore_leaderboard_repository.dart';

// SharedPreferences Provider - will be overridden in main()
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

// Services Providers
final configServiceProvider = Provider<ConfigService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ConfigService(prefs);
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(); // Managed externally or singleton
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// Dynamic configuration state
final useFirebaseProvider = StateProvider<bool>((ref) {
  final configService = ref.watch(configServiceProvider);
  return configService.useFirebase;
});

// Dynamic Repositories (Switches on useFirebaseProvider change)
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final useFirebase = ref.watch(useFirebaseProvider);
  final storage = ref.watch(storageServiceProvider);
  
  if (useFirebase) {
    return FirebaseAuthRepository();
  } else {
    return MockAuthRepository(storage);
  }
});

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final useFirebase = ref.watch(useFirebaseProvider);
  final storage = ref.watch(storageServiceProvider);

  if (useFirebase) {
    return FirestoreGoalRepository();
  } else {
    return MockGoalRepository(storage);
  }
});

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  final useFirebase = ref.watch(useFirebaseProvider);
  final storage = ref.watch(storageServiceProvider);

  if (useFirebase) {
    return FirestoreLeaderboardRepository();
  } else {
    return MockLeaderboardRepository(storage);
  }
});
