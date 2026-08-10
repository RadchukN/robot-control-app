import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';
import 'package:robot_control_app/features/audio/presentation/audio_screen.dart';
import 'package:robot_control_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:robot_control_app/features/motion/presentation/motion_screen.dart';
import 'package:robot_control_app/features/settings/presentation/settings_screen.dart';
import 'package:robot_control_app/features/vision/presentation/vision_screen.dart';
import 'package:robot_control_app/shared/widgets/error_view.dart';

final appRouterProvider = Provider<GoRouter>(
  (ref) {
    final router = GoRouter(
      initialLocation: AppRoutes.dashboard,
      routes: [
        GoRoute(
          path: AppRoutes.dashboardAlias,
          redirect: (context, state) => AppRoutes.dashboard,
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => AppNavigationShell(
            navigationShell: navigationShell,
          ),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.dashboard,
                  builder: (context, state) => const DashboardScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.motion,
                  builder: (context, state) => const MotionScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.audio,
                  builder: (context, state) => const AudioScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.vision,
                  builder: (context, state) => const VisionScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.settings,
                  builder: (context, state) => const SettingsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Page not found')),
        body: ErrorView(message: state.error?.toString() ?? 'The requested page does not exist.'),
      ),
    );
    ref.onDispose(router.dispose);
    return router;
  },
  name: 'AppRouterProvider',
);

class AppNavigationShell extends StatelessWidget {
  const AppNavigationShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.directions_walk_outlined),
              selectedIcon: Icon(Icons.directions_walk_rounded),
              label: 'Motion',
            ),
            NavigationDestination(
              icon: Icon(Icons.graphic_eq_outlined),
              selectedIcon: Icon(Icons.graphic_eq_rounded),
              label: 'Audio',
            ),
            NavigationDestination(
              icon: Icon(Icons.visibility_outlined),
              selectedIcon: Icon(Icons.visibility_rounded),
              label: 'Vision',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      );
}
