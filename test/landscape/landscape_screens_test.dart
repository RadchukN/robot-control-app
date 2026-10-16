import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';

import 'landscape_harness.dart';

const _routes = {
  'Dashboard': AppRoutes.dashboard,
  'Motion': AppRoutes.motion,
  'Vision': AppRoutes.vision,
  'AI Workspace': AppRoutes.aiWorkspace,
  'AI Voice Studio': AppRoutes.voiceStudio,
  'Settings': AppRoutes.settings,
};

void main() {
  setUpAll(loadRealFonts);

  for (final MapEntry(key: name, value: route) in _routes.entries) {
    testWidgets('$name fits every phone landscape viewport', (tester) async {
      final failures = <String>[];
      for (final size in landscapePhones) {
        for (final textScale in const [1.0, 1.3]) {
          setPhoneView(
            tester,
            size,
            padding: notchPadding,
            textScale: textScale,
          );
          final robot = RecordingRobot();
          final errors = await layoutErrors(() async {
            await pumpApp(tester, route: route, robot: robot);
          });
          for (final error in errors.toSet()) {
            failures.add('$size x$textScale: $error');
          }
          expect(robot.motionCalls, isEmpty, reason: 'layout sent motion');
          expect(robot.sentAudioFrames, isEmpty, reason: 'layout sent audio');
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  }
}
