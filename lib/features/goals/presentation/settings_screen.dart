import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/services/providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../notifications/presentation/notification_preferences_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useFirebase = ref.watch(useFirebaseProvider);
    final notificationPrefsAsync = ref.watch(notificationPreferencesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Section 1: Data Mode
            Text(
              'Database Configuration',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Live Firebase Sync'),
                    subtitle: const Text('Use Firebase Auth and Cloud Firestore to compete with real players.'),
                    value: useFirebase,
                    onChanged: (bool value) async {
                      // Save setting to storage
                      final config = ref.read(configServiceProvider);
                      await config.setUseFirebase(value);
                      
                      // Notify Provider
                      ref.read(useFirebaseProvider.notifier).state = value;

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(value 
                                ? 'Switched to live Firebase sync! Logging out active local sessions.' 
                                : 'Switched to offline Mock Mode! Note: No live tracking with your other competitors will show.'),
                            backgroundColor: value ? AppColors.success : AppColors.pending,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 2: Storage Management
            Text(
              'Local Cache Management',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Clear Local Databases'),
                subtitle: const Text('Deletes all local goals, histories, and simulated competitors.'),
                trailing: const Icon(Icons.delete_sweep, color: AppColors.danger),
                onTap: () => _confirmClearStorage(context, ref),
              ),
            ),
            const SizedBox(height: 24),

            // Section 3: App Information
            Text(
              'About App',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text('GoalSync Mobile'),
                    trailing: Text('v1.0.0'),
                  ),
                  Divider(height: 1),
                  ListTile(
                    title: Text('Branding'),
                    trailing: Text('Argus GoalSync'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Notification Diagnostics',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_paused_outlined),
                    title: const Text('Test Notification (10s Delay)'),
                    subtitle: const Text('Schedule a test alert to fire in 10 seconds to verify notifications work on this device.'),
                    onTap: () async {
                      final notifications = ref.read(notificationServiceProvider);
                      await notifications.scheduleTestNotification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Test notification scheduled! Close the app and wait 10 seconds...'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Notification Preferences
            Text(
              'Notification Preferences',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: notificationPrefsAsync.when(
                data: (prefs) {
                  return Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Push Notifications'),
                        subtitle: const Text('Enable or disable all notifications'),
                        value: prefs.pushNotifications,
                        onChanged: (value) => ref.read(notificationPreferencesProvider.notifier).updatePreferences(prefs.copyWith(pushNotifications: value)),
                      ),
                      if (prefs.pushNotifications) ...[
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Goal Reminders'),
                          value: prefs.goalReminders,
                          onChanged: (value) => ref.read(notificationPreferencesProvider.notifier).updatePreferences(prefs.copyWith(goalReminders: value)),
                        ),
                        SwitchListTile(
                          title: const Text('Streak Alerts'),
                          value: prefs.streakAlerts,
                          onChanged: (value) => ref.read(notificationPreferencesProvider.notifier).updatePreferences(prefs.copyWith(streakAlerts: value)),
                        ),
                        SwitchListTile(
                          title: const Text('Competitor Updates'),
                          value: prefs.competitorUpdates,
                          onChanged: (value) => ref.read(notificationPreferencesProvider.notifier).updatePreferences(prefs.copyWith(competitorUpdates: value)),
                        ),
                        SwitchListTile(
                          title: const Text('Rank Changes'),
                          value: prefs.rankChanges,
                          onChanged: (value) => ref.read(notificationPreferencesProvider.notifier).updatePreferences(prefs.copyWith(rankChanges: value)),
                        ),
                        SwitchListTile(
                          title: const Text('Achievements'),
                          value: prefs.achievements,
                          onChanged: (value) => ref.read(notificationPreferencesProvider.notifier).updatePreferences(prefs.copyWith(achievements: value)),
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator())),
                error: (e, st) => Padding(padding: const EdgeInsets.all(16.0), child: Text('Failed to load preferences: $e')),
              ),
            ),
            const SizedBox(height: 24),
            
            // Debug Info
            Text(
              'Developer Debug',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.token, color: Colors.grey),
                    title: const Text('Copy FCM Token'),
                    subtitle: const Text('Use this token to send test messages from Firebase Console.'),
                    onTap: () async {
                      try {
                        final token = await FirebaseMessaging.instance.getToken();
                        if (token != null) {
                          await Clipboard.setData(ClipboardData(text: token));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('FCM Token copied to clipboard!')),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('FCM Token is null (unavailable).')),
                            );
                          }
                        }
                      } catch (e) {
                         if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to get token: $e')),
                            );
                          }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Danger Zone',
              style: theme.textTheme.titleMedium?.copyWith(color: AppColors.danger, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              color: AppColors.danger.withAlpha(15),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: AppColors.danger),
                    title: const Text('Delete Account', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Permanently delete your profile, goals, and credentials.'),
                    onTap: () => _confirmDeleteAccount(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearStorage(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear local database?'),
          content: const Text('This action will delete all local goals, cached profiles, and progress logs. This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
              onPressed: () async {
                final storage = ref.read(storageServiceProvider);
                await storage.clearAll();
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Local Hive boxes cleared successfully!'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Account?'),
          content: const Text(
            'Are you sure you want to permanently delete your account? '
            'This will delete all your active goals, progress history, '
            'competition leaderboards, and login credentials. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                try {
                  Navigator.pop(context); // Close dialog
                  await ref.read(authControllerProvider.notifier).deleteAccount();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Account successfully deleted.'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete account: $e'),
                        backgroundColor: AppColors.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );
  }
}
