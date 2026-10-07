import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/leaderboard_entry.dart';
import '../domain/leaderboard_repository.dart';

class FirestoreLeaderboardRepository implements LeaderboardRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache to store matched cohortId by goalId
  final Map<String, String> _goalCohortCache = {};

  double _calculateScore({
    required double completionPercentage,
    required int streak,
    required int totalCompletedDays,
    required double consistencyRate,
  }) {
    final streakPoints = streak * 10.0;
    final completedDaysPoints = totalCompletedDays * 5.0;
    return (completionPercentage * 0.5) + (streakPoints * 0.3) + (completedDaysPoints * 0.2) + (consistencyRate * 100 * 0.1);
  }

  @override
  Stream<List<LeaderboardEntry>> getLeaderboardForGoal(String goalId) {
    final controller = StreamController<List<LeaderboardEntry>>.broadcast();
    StreamSubscription? sub;

    _findCohortIdForGoal(goalId).then((cohortId) {
      if (cohortId != null) {
        sub = _firestore
            .collection('cohorts')
            .doc(cohortId)
            .collection('members')
            .snapshots()
            .map((snapshot) {
          final entries = snapshot.docs.map((doc) {
            final data = doc.data();
            final completionPct = (data['targetValue'] as num).toDouble() > 0 
                ? ((data['currentValue'] as num).toDouble() / (data['targetValue'] as num).toDouble()) * 100 
                : 0.0;
                
            final score = _calculateScore(
              completionPercentage: completionPct,
              streak: data['currentStreak'] ?? 0,
              totalCompletedDays: data['totalCompletedDays'] ?? 0,
              consistencyRate: (data['consistencyRate'] as num?)?.toDouble() ?? 0.0,
            );

            return LeaderboardEntry(
              userId: doc.id,
              username: data['username'] ?? 'user',
              displayName: data['displayName'] ?? 'User',
              photoUrl: data['photoUrl'],
              currentValue: (data['currentValue'] as num?)?.toDouble() ?? 0.0,
              targetValue: (data['targetValue'] as num?)?.toDouble() ?? 0.0,
              unit: data['unit'] ?? '',
              completionPercentage: completionPct,
              currentStreak: data['currentStreak'] ?? 0,
              totalCompletedDays: data['totalCompletedDays'] ?? 0,
              consistencyRate: (data['consistencyRate'] as num?)?.toDouble() ?? 0.0,
              score: score,
              todayStatus: data['todayStatus'] ?? 'Pending',
            );
          }).toList();

          // Sort entries by score descending
          entries.sort((a, b) => b.score.compareTo(a.score));
          return entries;
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

  Future<String?> _findCohortIdForGoal(String goalId) async {
    if (_goalCohortCache.containsKey(goalId)) {
      return _goalCohortCache[goalId];
    }

    try {
      // Find where member UID = goalId or search matching cohort registry
      final query = await _firestore
          .collection('cohorts')
          .where('goalIds', arrayContains: goalId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final id = query.docs.first.id;
        _goalCohortCache[goalId] = id;
        return id;
      }
    } catch (e) {
      debugPrint("Error finding cohort ID: $e");
    }
    return null;
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
    try {
      // Check if already cached
      final cachedId = await _findCohortIdForGoal(goalId);
      if (cachedId != null) return;

      // Smart Matching: find an active cohort matching target +/- 20%
      final minVal = targetValue * 0.8;
      final maxVal = targetValue * 1.2;

      // Query cohorts matching category only to avoid Firestore composite index errors
      final query = await _firestore
          .collection('cohorts')
          .where('category', isEqualTo: category)
          .get();

      DocumentSnapshot? matchedCohortDoc;
      for (var doc in query.docs) {
        final data = doc.data();
        final docUnit = data['unit'];
        final docFreq = data['frequency'];
        final docTargetVal = (data['targetValue'] as num?)?.toDouble() ?? 0.0;
        
        if (docUnit == unit && docFreq == frequency && docTargetVal >= minVal && docTargetVal <= maxVal) {
          matchedCohortDoc = doc;
          break;
        }
      }

      String cohortId;
      List<dynamic> existingGoalIds = [];

      // Fetch user profile details to register in cohort members list
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};

      if (matchedCohortDoc != null) {
        // Match found!
        cohortId = matchedCohortDoc.id;
        existingGoalIds = (matchedCohortDoc.data() as Map<String, dynamic>)['goalIds'] ?? [];
      } else {
        // No match, create a new cohort
        final newCohortRef = _firestore.collection('cohorts').doc();
        cohortId = newCohortRef.id;
        
        await newCohortRef.set({
          'category': category,
          'targetValue': targetValue, // Pivot target value
          'unit': unit,
          'frequency': frequency,
          'title': title,
          'goalIds': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Add goalId to cohort goalIds list
      if (!existingGoalIds.contains(goalId)) {
        await _firestore.collection('cohorts').doc(cohortId).update({
          'goalIds': FieldValue.arrayUnion([goalId])
        });
      }

      // Add user details into member subcollection
      await _firestore
          .collection('cohorts')
          .doc(cohortId)
          .collection('members')
          .doc(userId)
          .set({
        'username': userData['username'] ?? 'user',
        'displayName': userData['displayName'] ?? 'User',
        'photoUrl': userData['photoUrl'],
        'currentValue': 0.0,
        'targetValue': targetValue,
        'unit': unit,
        'currentStreak': 0,
        'totalCompletedDays': 0,
        'consistencyRate': 0.0,
        'todayStatus': 'Pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _goalCohortCache[goalId] = cohortId;
    } catch (e) {
      debugPrint("Error joining Firestore cohort: $e");
      throw Exception("Failed to join cohort: $e");
    }
  }

  @override
  Future<void> leaveCohortForGoal(String userId, String goalId) async {
    try {
      final cohortId = await _findCohortIdForGoal(goalId);
      if (cohortId == null) return;

      // Delete member from cohort
      await _firestore
          .collection('cohorts')
          .doc(cohortId)
          .collection('members')
          .doc(userId)
          .delete();

      // Check remaining members in the cohort
      final membersSnap = await _firestore
          .collection('cohorts')
          .doc(cohortId)
          .collection('members')
          .limit(1)
          .get();

      if (membersSnap.docs.isEmpty) {
        // No members left! Delete the cohort document
        await _firestore.collection('cohorts').doc(cohortId).delete();
      } else {
        // Remove goalId from cohort's goalIds
        await _firestore.collection('cohorts').doc(cohortId).update({
          'goalIds': FieldValue.arrayRemove([goalId])
        });
      }

      _goalCohortCache.remove(goalId);
    } catch (e) {
      debugPrint("Error leaving Firestore cohort: $e");
    }
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
    try {
      final cohortId = await _findCohortIdForGoal(goalId);
      if (cohortId == null) return;

      final todayStatus = isCompleted 
          ? 'Completed' 
          : (value > 0 ? 'Pending' : 'Missed');

      await _firestore
          .collection('cohorts')
          .doc(cohortId)
          .collection('members')
          .doc(userId)
          .update({
        'currentValue': value,
        'todayStatus': todayStatus,
        'currentStreak': currentStreak,
        'totalCompletedDays': totalCompletedDays,
        'consistencyRate': consistencyRate,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error syncing progress with Firestore cohort: $e");
    }
  }
}
