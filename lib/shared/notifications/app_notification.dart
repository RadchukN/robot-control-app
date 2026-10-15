import 'package:flutter/widgets.dart';

/// Visual and timing variant of an [AppNotification].
enum AppNotificationType {
  success('Success', Duration(milliseconds: 3500)),
  info('Info', Duration(milliseconds: 4500)),
  warning('Warning', Duration(seconds: 7)),
  error('Error', Duration(seconds: 12)),
  unsaved('Unsaved', Duration(seconds: 6)),

  /// Unresolved robot safety condition: stays until acknowledged or resolved.
  critical('Safety', null),

  /// Ongoing work: stays until updated or dismissed.
  progress('In progress', null);

  const AppNotificationType(this.badge, this.defaultDuration);

  final String badge;

  /// Null means the notification never times out on its own.
  final Duration? defaultDuration;
}

@immutable
class AppNotificationAction {
  const AppNotificationAction(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;
}

@immutable
class AppNotification {
  const AppNotification({
    required this.key,
    required this.type,
    required this.title,
    this.description,
    this.badge,
    this.icon,
    this.action,
    this.duration,
    this.progress,
    this.repeatCount = 1,
  });

  /// Stable identity used for de-duplication and in-place updates.
  final String key;
  final AppNotificationType type;
  final String title;
  final String? description;

  /// Overrides the type's default badge label.
  final String? badge;
  final IconData? icon;
  final AppNotificationAction? action;

  /// Null means the notification is persistent.
  final Duration? duration;

  /// 0..1 for determinate progress; null shows an indeterminate bar.
  final double? progress;

  /// How many times this exact event was raised while visible or queued.
  final int repeatCount;

  String get badgeLabel => badge ?? type.badge;

  bool get isCritical => type == AppNotificationType.critical;

  /// Critical notifications are only removed by an explicit acknowledgement.
  bool get closable => !isCritical;

  bool sameContentAs(AppNotification other) =>
      type == other.type &&
      title == other.title &&
      description == other.description &&
      badge == other.badge &&
      progress == other.progress;

  AppNotification copyWith({int? repeatCount}) => AppNotification(
    key: key,
    type: type,
    title: title,
    description: description,
    badge: badge,
    icon: icon,
    action: action,
    duration: duration,
    progress: progress,
    repeatCount: repeatCount ?? this.repeatCount,
  );
}
