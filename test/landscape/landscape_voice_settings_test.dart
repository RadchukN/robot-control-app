import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';
import 'package:robot_control_app/features/settings/application/settings_state.dart';
import 'package:robot_control_app/features/voice_studio/application/voice_studio_providers.dart';

import 'landscape_harness.dart';

void main() {
  setUpAll(loadRealFonts);

  testWidgets('Voice Studio panels are one tap away and fit the screen', (
    tester,
  ) async {
    setPhoneView(tester, const Size(740, 360), padding: notchPadding);
    final robot = RecordingRobot();
    final errors = await layoutErrors(() async {
      await pumpApp(tester, route: AppRoutes.voiceStudio, robot: robot);
      for (final section in const [
        'transcript',
        'speech',
        'quickMotions',
        'connection',
        'conversation',
      ]) {
        final tile = find.byKey(Key('voice-section-$section'));
        await tester.ensureVisible(tile);
        expectTappable(tester, tile, reason: section);
        await tester.tap(tile);
        await settle(tester);
      }
    });
    expect(errors, isEmpty);
    expectTappable(tester, find.byKey(const Key('voice-start')));
    expect(robot.motionCalls, isEmpty);
    expect(robot.sentAudioFrames, isEmpty);
  });

  testWidgets('Stop AI stays reachable from every section during a demo '
      'conversation', (tester) async {
    setPhoneView(tester, const Size(844, 390), padding: notchPadding);
    final robot = RecordingRobot();
    final container = await pumpApp(
      tester,
      route: AppRoutes.voiceStudio,
      robot: robot,
    );
    // Demo Mode is the default; nothing reaches the robot.
    expect(container.read(voiceDemoModeProvider), isTrue);
    expect(find.byKey(const Key('voice-landscape-stop-ai')), findsNothing);

    await tester.tap(find.byKey(const Key('voice-start')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('voice-section-speech')));
    await settle(tester);
    expectTappable(tester, find.byKey(const Key('voice-landscape-stop-ai')));

    await tester.tap(find.byKey(const Key('voice-landscape-stop-ai')));
    await settle(tester);
    expect(find.byKey(const Key('voice-landscape-stop-ai')), findsNothing);
    expect(robot.motionCalls, isEmpty);
    expect(robot.sentAudioFrames, isEmpty);
  });

  testWidgets('Connectivity keeps robot connection and audio devices usable', (
    tester,
  ) async {
    for (final size in landscapePhones) {
      setPhoneView(tester, size, padding: notchPadding);
      final robot = RecordingRobot();
      final errors = await layoutErrors(() async {
        final container = await pumpApp(
          tester,
          route: AppRoutes.settings,
          robot: robot,
        );
        container
            .read(settingsProvider.notifier)
            .selectCategory(SettingsCategory.connectivity);
        await settle(tester);
        for (final key in const [
          'robot-ip-field',
          'robot-connect-button',
          'audio-devices-card',
          'audio-input-select',
          'audio-output-select',
        ]) {
          final finder = find.byKey(Key(key));
          await tester.ensureVisible(finder);
          await settle(tester);
          expect(finder.hitTestable(), findsOneWidget, reason: '$size $key');
        }
        // Open and close a device dropdown.
        final select = find.byKey(const Key('audio-input-select'));
        await tester.ensureVisible(select);
        await settle(tester);
        final routes = find.byType(Scrollable).evaluate().length;
        await tester.tap(select);
        await settle(tester);
        expect(
          find.byType(Scrollable).evaluate().length,
          greaterThan(routes),
          reason: '$size dropdown menu did not open',
        );
        await tester.tapAt(const Offset(4, 4));
        await settle(tester);
      });
      expect(errors, isEmpty, reason: '$size');
      expect(robot.motionCalls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('the robot address field stays visible above the keyboard', (
    tester,
  ) async {
    for (final size in landscapePhones) {
      final keyboard = (size.height * 0.5).roundToDouble();
      setPhoneView(tester, size, padding: notchPadding, keyboard: keyboard);
      final errors = await layoutErrors(() async {
        final container = await pumpApp(tester, route: AppRoutes.settings);
        container
            .read(settingsProvider.notifier)
            .selectCategory(SettingsCategory.connectivity);
        await settle(tester);
        final field = find.byKey(const Key('robot-ip-field'));
        await tester.ensureVisible(field);
        await tester.showKeyboard(field);
        await settle(tester);
        final rect = tester.getRect(field);
        expect(
          rect.bottom,
          lessThanOrEqualTo(size.height - keyboard),
          reason: '$size',
        );
        expect(rect.top, greaterThanOrEqualTo(0), reason: '$size');
      });
      expect(errors, isEmpty, reason: '$size');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
