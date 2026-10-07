import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/goals/presentation/home_dashboard_screen.dart';
import '../../features/goals/presentation/goal_creation_screen.dart';
import '../../features/goals/presentation/goal_detail_screen.dart';
import '../../features/statistics/presentation/statistics_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/goals/presentation/settings_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../constants/app_colors.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Watch current user to trigger re-evaluation of redirect rules on login/logout
  final authState = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/home',
    // Redirect logic based on auth status
    redirect: (BuildContext context, GoRouterState state) {
      final user = authState.value;
      final isLoading = authState.isLoading;
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';

      if (isLoading) return null; // Wait until loaded

      final isLoggedIn = user != null;

      if (!isLoggedIn) {
        // Force user to login unless they are already registering
        if (!isLoggingIn && !isRegistering) {
          return '/login';
        }
        return null;
      }

      // If logged in, send away from auth pages to home
      if (isLoggingIn || isRegistering) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      
      // Main App Layout using ShellRoute for Bottom Navigation Tabs
      ShellRoute(
        builder: (context, state, child) {
          return MainNavigationShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeDashboardScreen(),
          ),
          GoRoute(
            path: '/statistics',
            builder: (context, state) => const StatisticsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      
      // Sub-pages pushed on top of the main shell
      GoRoute(
        path: '/create-goal',
        builder: (context, state) => const GoalCreationScreen(),
      ),
      GoRoute(
        path: '/goal-details/:id',
        builder: (context, state) {
          final goalId = state.pathParameters['id']!;
          return GoalDetailScreen(goalId: goalId);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
});

class MainNavigationShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainNavigationShell({super.key, required this.child});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).requestPermissions();
    });
  }

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/statistics')) return 1;
    if (location.startsWith('/profile')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/statistics');
        break;
      case 2:
        context.go('/profile');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => _onItemTapped(index, context),
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.colorScheme.primary.withAlpha(50),
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.primary),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: AppColors.primary),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primary),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppColors.primary),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
