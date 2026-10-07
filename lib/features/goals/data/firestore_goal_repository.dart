import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../domain/goal.dart';
import '../domain/goal_progress.dart';
import '../domain/goal_repository.dart';

class FirestoreGoalRepository implements GoalRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _dateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  @override
  Stream<List<Goal>> getGoals(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('goals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Goal.fromMap(doc.data())).toList();
    });
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Future<Goal?> getGoalById(String goalId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        final doc = await _firestore
            .collection('users')
            .doc(uid)
            .collection('goals')
            .doc(goalId)
            .get();
        if (doc.exists && doc.data() != null) {
          return Goal.fromMap(doc.data()!);
        }
      }
      
      // Fallback
      final query = await _firestore
          .collectionGroup('goals')
          .where('id', isEqualTo: goalId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return Goal.fromMap(query.docs.first.data());
      }
    } catch (e) {
      debugPrint("Error fetching goal by ID in Firestore: $e");
    }
    return null;
  }

  @override
  Future<void> createGoal(Goal goal) async {
    await _firestore
        .collection('users')
        .doc(goal.userId)
        .collection('goals')
        .doc(goal.id)
        .set(goal.toMap());
  }

  @override
  Future<void> updateGoal(Goal goal) async {
    await _firestore
        .collection('users')
        .doc(goal.userId)
        .collection('goals')
        .doc(goal.id)
        .update(goal.toMap());
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    try {
      // Find the goal first to get the userId
      final goal = await getGoalById(goalId);
      if (goal != null) {
        final docRef = _firestore
            .collection('users')
            .doc(goal.userId)
            .collection('goals')
            .doc(goalId);

        // Delete all progress documents in the subcollection first
        final progressDocs = await docRef.collection('progress').get();
        final batch = _firestore.batch();
        for (var doc in progressDocs.docs) {
          batch.delete(doc.reference);
        }
        
        // Delete the goal itself
        batch.delete(docRef);
        await batch.commit();
      }
    } catch (e) {
      debugPrint("Error deleting goal in Firestore: $e");
      throw Exception("Failed to delete goal: $e");
    }
  }

  @override
  Stream<List<GoalProgress>> getGoalProgressHistory(String goalId) {
    // Query collectionGroup or find goal first to get path. Since snaps must be live,
    // we fetch goal first to determine the userId, and then stream.
    final controller = StreamController<List<GoalProgress>>.broadcast();
    StreamSubscription? sub;

    getGoalById(goalId).then((goal) {
      if (goal != null) {
        sub = _firestore
            .collection('users')
            .doc(goal.userId)
            .collection('goals')
            .doc(goalId)
            .collection('progress')
            .orderBy('date', descending: true)
            .snapshots()
            .map((snapshot) {
          return snapshot.docs.map((doc) => GoalProgress.fromMap(doc.data())).toList();
        }).listen(
          (data) => controller.add(data),
          onError: (err) => controller.addError(err),
        );
      } else {
        controller.add([]);
      }
    });

    controller.onCancel = () {
      sub?.cancel();
    };

    return controller.stream;
  }

  @override
  Future<GoalProgress?> getGoalProgressForDate(String goalId, DateTime date) async {
    final goal = await getGoalById(goalId);
    if (goal != null) {
      final doc = await _firestore
          .collection('users')
          .doc(goal.userId)
          .collection('goals')
          .doc(goalId)
          .collection('progress')
          .doc(_dateKey(date))
          .get();
      if (doc.exists && doc.data() != null) {
        return GoalProgress.fromMap(doc.data()!);
      }
    }
    return null;
  }

  @override
  Future<void> updateGoalProgress(GoalProgress progress) async {
    final goal = await getGoalById(progress.goalId);
    if (goal == null) return;

    final docRef = _firestore
        .collection('users')
        .doc(goal.userId)
        .collection('goals')
        .doc(progress.goalId)
        .collection('progress')
        .doc(_dateKey(progress.date));

    // Save progress doc
    await docRef.set(progress.toMap());

    // Recalculate streak values from all progress history docs
    final allProgressQuery = await _firestore
        .collection('users')
        .doc(goal.userId)
        .collection('goals')
        .doc(progress.goalId)
        .collection('progress')
        .get();

    final history = allProgressQuery.docs
        .map((doc) => GoalProgress.fromMap(doc.data()))
        .toList();

    final streaks = _calculateStreaks(history);
    
    final updatedGoal = goal.copyWith(
      currentStreak: streaks.current,
      longestStreak: streaks.longest,
      lastCompletedDate: progress.isCompleted && (goal.lastCompletedDate == null || progress.date.isAfter(goal.lastCompletedDate!)) 
          ? progress.date 
          : goal.lastCompletedDate,
    );

    // Save updated goal doc
    await updateGoal(updatedGoal);
  }

  _StreakResult _calculateStreaks(List<GoalProgress> history) {
    if (history.isEmpty) return _StreakResult(0, 0);

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

    // Check if streak is still active
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final lastCompleted = completedDates.last;
    final daysSinceLastComplete = today.difference(lastCompleted).inDays;
    
    int activeStreak = 0;
    if (daysSinceLastComplete <= 1) {
      activeStreak = currentStreak;
    }

    return _StreakResult(activeStreak, maxStreak);
  }
}

class _StreakResult {
  final int current;
  final int longest;
  _StreakResult(this.current, this.longest);
}
