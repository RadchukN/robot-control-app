import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/shared/notifications/app_notification.dart';

@immutable
class AppNotificationsState {
  const AppNotificationsState({
    this.visible = const [],
    this.queued = const [],
  });

  /// Shown on screen, top first. Critical notifications always lead.
  final List<AppNotification> visible;

  /// Waiting for a free slot, oldest first.
  final List<AppNotification> queued;
}

/// Application-wide notification queue.
///
/// Notifications are keyed: raising the same key again updates the existing
/// card in place (for example Connecting → Connected) instead of stacking a
/// duplicate. Without an explicit key, identical events share one card.
class AppNotificationService extends Notifier<AppNotificationsState> {
  static const maxVisible = 3;

  final _timers = <String, Timer>{};

  /// Mounted [AppNotificationHost]s. Countdowns only run while a card can
  /// actually be seen, and stop when the last host goes away.
  int _hosts = 0;

  bool get hasHost => _hosts > 0;

  void attachHost() {
    _hosts++;
    if (_hosts == 1) state.visible.forEach(_restartTimer);
  }

  void detachHost() {
    if (_hosts == 0) return;
    _hosts--;
    if (_hosts == 0) _cancelTimers();
  }

  void _cancelTimers() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  @override
  AppNotificationsState build() {
    ref.onDispose(_cancelTimers);
    return const AppNotificationsState();
  }

  String success(
    String title, {
    String? description,
    String? key,
    AppNotificationAction? action,
  }) => show(
    AppNotificationType.success,
    title,
    description: description,
    key: key,
    action: action,
  );

  String info(
    String title, {
    String? description,
    String? key,
    AppNotificationAction? action,
  }) => show(
    AppNotificationType.info,
    title,
    description: description,
    key: key,
    action: action,
  );

  String warning(
    String title, {
    String? description,
    String? key,
    AppNotificationAction? action,
  }) => show(
    AppNotificationType.warning,
    title,
    description: description,
    key: key,
    action: action,
  );

  String error(
    String title, {
    String? description,
    String? key,
    AppNotificationAction? action,
  }) => show(
    AppNotificationType.error,
    title,
    description: description,
    key: key,
    action: action,
  );

  String unsaved(String title, {String? description, String? key}) => show(
    AppNotificationType.unsaved,
    title,
    description: description,
    key: key,
  );

  /// A safety condition. It stays until [dismiss] (acknowledged by the user)
  /// or [resolve] (the condition cleared); it is never timed out or cleared by
  /// [dismissAll].
  String critical(
    String title, {
    String? description,
    String? key,
    AppNotificationAction? action,
  }) => show(
    AppNotificationType.critical,
    title,
    description: description,
    key: key,
    action: action,
  );

  String progress(
    String title, {
    String? description,
    String? key,
    double? value,
  }) => show(
    AppNotificationType.progress,
    title,
    description: description,
    key: key,
    progress: value,
  );

