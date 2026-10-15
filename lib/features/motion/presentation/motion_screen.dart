import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/core/theme/app_spacing.dart';
import 'package:robot_control_app/features/motion/application/motion_state.dart';
import 'package:robot_control_app/features/motion/presentation/motion_notifications.dart';
import 'package:robot_control_app/shared/notifications/app_notification.dart';
import 'package:robot_control_app/shared/notifications/app_notification_service.dart';

part 'motion_widgets.dart';

const _backgroundTop = Color(0xFFFBFCFF);
const _backgroundBottom = Color(0xFFF0F3FF);
const _surface = Color(0xF2FFFFFF);
const _ink = Color(0xFF171A35);
const _body = Color(0xFF404867);
const _muted = Color(0xFF75809F);
const _outline = Color(0x80D7DCEF);
const _purple = Color(0xFF6F2CF4);
const _purpleSoft = Color(0xFFF0EBFF);
const _green = Color(0xFF0BA968);
const _greenSoft = Color(0xFFE8F8F1);
const _red = Color(0xFFED3155);
const _redSoft = Color(0xFFFFEBEF);
const _amber = Color(0xFFF5A400);

class MotionScreen extends ConsumerWidget {
  const MotionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(motionProvider.select((state) => state.commandMessage), (
      _,
      next,
    ) {
      if (next != null) {
        notifyMotionCommand(
          ref.read(appNotificationsProvider.notifier),
          ref.read(motionProvider),
        );
      }
    });
    final state = ref.watch(motionProvider);
    final controller = ref.read(motionProvider.notifier);
    return DecoratedBox(
      key: const Key('motion-screen'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_backgroundTop, _backgroundBottom],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            constraints.maxWidth < 600 ? 12 : 16,
            constraints.maxWidth < 600 ? 14 : 18,
            constraints.maxWidth < 600 ? 12 : 16,
            AppSpacing.lg,
          ),
          child: _MotionPage(
            state: state,
            controller: controller,
            width: constraints.maxWidth,
          ),
        ),
      ),
    );
  }
}
