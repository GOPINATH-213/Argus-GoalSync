import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'auth_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../domain/user_profile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  final List<Map<String, dynamic>> _allBadges = const [
    {
      'id': 'StreakMaster',
      'name': 'Streak Master',
      'description': 'Achieve a 7-day completion streak on any goal',
      'icon': Icons.local_fire_department,
      'color': AppColors.streakActive,
    },
    {
      'id': 'StreakLegend',
      'name': 'Streak Legend',
      'description': 'Achieve a 30-day completion streak on any goal',
      'icon': Icons.flash_on,
      'color': AppColors.streakGold,
    },
    {
      'id': 'EarlyBird',
      'name': 'Early Bird',
      'description': 'Complete a daily goal before 9:00 AM',
      'icon': Icons.wb_sunny,
      'color': Colors.amber,
    },
    {
      'id': 'ConsistencyKing',
      'name': 'Consistency King',
      'description': 'Achieve a 90% completion consistency over 5+ active days',
      'icon': Icons.military_tech,
      'color': Colors.purple,
    },
    {
      'id': 'MilestoneAchiever',
      'name': 'Milestone Achiever',
      'description': 'Complete 20 total daily goal milestones',
      'icon': Icons.stars,
      'color': AppColors.secondary,
    },
    {
      'id': 'NightOwl',
      'name': 'Night Owl',
      'description': 'Complete a goal between 9:00 PM and 11:59 PM',
      'icon': Icons.nights_stay,
      'color': Colors.indigo,
    },
    {
      'id': 'WeekendWarrior',
      'name': 'Weekend Warrior',
      'description': 'Complete a goal on Saturday or Sunday',
      'icon': Icons.sports_kabaddi,
      'color': Colors.orange,
    },
    {
      'id': 'HabitStarter',
      'name': 'Habit Starter',
      'description': 'Log progress on 3 different goals in a single day',
      'icon': Icons.rocket_launch,
      'color': Colors.teal,
    },
    {
      'id': 'XPCollector',
      'name': 'XP Collector',
      'description': 'Reach a total of 5,000 XP (Level 6+)',
      'icon': Icons.emoji_events,
      'color': Colors.amber,
    },
    {
      'id': 'HydrationHero',
      'name': 'Hydration Hero',
      'description': 'Complete any Hydration category goal 5 times',
      'icon': Icons.opacity,
      'color': Colors.blue,
    },
    {
      'id': 'FitnessFanatic',
      'name': 'Fitness Fanatic',
      'description': 'Complete any Fitness/Exercise category goal 5 times',
      'icon': Icons.fitness_center,
      'color': Colors.deepOrange,
    },
    {
      'id': 'MindfulnessGuru',
      'name': 'Mindfulness Guru',
      'description': 'Complete any Health/Meditation category goal 5 times',
      'icon': Icons.self_improvement,
      'color': Colors.green,
    },
    {
      'id': 'SuperScholar',
      'name': 'Super Scholar',
      'description': 'Complete any Study/Learning category goal 5 times',
      'icon': Icons.auto_stories,
      'color': Colors.brown,
    },
    {
      'id': 'CustomCreator',
      'name': 'Custom Creator',
      'description': 'Create a goal under the custom "Others" category',
      'icon': Icons.build,
      'color': Colors.blueGrey,
    },
    {
      'id': 'PerfectWeek',
      'name': 'Perfect Week',
      'description': 'Maintain a 7-day completion streak on 2 or more different goals',
      'icon': Icons.workspace_premium,
      'color': Colors.cyan,
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.danger),
            onPressed: () => _confirmLogout(context, ref),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
        child: userState.when(
          data: (user) {
            if (user == null) return const Center(child: Text("Loading profile..."));

            const nextLevelXp = 1000;
            final currentLevelXp = user.xp % 1000;
            final xpPercent = currentLevelXp / nextLevelXp;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Profile Card (Avatar and Metadata)
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => _pickImage(context, ref, user),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: theme.colorScheme.secondary,
                                backgroundImage: _getProfileImageProvider(user.photoUrl),
                                child: user.photoUrl == null || user.photoUrl!.isEmpty
                                    ? Text(
                                        user.displayName.substring(0, 1).toUpperCase(),
                                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                                      )
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.colorScheme.surface, width: 1.5),
                                ),
                                child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.displayName,
                          style: theme.textTheme.displayMedium?.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${user.username}',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Member since: ${user.createdAt.year}-${user.createdAt.month}-${user.createdAt.day}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 2. Level Details Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Level ${user.level}',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${user.xp} Total XP',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.xpColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: xpPercent,
                              minHeight: 12,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.xpColor),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${nextLevelXp - currentLevelXp} XP to reach Level ${user.level + 1}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 3. Badges / Achievements Title
                  Text(
                    'Achievements & Badges',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // 4. Badges Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _allBadges.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemBuilder: (context, index) {
                      final badge = _allBadges[index];
                      final isUnlocked = user.badges.contains(badge['id']);

                      return GestureDetector(
                        onTap: () => _showBadgeDetails(context, badge, isUnlocked),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isUnlocked 
                                ? theme.colorScheme.primaryContainer.withAlpha(40) 
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isUnlocked ? badge['color'] : theme.colorScheme.outlineVariant,
                              width: isUnlocked ? 1.8 : 0.8,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                badge['icon'],
                                size: 32,
                                color: isUnlocked ? badge['color'] : Colors.grey.withAlpha(100),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Text(
                                  badge['name'],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isUnlocked ? theme.colorScheme.onSurface : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(child: Text("Error: $err")),
        ),
      ),
    );
  }

  void _showBadgeDetails(BuildContext context, Map<String, dynamic> badge, bool isUnlocked) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: Icon(badge['icon'], size: 48, color: isUnlocked ? badge['color'] : Colors.grey),
          title: Text(badge['name']),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                badge['description'],
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isUnlocked ? AppColors.success.withAlpha(20) : Colors.grey.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isUnlocked ? 'Unlocked ✅' : 'Locked 🔒',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isUnlocked ? AppColors.success : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out? Your goals and history are saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context); // Close dialog
                ref.read(authControllerProvider.notifier).logout();
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  ImageProvider? _getProfileImageProvider(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    if (photoUrl.startsWith('http') || photoUrl.startsWith('https')) {
      return NetworkImage(photoUrl);
    }
    return FileImage(File(photoUrl));
  }

  Future<void> _pickImage(BuildContext context, WidgetRef ref, UserProfile user) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (image != null) {
        final updatedUser = user.copyWith(photoUrl: image.path);
        await ref.read(authControllerProvider.notifier).updateProfile(updatedUser);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }
}
