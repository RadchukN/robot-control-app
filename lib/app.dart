import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/core/config/app_config.dart';
import 'package:robot_control_app/core/routing/app_router.dart';
import 'package:robot_control_app/core/theme/app_theme.dart';
import 'package:robot_control_app/core/theme/theme_provider.dart';
import 'package:robot_control_app/shared/notifications/app_notification_host.dart';
import 'package:robot_control_app/shared/notifications/robot_link_notifications.dart';

class RobotControlApp extends ConsumerWidget {
  const RobotControlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: config.applicationName,
      debugShowCheckedModeBanner: config.debugMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      // One notification layer above every route; it never shifts page layout.
      builder: (context, child) => AppNotificationHost(
        child: RobotLinkNotifications(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
