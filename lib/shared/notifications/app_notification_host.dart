import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/shared/notifications/app_notification.dart';
import 'package:robot_control_app/shared/notifications/app_notification_card.dart';
import 'package:robot_control_app/shared/notifications/app_notification_service.dart';

/// Where notifications float. Defaults keep cards below the app header.
@immutable
class AppNotificationPlacement {
  const AppNotificationPlacement({
    this.desktopMargin = const EdgeInsets.fromLTRB(16, 100, 20, 16),
    this.compactMargin = const EdgeInsets.fromLTRB(12, 82, 12, 12),
    this.compactBreakpoint = 600,
    this.maxWidth = 400,
    this.spacing = 10,
  });

  final EdgeInsets desktopMargin;
  final EdgeInsets compactMargin;
  final double compactBreakpoint;
  final double maxWidth;
  final double spacing;
}

/// Mounts the notification layer once, above every route, without taking
/// part in page layout. Place it in `MaterialApp.builder`.
class AppNotificationHost extends StatefulWidget {
  const AppNotificationHost({
    super.key,
    required this.child,
    this.placement = const AppNotificationPlacement(),
  });

  final Widget child;
  final AppNotificationPlacement placement;

  @override
  State<AppNotificationHost> createState() => _AppNotificationHostState();
}

class _AppNotificationHostState extends State<AppNotificationHost> {
  // A private Overlay gives tooltips and ink a home above the router.
  late final OverlayEntry _entry = OverlayEntry(
    builder: (_) => FocusScope(
      node: _scope,
      child: _NotificationLayer(
        placement: widget.placement,
        onEmpty: _restoreFocus,
      ),
    ),
  );

  /// Notifications sit outside the router's focus scope, so Tab alone never
  /// reaches them. F6 (the Windows "next pane" key) moves focus into the
  /// stack and back to where it was.
  final _scope = FocusScopeNode(debugLabel: 'AppNotifications');
  FocusNode? _returnFocus;

  /// Returns focus to where it was before F6, e.g. when the last card the
  /// user was on is dismissed.
  void _restoreFocus() {
    if (!_scope.hasFocus) return;
    final target = _returnFocus;
    _returnFocus = null;
    if (target != null && target.context != null) {
      target.requestFocus();
    } else {
      _scope.unfocus();
    }
  }

  @override
  void initState() {
    super.initState();
    // Global so F6 works even before anything in the app has focus.
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.f6 ||
        !mounted) {
      return false;
    }
    _toggleFocus();
    return true;
  }

  void _toggleFocus() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary != _scope && _scope.hasFocus) {
      _restoreFocus();
      return;
    }
    final first = _scope.traversalDescendants.firstOrNull;
    if (first == null) return;
    _returnFocus = FocusManager.instance.primaryFocus;
    first.requestFocus();
  }

  @override
  void didUpdateWidget(AppNotificationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement) _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry
      ..remove()
      ..dispose();
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      Positioned.fill(
        child: Overlay(
          key: const Key('app-notification-overlay'),
          initialEntries: [_entry],
        ),
      ),
    ],
  );
}

class _NotificationLayer extends ConsumerStatefulWidget {
  const _NotificationLayer({required this.placement, required this.onEmpty});

  final AppNotificationPlacement placement;
  final VoidCallback onEmpty;

  @override
  ConsumerState<_NotificationLayer> createState() => _NotificationLayerState();
}

class _NotificationLayerState extends ConsumerState<_NotificationLayer> {
  late final AppNotificationService _service;

  @override
  void initState() {
    super.initState();
    _service = ref.read(appNotificationsProvider.notifier)..attachHost();
  }

  @override
  void dispose() {
    // Stops every countdown so no timer outlives the overlay.
    _service.detachHost();
    super.dispose();
  }

  /// Cards removed from the service, kept briefly for their exit animation.
  /// Value: the card and its last on-screen index, so it exits in place.
  final _leaving = <String, (AppNotification, int)>{};

  @override
  Widget build(BuildContext context) {
    ref.listen(appNotificationsProvider, (previous, next) {
      final remaining = {for (final n in next.visible) n.key};
      if (remaining.isEmpty) widget.onEmpty();
      final before = previous?.visible ?? const <AppNotification>[];
      final removed = [
        for (var i = 0; i < before.length; i++)
          if (!remaining.contains(before[i].key)) (before[i], i),
      ];
      if (removed.isEmpty && !_leaving.keys.any(remaining.contains)) return;
      setState(() {
        _leaving.removeWhere((key, _) => remaining.contains(key));
        for (final entry in removed) {
          _leaving[entry.$1.key] = entry;
        }
      });
    });
    final visible = ref.watch(
      appNotificationsProvider.select((s) => s.visible),
    );
    final service = _service;
    final media = MediaQuery.of(context);
    final placement = widget.placement;
    final compact = media.size.width < placement.compactBreakpoint;
    final margin = compact ? placement.compactMargin : placement.desktopMargin;
    final items = [for (final n in visible) (n, false)];
    final exiting = _leaving.values.toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    for (final (n, index) in exiting) {
      items.insert(index.clamp(0, items.length), (n, true));
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(
        top: media.padding.top + margin.top,
        left: media.padding.left + margin.left,
        right: media.padding.right + margin.right,
      ),
      child: Align(
        alignment: compact ? Alignment.topCenter : Alignment.topRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: compact ? double.infinity : placement.maxWidth,
          ),
          child: SingleChildScrollView(
            // Never covers more than the free viewport; scrolls if it must.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (notification, leaving) in items)
                  _AnimatedNotification(
                    key: ValueKey(notification.key),
                    leaving: leaving,
                    spacing: placement.spacing,
                    onExited: () {
                      if (mounted) {
                        setState(() => _leaving.remove(notification.key));
                      }
                    },
                    child: MouseRegion(
                      onEnter: (_) => service.hold(notification.key),
                      onExit: (_) => service.release(notification.key),
                      child: Focus(
                        canRequestFocus: false,
                        skipTraversal: true,
                        onFocusChange: (focused) => focused
                            ? service.hold(notification.key)
                            : service.release(notification.key),
                        child: AppNotificationCard(
                          notification: notification,
                          onDismiss: () => service.dismiss(notification.key),
                          onAction: () => service.dismiss(notification.key),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedNotification extends StatefulWidget {
  const _AnimatedNotification({
    super.key,
    required this.child,
    required this.leaving,
    required this.spacing,
    required this.onExited,
  });

  final Widget child;
  final bool leaving;
  final double spacing;
  final VoidCallback onExited;

  @override
  State<_AnimatedNotification> createState() => _AnimatedNotificationState();
}

class _AnimatedNotificationState extends State<_AnimatedNotification>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 220);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.status == AnimationStatus.dismissed && !widget.leaving) {
      if (MediaQuery.of(context).disableAnimations) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void didUpdateWidget(_AnimatedNotification oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.leaving && !oldWidget.leaving) {
      if (MediaQuery.of(context).disableAnimations) {
        // Never setState on the parent while it is building.
        WidgetsBinding.instance.addPostFrameCallback((_) => widget.onExited());
      } else {
        _controller.reverse().whenCompleteOrCancel(widget.onExited);
      }
    } else if (!widget.leaving && oldWidget.leaving) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizeTransition(
    sizeFactor: _curve,
    alignment: Alignment.topCenter,
    child: FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0.06, -0.04),
          end: Offset.zero,
        ).animate(_curve),
        child: Padding(
          padding: EdgeInsets.only(bottom: widget.spacing),
          child: IgnorePointer(ignoring: widget.leaving, child: widget.child),
        ),
      ),
    ),
  );
}
