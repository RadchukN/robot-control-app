import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';

import 'landscape_harness.dart';

Map<String, dynamic> _dryRun(String action, String? motion) => {
  'type': 'motion_result',
  'action': action,
  'motion': ?motion,
  'status': 'dry_run',
  'dry_run': true,
};

void main() {
  setUpAll(loadRealFonts);

  testWidgets('Dashboard shows the robot overview in the first screenful', (
    tester,
  ) async {
    for (final size in landscapePhones) {
      setPhoneView(tester, size, padding: notchPadding);
      await layoutErrors(() => pumpApp(tester, route: AppRoutes.dashboard));
      expect(find.text('Telemetry'), findsOneWidget, reason: '$size');
      final overview = tester.getRect(find.text('Robot overview'));
      expect(overview.top, lessThan(size.height / 3), reason: '$size');
      expect(
        tester.getRect(find.text('Emergency stop')).bottom,
        lessThan(size.height),
        reason: '$size',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('Motion keeps Play, Stop and progress pinned on phones', (
    tester,
  ) async {
    for (final size in landscapePhones) {
      for (final textScale in const [1.0, 1.3]) {
        setPhoneView(tester, size, padding: notchPadding, textScale: textScale);
        await layoutErrors(() => pumpApp(tester, route: AppRoutes.motion));
        final reason = '$size x$textScale';
        expect(
          find.byKey(const Key('motion-playback-dock')),
          findsOneWidget,
          reason: reason,
        );
        expectTappable(
          tester,
          find.byKey(const Key('motion-dock-play')),
          reason: reason,
        );
        expectTappable(
          tester,
          find.byKey(const Key('motion-dock-stop')),
          reason: reason,
        );
        // Scroll the catalog to its end: the dock does not move.
        final stop = tester.getRect(find.byKey(const Key('motion-dock-stop')));
        await tester.drag(
          find.byKey(const Key('motion-landscape-scroll')),
          const Offset(0, -2000),
        );
        await settle(tester);
        expect(
          tester.getRect(find.byKey(const Key('motion-dock-stop'))),
          stop,
          reason: reason,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });

  testWidgets('the saved-motion list is part of the page scroll on phones', (
    tester,
  ) async {
    setPhoneView(tester, const Size(844, 390), padding: notchPadding);
    await layoutErrors(() => pumpApp(tester, route: AppRoutes.motion));
    final pageScroll = find.byKey(const Key('motion-landscape-scroll'));
    final nested = find.descendant(
      of: pageScroll,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    // Only the page itself scrolls vertically.
    expect(nested, findsOneWidget);
  });

  testWidgets('dock Stop sends one Stop through the motion controller', (
    tester,
  ) async {
    setPhoneView(tester, const Size(740, 360), padding: notchPadding);
    final robot = RecordingRobot();
    await layoutErrors(() async {
      await pumpApp(tester, route: AppRoutes.motion, robot: robot);
      await tester.tap(find.byKey(const Key('motion-dock-stop')));
      await settle(tester);
    });
    expect(robot.motionCalls, ['stop_motion']);
    expect(find.byKey(const Key('motion-physical-badge')), findsOneWidget);
  });

  testWidgets('a dry run is labelled differently from physical motion', (
    tester,
  ) async {
    setPhoneView(tester, const Size(844, 390), padding: notchPadding);
    final robot = RecordingRobot(reply: _dryRun);
    await layoutErrors(() async {
      await pumpApp(tester, route: AppRoutes.motion, robot: robot);
      expect(find.byKey(const Key('motion-dry-run-badge')), findsNothing);
      await tester.tap(find.byKey(const Key('motion-dock-play')));
      await settle(tester);
    });
    expect(robot.motionCalls, ['play_recorded_motion:fake_hello.json']);
    expect(find.byKey(const Key('motion-dry-run-badge')), findsOneWidget);
    expect(find.text('Dry run · robot did not move'), findsOneWidget);
    expect(find.byKey(const Key('motion-physical-badge')), findsNothing);
  });

  testWidgets('a command awaiting the robot shows physical motion', (
    tester,
  ) async {
    setPhoneView(tester, const Size(844, 390), padding: notchPadding);
    final robot = RecordingRobot();
    await layoutErrors(() async {
      await pumpApp(tester, route: AppRoutes.motion, robot: robot);
      await tester.tap(find.byKey(const Key('motion-dock-play')));
      await settle(tester);
    });
    expect(robot.motionCalls, hasLength(1));
    expect(find.byKey(const Key('motion-physical-badge')), findsOneWidget);
    expect(find.text('Physical motion on robot'), findsOneWidget);
    expect(find.byKey(const Key('motion-dry-run-badge')), findsNothing);
  });

  testWidgets('desktop Motion and Dashboard keep their layouts', (
    tester,
  ) async {
    for (final size in const [Size(1440, 960), Size(768, 1024)]) {
      setPhoneView(tester, size);
      await layoutErrors(() => pumpApp(tester, route: AppRoutes.motion));
      expect(find.byKey(const Key('motion-playback-dock')), findsNothing);
      expect(find.text('Playback controls'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
