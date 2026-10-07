// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goalsync/main.dart';
import 'package:goalsync/core/services/providers.dart';
import 'package:goalsync/features/auth/domain/auth_repository.dart';
import 'package:goalsync/features/auth/domain/user_profile.dart';
import 'package:goalsync/features/goals/domain/goal_repository.dart';
import 'package:goalsync/features/goals/domain/goal.dart';
import 'package:goalsync/features/goals/domain/goal_progress.dart';
import 'package:goalsync/features/leaderboard/domain/leaderboard_repository.dart';
import 'package:goalsync/features/leaderboard/domain/leaderboard_entry.dart';

void main() {
  testWidgets('App compiles and loads smoke test', (WidgetTester tester) async {
    // Mock shared preferences
    SharedPreferences.setMockInitialValues({});
    final sharedPrefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          authRepositoryProvider.overrideWithValue(DummyAuthRepository()),
          goalRepositoryProvider.overrideWithValue(DummyGoalRepository()),
          leaderboardRepositoryProvider.overrideWithValue(DummyLeaderboardRepository()),
        ],
        child: const MyApp(),
      ),
    );

    // Let the app run initial frames
    await tester.pump();

    // Verify that our app renders successfully without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

class DummyAuthRepository implements AuthRepository {
  final _controller = StreamController<UserProfile?>.broadcast();

  @override
  Stream<UserProfile?> get authStateChanges => _controller.stream;

  @override
  Future<UserProfile?> getCurrentUser() async => null;

  @override
  Future<UserProfile> loginWithEmail(String email, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<bool> isUsernameAvailable(String username) async => true;

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async => profile;

  @override
  Future<void> deleteAccount(String uid) async {}
}

class DummyGoalRepository implements GoalRepository {
  @override
  Stream<List<Goal>> getGoals(String userId) => Stream.value([]);

  @override
  Future<Goal?> getGoalById(String goalId) async => null;

  @override
  Future<void> createGoal(Goal goal) async {}

  @override
  Future<void> updateGoal(Goal goal) async {}

  @override
  Future<void> deleteGoal(String goalId) async {}

  @override
  Stream<List<GoalProgress>> getGoalProgressHistory(String goalId) => Stream.value([]);

  @override
  Future<GoalProgress?> getGoalProgressForDate(String goalId, DateTime date) async => null;

  @override
  Future<void> updateGoalProgress(GoalProgress progress) async {}
}

class DummyLeaderboardRepository implements LeaderboardRepository {
  @override
  Stream<List<LeaderboardEntry>> getLeaderboardForGoal(String goalId) => Stream.value([]);

  @override
  Future<void> joinCohortForGoal(
    String userId, 
    String goalId, {
    required String category, 
    required double targetValue, 
    required String unit, 
    required String frequency,
    required String title,
  }) async {}

  @override
  Future<void> leaveCohortForGoal(String userId, String goalId) async {}

  @override
  Future<void> syncProgressWithCohort(
    String userId, 
    String goalId, 
    double value, 
    bool isCompleted,
    int currentStreak,
    int totalCompletedDays,
    double consistencyRate,
  ) async {}
}
