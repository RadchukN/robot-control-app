import 'package:robot_control_app/features/motion/application/motion_state.dart';
import 'package:robot_control_app/shared/notifications/app_notification_service.dart';

const motionCommandNotificationKey = 'motion-command';
const motionSafetyNotificationKey = 'motion-safety';

final _unknownOutcome = RegExp(r'outcome (is )?unknown|unknown outcome');

/// Presents a motion command message. Only reads [MotionState]; command
/// sending and the unknown-outcome lock stay in the motion command session.
void notifyMotionCommand(
  AppNotificationService notifications,
  MotionState state,
) {
  final message = state.commandMessage;
  if (message == null) return;
  // Link changes are reported by the robot-link notification.
  if (message == 'Robot WebSocket connected. No motion was sent.') return;

  if (_unknownOutcome.hasMatch(message)) {
    notifications.critical(
      'Robot motion state unknown',
      description:
          'Motion commands are blocked until safety is verified. '
          'Use Stop and confirm the robot state. ($message)',
      key: motionSafetyNotificationKey,
    );
    return;
  }
  if (message.contains('outcome may be unknown')) {
    notifications.warning(
      'Motion outcome may be unknown',
      description: message,
      key: motionCommandNotificationKey,
    );
    return;
  }
  if (message.startsWith('A command is pending')) {
    notifications.warning(
      'Command pending',
      description: message,
      key: motionCommandNotificationKey,
    );
    return;
  }

  const key = motionCommandNotificationKey;
  switch (state.playbackStatus) {
    case MotionPlaybackStatus.sending:
    case MotionPlaybackStatus.stopping:
      notifications.progress(
        state.playbackStatus == MotionPlaybackStatus.stopping
            ? 'Stopping…'
            : 'Sending motion…',
        description: message,
        key: key,
      );
    case MotionPlaybackStatus.playing:
      notifications.info('Playing on robot', description: message, key: key);
    case MotionPlaybackStatus.simulated:
      notifications.info(
        'Motion simulation',
        description: '$simulationOnlyLabel.',
        key: key,
      );
    case MotionPlaybackStatus.finished:
      notifications.success('Motion completed', description: message, key: key);
    case MotionPlaybackStatus.stopped:
      // Never resolves the safety card: a dry_run "stopped" reply maps to the
      // same status, so only the user's acknowledgement removes it.
      notifications.success('Motion stopped', description: message, key: key);
    case MotionPlaybackStatus.busy:
      notifications.warning('Robot busy', description: message, key: key);
    case MotionPlaybackStatus.unavailable:
      notifications.warning('Not available', description: message, key: key);
    case MotionPlaybackStatus.error:
      notifications.error(
        'Motion command failed',
        description: message,
        key: key,
      );
    case MotionPlaybackStatus.idle:
    case MotionPlaybackStatus.paused:
      notifications.info(message, key: key);
  }
}
