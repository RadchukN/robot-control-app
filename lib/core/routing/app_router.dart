import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';
import 'package:robot_control_app/features/ai_workspace/presentation/ai_workspace_screen.dart';
import 'package:robot_control_app/features/audio/presentation/audio_screen.dart';
import 'package:robot_control_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:robot_control_app/features/motion/presentation/motion_screen.dart';
import 'package:robot_control_app/features/settings/presentation/settings_screen.dart';
import 'package:robot_control_app/features/vision/presentation/vision_screen.dart';
import 'package:robot_control_app/features/voice_studio/presentation/voice_studio_screen.dart';
import 'package:robot_control_app/shared/widgets/app_navigation_shell.dart';
import 'package:robot_control_app/shared/widgets/error_view.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.dashboard,
    routes: [
      GoRoute(
        path: AppRoutes.dashboardAlias,
        redirect: (context, state) => AppRoutes.dashboard,
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppNavigationShell(navigationShell: navigationShell),
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.aiWorkspace,
                builder: (context, state) => const AiWorkspaceScreen(),
              ),
            ],
          ),
          // Appended so existing branch indexes stay unchanged.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.voiceStudio,
                builder: (context, state) => const VoiceStudioScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: ErrorView(
        message:
            state.error?.toString() ?? 'The requested page does not exist.',
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
}, name: 'AppRouterProvider');
