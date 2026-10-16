import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';

import 'landscape_harness.dart';

const _shell = 'app_navigation_shell.dart';

const _branches = {
  0: 'Dashboard',
  5: 'AI Workspace',
  1: 'Motion',
  6: 'AI Voice Studio',
  3: 'Vision',
  4: 'Settings',
};

Matcher _selectedTab(String label) => isSemantics(
  label: label,
  isButton: true,
  isSelected: true,
  hasTapAction: true,
);

void main() {
  testWidgets('landscape phones get the rail, not the desktop chrome', (
    tester,
  ) async {
    for (final size in landscapePhones) {
      setPhoneView(tester, size, padding: notchPadding);
      final errors = await layoutErrors(
        () => pumpApp(tester, route: AppRoutes.settings),
      );
      expect(errorsIn(errors, _shell), isEmpty, reason: '$size');
      expect(find.byKey(const Key('landscape-shell')), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing, reason: '$size');
      expect(find.byKey(const Key('global-search-trigger')), findsNothing);
      for (final branch in _branches.keys) {
        expect(
          find.byKey(Key('landscape-nav-$branch')),
          findsOneWidget,
          reason: '$size branch $branch',
        );
      }
      // The unfinished Audio page is hidden from navigation.
      expect(find.byKey(const Key('landscape-nav-2')), findsNothing);
      expectTappable(
        tester,
        find.byKey(const Key('landscape-stop')),
        reason: '$size',
      );
      expectTappable(
        tester,
        find.byKey(const Key('landscape-robot-status')),
        reason: '$size',
      );
      // The rail paints under the notch; its controls clear it.
      final rail = tester.getRect(find.byKey(const Key('landscape-rail')));
      final stop = tester.getRect(find.byKey(const Key('landscape-stop')));
      expect(rail.left, 0);
      expect(stop.left, greaterThanOrEqualTo(notchPadding.left));
      expect(stop.bottom, lessThanOrEqualTo(size.height - notchPadding.bottom));
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('every destination opens from the rail', (tester) async {
    final semantics = tester.ensureSemantics();
    setPhoneView(tester, const Size(844, 390), padding: notchPadding);
    await layoutErrors(() async {
      await pumpApp(tester, route: AppRoutes.dashboard);
      for (final MapEntry(key: branch, value: label) in _branches.entries) {
        final tile = find.byKey(Key('landscape-nav-$branch'));
        await tester.ensureVisible(tile);
        await settle(tester);
        await tester.tap(tile);
        await settle(tester);
        expect(tester.getSemantics(tile), _selectedTab(label), reason: label);
      }
    });
    semantics.dispose();
  });

  testWidgets('rail survives 2x text and keeps Stop reachable', (tester) async {
    for (final size in landscapePhones) {
      setPhoneView(tester, size, padding: notchPadding, textScale: 2);
      final errors = await layoutErrors(
        () => pumpApp(tester, route: AppRoutes.settings),
      );
      expect(errorsIn(errors, _shell), isEmpty, reason: '$size');
      expectTappable(tester, find.byKey(const Key('landscape-stop')));
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('rail Stop uses the motion controller and sends one Stop', (
    tester,
  ) async {
    setPhoneView(tester, const Size(740, 360), padding: notchPadding);
    final robot = RecordingRobot();
    await layoutErrors(() async {
      await pumpApp(tester, route: AppRoutes.vision, robot: robot);
      expect(robot.motionCalls, isEmpty);

      await tester.tap(find.byKey(const Key('landscape-stop')));
      // The recorder never answers, so Stop stays pending ("Stopping…").
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Stopping…'), findsOneWidget);
    });

    expect(robot.motionCalls, ['stop_motion']);
    expect(robot.sentAudioFrames, isEmpty);
  });

  testWidgets('robot status reflects the live link and opens Settings', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    setPhoneView(tester, const Size(844, 390));
    await layoutErrors(() async {
      await pumpApp(tester, route: AppRoutes.dashboard);
      expect(
        find.byKey(const Key('landscape-link-disconnected')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('landscape-robot-status')));
      await settle(tester);
    });
    expect(
      tester.getSemantics(find.byKey(const Key('landscape-nav-4'))),
      _selectedTab('Settings'),
    );
    semantics.dispose();
  });

  testWidgets('desktop and portrait reference viewports keep their shell', (
    tester,
  ) async {
    for (final size in const [
      Size(1440, 960),
      Size(1792, 920),
      Size(1024, 768),
      Size(768, 1024),
      Size(390, 844),
    ]) {
      setPhoneView(tester, size);
      await layoutErrors(() => pumpApp(tester, route: AppRoutes.settings));
      expect(
        find.byKey(const Key('landscape-shell')),
        findsNothing,
        reason: '$size',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
