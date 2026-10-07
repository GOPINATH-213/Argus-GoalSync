import 'dart:convert';
import 'package:go_router/go_router.dart';

enum NotificationType {
  goalReminder,
  goalCompleted,
  streakAlert,
  competitorUpdate,
  rankChanged,
  achievementUnlocked,
  systemAnnouncement,
  unknown
}

class NotificationData {
  final NotificationType type;
  final String? goalId;
  final Map<String, dynamic> rawPayload;

  NotificationData({
    required this.type,
    this.goalId,
    required this.rawPayload,
  });

  factory NotificationData.fromMap(Map<String, dynamic> map) {
    NotificationType parsedType = NotificationType.unknown;
    final typeStr = map['type'] as String?;
    
    if (typeStr != null) {
      for (var t in NotificationType.values) {
        if (t.name == typeStr) {
          parsedType = t;
          break;
        }
      }
    }

    return NotificationData(
      type: parsedType,
      goalId: map['goalId'] as String?,
      rawPayload: map,
    );
  }

  factory NotificationData.fromJsonString(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return NotificationData.fromMap(map);
    } catch (e) {
      return NotificationData(type: NotificationType.unknown, rawPayload: {});
    }
  }
}

class NotificationNavigationService {
  static void navigateFromNotification(GoRouter router, Map<String, dynamic> data) {
    final notificationData = NotificationData.fromMap(data);

    switch (notificationData.type) {
      case NotificationType.goalReminder:
      case NotificationType.goalCompleted:
        if (notificationData.goalId != null) {
          router.push('/goal-details/${notificationData.goalId}');
        } else {
          router.go('/home');
        }
        break;
      case NotificationType.streakAlert:
        if (notificationData.goalId != null) {
          router.push('/goal-details/${notificationData.goalId}');
        } else {
          router.go('/home');
        }
        break;
      case NotificationType.competitorUpdate:
      case NotificationType.rankChanged:
        if (notificationData.goalId != null) {
          router.push('/goal-details/${notificationData.goalId}');
        } else {
          router.go('/home'); // Or a specific leaderboard route
        }
        break;
      case NotificationType.achievementUnlocked:
        router.push('/profile');
        break;
      case NotificationType.systemAnnouncement:
      case NotificationType.unknown:
        router.push('/notifications');
        break;
    }
  }
}
