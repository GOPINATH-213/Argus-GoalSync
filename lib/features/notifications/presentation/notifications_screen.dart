import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import 'notification_providers.dart';
import '../domain/notification_model.dart';
import '../../../core/services/notification_navigation_service.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final controller = ref.read(notificationListControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.checkCheck),
            tooltip: 'Mark all as read',
            onPressed: () => controller.markAllAsRead(),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.bellOff, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('No notifications yet', style: theme.textTheme.titleMedium),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (context, index) => Divider(color: theme.colorScheme.surfaceContainerHighest, height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationItem(context, notification, controller);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading notifications: $error', style: TextStyle(color: theme.colorScheme.error)),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, NotificationModel notification, NotificationListController controller) {
    final theme = Theme.of(context);
    final iconData = _getIconForType(notification.type);
    final iconColor = _getColorForType(notification.type);

    return InkWell(
      onTap: () {
        if (!notification.isRead) {
          controller.markAsRead(notification.id);
        }
        
        // Use NotificationNavigationService if there's raw payload, otherwise handle basic nav
        if (notification.metadata != null) {
          NotificationNavigationService.navigateFromNotification(GoRouter.of(context), notification.metadata!);
        } else {
          // Construct basic payload
          final data = {
            'type': notification.type.name,
            if (notification.goalId != null) 'goalId': notification.goalId,
          };
          NotificationNavigationService.navigateFromNotification(GoRouter.of(context), data);
        }
      },
      child: Container(
        color: notification.isRead ? Colors.transparent : AppColors.primary.withValues(alpha: 0.1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: iconColor.withValues(alpha: 0.2),
              child: Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(notification.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.goalReminder: return LucideIcons.alarmClock;
      case NotificationType.goalCompleted: return LucideIcons.checkCircle2;
      case NotificationType.streakAlert: return LucideIcons.flame;
      case NotificationType.competitorUpdate: return LucideIcons.swords;
      case NotificationType.rankChanged: return LucideIcons.trendingUp;
      case NotificationType.achievementUnlocked: return LucideIcons.medal;
      case NotificationType.systemAnnouncement: return LucideIcons.megaphone;
      case NotificationType.unknown: return LucideIcons.bell;
    }
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.goalReminder: return Colors.blue;
      case NotificationType.goalCompleted: return AppColors.success;
      case NotificationType.streakAlert: return Colors.orange;
      case NotificationType.competitorUpdate: return Colors.red;
      case NotificationType.rankChanged: return Colors.purple;
      case NotificationType.achievementUnlocked: return Colors.amber;
      case NotificationType.systemAnnouncement: return Colors.teal;
      case NotificationType.unknown: return Colors.grey;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat.jm().format(dateTime); // e.g. 5:30 PM
    } else if (difference.inDays < 7) {
      return DateFormat.E().format(dateTime); // e.g. Mon
    } else {
      return DateFormat.MMMd().format(dateTime); // e.g. Oct 12
    }
  }
}
