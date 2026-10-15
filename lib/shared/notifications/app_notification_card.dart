import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robot_control_app/shared/notifications/app_notification.dart';

/// Colors for one notification variant, tuned to the PilsLab palette.
@immutable
class AppNotificationTone {
  const AppNotificationTone({
    required this.accent,
    required this.badgeBackground,
    required this.border,
    required this.surface,
    required this.title,
    required this.body,
  });

  final Color accent;
  final Color badgeBackground;
  final Color border;
  final Color surface;
  final Color title;
  final Color body;

  static AppNotificationTone of(
    AppNotificationType type,
    Brightness brightness,
  ) {
    final dark = brightness == Brightness.dark;
    final accent = switch (type) {
      AppNotificationType.success => const Color(0xFF12A150),
      AppNotificationType.error => const Color(0xFFE5364F),
      AppNotificationType.warning => const Color(0xFFE07B12),
      AppNotificationType.info => const Color(0xFF2F6BEA),
      AppNotificationType.unsaved => const Color(0xFF8B3BF0),
      AppNotificationType.critical => const Color(0xFFD7263D),
      AppNotificationType.progress => const Color(0xFF6B7491),
    };
    final critical = type == AppNotificationType.critical;
    if (dark) {
      return AppNotificationTone(
        accent: Color.lerp(accent, Colors.white, 0.25)!,
        badgeBackground: accent.withValues(alpha: 0.2),
        border: accent.withValues(alpha: critical ? 0.75 : 0.45),
        surface: critical ? const Color(0xFF2A1A22) : const Color(0xFF1C1F2E),
        title: critical ? const Color(0xFFFFB3BD) : const Color(0xFFF1F2F8),
        body: const Color(0xFFB5BACB),
      );
    }
    return AppNotificationTone(
      accent: accent,
      badgeBackground: accent.withValues(alpha: 0.12),
      border: accent.withValues(alpha: critical ? 0.6 : 0.35),
      surface: critical ? const Color(0xFFFFF7F8) : const Color(0xFFFDFDFF),
      title: critical ? const Color(0xFF9E1328) : const Color(0xFF2A2F45),
      body: const Color(0xFF6B7491),
    );
  }
}

class AppNotificationCard extends StatelessWidget {
  const AppNotificationCard({
    super.key,
    required this.notification,
    required this.onDismiss,
    this.onAction,
  });

  final AppNotification notification;
  final VoidCallback onDismiss;

  /// Invoked when the action button is pressed, after the action's callback.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final tone = AppNotificationTone.of(n.type, Theme.of(context).brightness);
    final critical = n.isCritical;
    final action = n.action;
    final semanticsLabel = [
      n.badgeLabel,
      n.title,
      if (n.description != null) n.description!,
    ].join('. ');

    final card = Container(
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.border, width: critical ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: (critical ? tone.accent : const Color(0xFF2E2767))
                .withValues(alpha: critical ? 0.14 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Badge, title and description are announced once through
              // the card's label below.
              // Takes all free space so the close button sits at the edge.
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ExcludeSemantics(
                    child: _Badge(notification: n, tone: tone),
                  ),
                ),
              ),
              if (n.closable)
                SizedBox.square(
                  dimension: 28,
                  child: IconButton(
                    key: const Key('app-notification-close'),
                    tooltip: 'Dismiss notification',
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    onPressed: onDismiss,
                    icon: Icon(Icons.close_rounded, color: tone.body),
                  ),
                )
              else
                const SizedBox(height: 28),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 6),
            child: Text(
              n.title,
              semanticsLabel: '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                fontWeight: critical ? FontWeight.w700 : FontWeight.w600,
                color: tone.title,
              ),
            ),
          ),
          if (n.description != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 6),
              child: Text(
                n.description!,
                semanticsLabel: '',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 18 / 12.5,
                  color: tone.body,
                ),
              ),
            ),
          if (n.type == AppNotificationType.progress)
            Padding(
              padding: const EdgeInsets.only(top: 12, right: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  key: const Key('app-notification-progress'),
                  value: n.progress,
                  minHeight: 4,
                  color: const Color(0xFF6F2CF4),
                  backgroundColor: tone.badgeBackground,
                ),
              ),
            ),
          if (action != null || critical)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (action != null)
                    TextButton(
                      key: const Key('app-notification-action'),
                      style: TextButton.styleFrom(
                        foregroundColor: tone.accent,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        action.onPressed();
                        onAction?.call();
                      },
                      child: Text(action.label),
                    ),
                  if (critical)
                    FilledButton.tonal(
                      key: const Key('app-notification-acknowledge'),
                      style: FilledButton.styleFrom(
                        backgroundColor: tone.badgeBackground,
                        foregroundColor: tone.accent,
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(0, 36),
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: onDismiss,
                      child: const Text('Acknowledge'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );

    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticsLabel,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): onDismiss},
        child: FocusTraversalGroup(
          child: Material(type: MaterialType.transparency, child: card),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.notification, required this.tone});

  final AppNotification notification;
  final AppNotificationTone tone;

  @override
  Widget build(BuildContext context) {
    final icon =
        notification.icon ??
        (notification.isCritical ? Icons.shield_outlined : null);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tone.badgeBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: tone.accent),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              notification.badgeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 15 / 11.5,
                fontWeight: FontWeight.w600,
                color: tone.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
