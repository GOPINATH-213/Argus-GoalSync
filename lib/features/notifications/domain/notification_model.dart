import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/notification_navigation_service.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final String? goalId;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.goalId,
    required this.isRead,
    required this.createdAt,
    this.metadata,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    NotificationType parsedType = NotificationType.unknown;
    final typeStr = data['type'] as String?;
    if (typeStr != null) {
      for (var t in NotificationType.values) {
        if (t.name == typeStr) {
          parsedType = t;
          break;
        }
      }
    }

    return NotificationModel(
      id: doc.id,
      title: data['title'] ?? 'Notification',
      message: data['message'] ?? '',
      type: parsedType,
      goalId: data['goalId'],
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type.name,
      if (goalId != null) 'goalId': goalId,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      if (metadata != null) 'metadata': metadata,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    String? goalId,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      goalId: goalId ?? this.goalId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
