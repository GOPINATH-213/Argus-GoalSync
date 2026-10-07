import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/auth_repository.dart';
import '../domain/user_profile.dart';
import '../../goals/presentation/goal_providers.dart';
import '../../../core/services/providers.dart';

// Stream provider for the current user profile
final currentUserProvider = StreamProvider<UserProfile?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
});

// Controller to manage authentication asynchronous actions (loading state, errors)
class AuthController extends StateNotifier<AsyncValue<UserProfile?>> {
  final AuthRepository _authRepository;
  final Ref _ref;

  AuthController(this._authRepository, this._ref) : super(const AsyncValue.data(null));

  Future<void> login(String email, String password, {required void Function(String) onError}) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authRepository.loginWithEmail(email, password);
      state = AsyncValue.data(user);
      
      // Sync FCM token
      _ref.read(notificationServiceProvider).syncDeviceToken();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      onError(e.toString().replaceAll("Exception: ", ""));
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String displayName,
    required void Function(String) onError,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authRepository.signUpWithEmail(
        email: email,
        password: password,
        username: username,
        displayName: displayName,
      );
      state = AsyncValue.data(user);
      
      // Sync FCM token
      _ref.read(notificationServiceProvider).syncDeviceToken();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      onError(e.toString().replaceAll("Exception: ", ""));
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    // Remove FCM token before logging out
    await _ref.read(notificationServiceProvider).removeDeviceToken();
    await _authRepository.logout();
    state = const AsyncValue.data(null);
  }

  Future<void> addXp(int amount, Ref ref) async {
    final user = state.value ?? ref.read(currentUserProvider).value;
    if (user == null) return;
    
    final newXp = user.xp + amount;
    // Level Up calculation: Level = (XP / 1000) + 1
    final newLevel = (newXp / 1000).floor() + 1;
    
    var updatedUser = user.copyWith(xp: newXp, level: newLevel);
    
    // Check if new level unlocked
    if (newLevel > user.level) {
      final notifications = ref.read(notificationServiceProvider);
      notifications.showNotification(
        id: 999,
        title: "🎉 Level Up!",
        body: "Congratulations! You reached Level $newLevel!",
        payload: "level_up",
      );
    }
    
    state = AsyncValue.data(updatedUser);
    await _authRepository.updateProfile(updatedUser);

    if (newXp >= 5000 && !updatedUser.badges.contains('XPCollector')) {
      await awardBadge('XPCollector', ref);
    }
  }

  Future<void> awardBadge(String badgeId, Ref ref) async {
    final user = state.value ?? ref.read(currentUserProvider).value;
    if (user == null || user.badges.contains(badgeId)) return;
    
    final updatedBadges = List<String>.from(user.badges)..add(badgeId);
    final updatedUser = user.copyWith(badges: updatedBadges);
    
    // Notify user of badge unlock
    final notifications = ref.read(notificationServiceProvider);
    notifications.showNotification(
      id: 998,
      title: "🏆 Badge Unlocked!",
      body: "You earned the '$badgeId' badge! Check your profile.",
      payload: "badge_$badgeId",
    );

    state = AsyncValue.data(updatedUser);
    await _authRepository.updateProfile(updatedUser);
    
    // Give bonus XP for badge unlock (+100 XP)
    await addXp(100, ref);
  }

  Future<void> updateProfile(UserProfile profile) async {
    try {
      final updated = await _authRepository.updateProfile(profile);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteAccount() async {
    final user = state.value ?? _ref.read(currentUserProvider).value;
    if (user == null) return;
    
    state = const AsyncValue.loading();
    try {
      // 1. Delete all user's goals & clean up their cohort memberships
      final goalsState = _ref.read(userGoalsProvider).value;
      if (goalsState != null) {
        final goalController = _ref.read(goalControllerProvider.notifier);
        for (var goal in goalsState) {
          await goalController.deleteGoal(goal.id);
        }
      }
      
      // Remove FCM token before deleting
      await _ref.read(notificationServiceProvider).removeDeviceToken();
      
      // 2. Perform database and authentication deletion
      await _authRepository.deleteAccount(user.uid);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<UserProfile?>>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return AuthController(authRepo, ref);
});