  /// Shows a notification or updates the one with the same [key].
  String show(
    AppNotificationType type,
    String title, {
    String? description,
    String? key,
    String? badge,
    IconData? icon,
    AppNotificationAction? action,
    Duration? duration,
    bool persistent = false,
    double? progress,
  }) {
    final resolvedKey = key ?? '${type.name}|$title|${description ?? ''}';
    var next = AppNotification(
      key: resolvedKey,
      type: type,
      title: title,
      description: description,
      badge: badge,
      icon: icon,
      action: action,
      duration: persistent ? null : duration ?? type.defaultDuration,
      progress: progress,
    );
    final visible = [...state.visible];
    final queued = [...state.queued];
    final visibleIndex = visible.indexWhere((n) => n.key == resolvedKey);
    final queuedIndex = queued.indexWhere((n) => n.key == resolvedKey);
    final existing = visibleIndex >= 0
        ? visible[visibleIndex]
        : queuedIndex >= 0
        ? queued[queuedIndex]
        : null;
    if (existing != null && existing.sameContentAs(next)) {
      next = next.copyWith(repeatCount: existing.repeatCount + 1);
    }

    if (visibleIndex >= 0) {
      visible[visibleIndex] = next;
      _commit(visible, queued);
      _restartTimer(next);
      return resolvedKey;
    }
    if (queuedIndex >= 0) queued.removeAt(queuedIndex);

    if (visible.length < maxVisible) {
      visible.insert(next.isCritical ? 0 : _firstNonCritical(visible), next);
    } else if (next.isCritical &&
        visible.any((notification) => !notification.isCritical)) {
      // Safety first: push the oldest regular card back to the queue.
      final displaced = visible.lastWhere((n) => !n.isCritical);
      visible.remove(displaced);
      _timers.remove(displaced.key)?.cancel();
      queued.insert(0, displaced);
      visible.insert(0, next);
    } else {
      // A queued critical waits ahead of regular messages.
      queued.insert(next.isCritical ? 0 : queued.length, next);
      _commit(visible, queued);
      return resolvedKey;
    }
    _commit(visible, queued);
    _restartTimer(next);
    return resolvedKey;
  }

  int _firstNonCritical(List<AppNotification> visible) {
    final index = visible.indexWhere((n) => !n.isCritical);
    return index < 0 ? visible.length : index;
  }

  /// Removes a notification, including an acknowledged critical one.
  void dismiss(String key) {
    _timers.remove(key)?.cancel();
    final visible = state.visible.where((n) => n.key != key).toList();
    final queued = state.queued.where((n) => n.key != key).toList();
    if (visible.length == state.visible.length &&
        queued.length == state.queued.length) {
      return;
    }
    _promote(visible, queued);
  }

  /// The underlying condition cleared; same as [dismiss] but reads clearer
  /// at call sites that resolve a safety state.
  void resolve(String key) => dismiss(key);

  /// Clears everything except critical safety notifications.
  void dismissAll() {
    for (final notification in [...state.visible, ...state.queued]) {
      if (!notification.isCritical) _timers.remove(notification.key)?.cancel();
    }
    _promote(
      state.visible.where((n) => n.isCritical).toList(),
      state.queued.where((n) => n.isCritical).toList(),
    );
  }

  /// Pauses auto-dismiss while the pointer or focus is on a card.
  void hold(String key) => _timers.remove(key)?.cancel();

  /// Restarts the full timeout after [hold].
  void release(String key) {
    final notification = state.visible.where((n) => n.key == key).firstOrNull;
    if (notification != null && !_timers.containsKey(key)) {
      _restartTimer(notification);
    }
  }

  void _promote(List<AppNotification> visible, List<AppNotification> queued) {
    final promoted = <AppNotification>[];
    while (visible.length < maxVisible && queued.isNotEmpty) {
      final next = queued.removeAt(0);
      visible.insert(next.isCritical ? 0 : visible.length, next);
      promoted.add(next);
    }
    _commit(visible, queued);
    promoted.forEach(_restartTimer);
  }

  void _commit(List<AppNotification> visible, List<AppNotification> queued) =>
      state = AppNotificationsState(
        visible: List.unmodifiable(visible),
        queued: List.unmodifiable(queued),
      );

  void _restartTimer(AppNotification notification) {
    _timers.remove(notification.key)?.cancel();
    final duration = notification.duration;
    if (duration == null || notification.isCritical || !hasHost) return;
    _timers[notification.key] = Timer(
      duration,
      () => dismiss(notification.key),
    );
  }
}

final appNotificationsProvider =
    NotifierProvider<AppNotificationService, AppNotificationsState>(
      AppNotificationService.new,
      name: 'AppNotificationsProvider',
    );

/// Access from widgets that are not Riverpod consumers.
extension AppNotificationsContext on BuildContext {
  AppNotificationService get notifications => ProviderScope.containerOf(
    this,
    listen: false,
  ).read(appNotificationsProvider.notifier);
}
