import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/goals/domain/goal.dart';
import 'dart:convert';

class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Stream to listen to in-app alerts (specifically useful on Web or when app is in foreground)
  final StreamController<String> _alertStreamController = StreamController<String>.broadcast();
  Stream<String> get alertStream => _alertStreamController.stream;

  Future<void> init() async {
    if (kIsWeb) {
      debugPrint("Notifications: Web mode initialized (Alert stream fallback).");
      return;
    }

    try {
      tz.initializeTimeZones();
      final TimezoneInfo timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
      
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('launcher_icon');
      
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          if (details.payload != null) {
            _alertStreamController.add(details.payload!);
          }
        },
      );
      
      // Initialize Firebase Messaging
      FirebaseMessaging.instance.onTokenRefresh.listen(_syncTokenToFirestore);
      
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        
        final notification = message.notification;
        final android = message.notification?.android;

        if (notification != null && android != null) {
          showNotification(
            id: notification.hashCode,
            title: notification.title ?? 'New Notification',
            body: notification.body ?? '',
            payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
          );
        }
      });
      
    } catch (e) {
      debugPrint("Failed to initialize local notifications: $e");
    }
  }

  Future<void> syncDeviceToken() async {
    if (kIsWeb) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _syncTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint("Error fetching FCM token: $e");
    }
  }

  Future<void> _syncTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return; // Only sync if logged in

      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null) {
        deviceId = const Uuid().v4();
        await prefs.setString('device_id', deviceId);
      }

      final deviceRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId);

      await deviceRef.set({
        'fcmToken': token,
        'platform': defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'notificationsEnabled': await Permission.notification.isGranted,
      }, SetOptions(merge: true));
      
      debugPrint("FCM token synced to Firestore for device: $deviceId");
    } catch (e) {
      debugPrint("Error syncing FCM token to Firestore: $e");
    }
  }

  Future<void> removeDeviceToken() async {
     try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');
      if (deviceId == null) return;

      final deviceRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId);

      await deviceRef.delete();
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint("Error removing FCM token: $e");
    }
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) return;
    
    try {
      // Request notification permission using permission_handler
      final status = await Permission.notification.request();
      debugPrint("Notification permission status: $status");

      if (status.isPermanentlyDenied) {
        _alertStreamController.add("settings_redirect_prompt");
      } else if (status.isGranted) {
        // Sync token once permission is granted
        await syncDeviceToken();
      }

      final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }
      
      final iosImplementation = _localNotifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint("Error requesting notification permissions: $e");
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Add to stream so UI can show in-app notification toasts dynamically
    _alertStreamController.add(payload ?? "$title: $body");

    if (kIsWeb) {
      debugPrint("Show Notification (Web): [$title] - $body");
      return;
    }

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'goalsync_channel',
        'GoalSync Notifications',
        channelDescription: 'Goal completions, streaks, and ranking alerts',
        importance: Importance.max,
        priority: Priority.high,
      );
      
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint("Error showing local notification: $e");
    }
  }

  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) {
      debugPrint("Schedule Reminder (Web): Daily at $hour:$minute -> $title");
      return;
    }

    try {
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'goalsync_reminders_channel',
        'GoalSync Reminders',
        channelDescription: 'Daily reminder check-ins',
        importance: Importance.high,
        priority: Priority.high,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      try {
        await _localNotifications.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e) {
        debugPrint("Exact alarm scheduling failed, fallback to inexact: $e");
        await _localNotifications.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (e) {
      debugPrint("Error scheduling local notification: $e");
    }
  }

  Future<void> scheduleGoalReminders(Goal goal) async {
    if (kIsWeb || goal.reminderTime == null) return;

    try {
      final timeParts = goal.reminderTime!.split(':');
      if (timeParts.length != 2) return;
      
      final hour = int.tryParse(timeParts[0]) ?? 8;
      final minute = int.tryParse(timeParts[1]) ?? 0;

      final int baseId = goal.id.hashCode & 0x7FFFFFFF;

      // 1. Daily Goal Reminder
      await scheduleDailyReminder(
        id: baseId,
        title: '⏰ Goal Reminder',
        body: 'Time to complete your "${goal.title}" goal!',
        hour: hour,
        minute: minute,
      );

      // 2. Incomplete Goal Reminder at 9:00 PM (21:00)
      await scheduleDailyReminder(
        id: baseId + 100000,
        title: '🌙 Incomplete Goal Reminder',
        body: 'You haven\'t completed today\'s goal "${goal.title}" yet. Finish it before the day ends!',
        hour: 21,
        minute: 0,
      );

      // 3. Streak Motivation at 12:00 PM (12:00)
      if (goal.currentStreak > 0) {
        await scheduleDailyReminder(
          id: baseId + 200000,
          title: '🔥 Streak Motivation',
          body: 'You\'re on a ${goal.currentStreak}-day streak for "${goal.title}". Keep it going!',
          hour: 12,
          minute: 0,
        );
      }
    } catch (e) {
      debugPrint("Error scheduling goal reminders: $e");
    }
  }

  Future<void> cancelScheduledNotificationsForGoal(String goalId) async {
    if (kIsWeb) return;
    try {
      final int baseId = goalId.hashCode & 0x7FFFFFFF;
      await _localNotifications.cancel(baseId);
      await _localNotifications.cancel(baseId + 100000);
      await _localNotifications.cancel(baseId + 200000);
    } catch (e) {
      debugPrint("Error canceling scheduled notifications: $e");
    }
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await _localNotifications.cancel(id);
  }

  Future<void> scheduleTestNotification() async {
    if (kIsWeb) return;
    try {
      final tz.TZDateTime scheduledDate = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'goalsync_test_channel',
        'GoalSync Test',
        channelDescription: 'Testing instant/short-delayed notifications',
        importance: Importance.max,
        priority: Priority.high,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      try {
        await _localNotifications.zonedSchedule(
          9999,
          '🧪 Test Notification',
          'This is a test notification scheduled 10 seconds ago.',
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint("Test notification exact alarm scheduling failed, fallback to inexact: $e");
        await _localNotifications.zonedSchedule(
          9999,
          '🧪 Test Notification',
          'This is a test notification scheduled 10 seconds ago.',
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
      debugPrint("Test notification scheduled successfully to fire in 10 seconds at $scheduledDate");
    } catch (e) {
      debugPrint("Error scheduling test notification: $e");
    }
  }
}
