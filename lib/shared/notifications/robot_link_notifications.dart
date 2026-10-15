import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/core/routing/app_router.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';
import 'package:robot_control_app/services/robot_connection.dart';
import 'package:robot_control_app/shared/notifications/app_notification.dart';
import 'package:robot_control_app/shared/notifications/app_notification_service.dart';

const robotLinkNotificationKey = 'robot-link';

/// Turns robot link transitions into one keyed notification that updates in
/// place. It only observes link state; it never connects or retries.
class RobotLinkNotifications extends ConsumerStatefulWidget {
  const RobotLinkNotifications({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RobotLinkNotifications> createState() =>
      _RobotLinkNotificationsState();
}

class _RobotLinkNotificationsState
    extends ConsumerState<RobotLinkNotifications> {
  final _policy = RobotLinkNotificationPolicy();

  @override
  Widget build(BuildContext context) {
    ref.listen(robotLinkProvider, (previous, next) {
      if (previous?.status == next.status &&
          previous?.message == next.message) {
        return;
      }
      _policy.apply(
        ref.read(appNotificationsProvider.notifier),
        previous,
        next,
        openSettings: () => ref.read(appRouterProvider).go(AppRoutes.settings),
      );
    });
    return widget.child;
  }
}

/// Reports each outage once: while the dashboard keeps retrying an
/// unreachable robot, connect/retry cycles stay quiet until it connects.
/// Persistent link status remains in the header and Settings.
class RobotLinkNotificationPolicy {
  bool _outageReported = false;

  void apply(
    AppNotificationService notifications,
    RobotLinkState? previous,
    RobotLinkState next, {
    required VoidCallback openSettings,
  }) {
    const key = robotLinkNotificationKey;
    final settings = AppNotificationAction('Settings', openSettings);
    switch (next.status) {
      case RobotLinkStatus.connecting:
        if (_outageReported) return;
        notifications.progress(
          'Connecting to robot…',
          description: 'Opening the Unitree G1 WebSocket.',
          key: key,
        );
      case RobotLinkStatus.reconnecting:
        if (_outageReported) return;
        notifications.progress(
          'Reconnecting to robot…',
          description: 'Connection lost. Commands are never replayed.',
          key: key,
        );
      case RobotLinkStatus.awaitingTelemetry:
        notifications.progress(
          'Waiting for telemetry…',
          description: 'Connected. Waiting for the first robot status update.',
          key: key,
        );
      case RobotLinkStatus.connected:
        _outageReported = false;
        if (previous?.status == RobotLinkStatus.connected) return;
        notifications.success(
          'Connected successfully',
          description: 'Connection to Unitree G1 established.',
          key: key,
        );
      case RobotLinkStatus.degraded:
        notifications.warning(
          'Telemetry unavailable',
          description:
              'Robot telemetry has not updated recently. Motion commands are '
              'disabled until it recovers.',
          key: key,
        );
      case RobotLinkStatus.authenticationRequired:
        _outageReported = true;
        notifications.show(
          AppNotificationType.error,
          'Authentication required',
          description:
              next.message ??
              'The robot rejected the saved token. Update it in Settings.',
          key: key,
          action: settings,
          persistent: true,
        );
      case RobotLinkStatus.disconnected:
        final message = next.message;
        if (message == null || message.startsWith('App suspended')) {
          _outageReported = false;
          notifications.dismiss(key);
          return;
        }
        if (_outageReported) return;
        _outageReported = true;
        notifications.error(
          'Connection failed',
          description:
              'Unable to reach the robot. Check your network settings.',
          key: key,
          action: settings,
        );
    }
  }
}
