import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/app.dart';
import 'package:robot_control_app/core/routing/app_router.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';
import 'package:robot_control_app/features/vision/application/vision_state.dart';
import 'package:robot_control_app/services/robot_service.dart';

import 'fixture_api_client.dart';

void main() {
  testWidgets('Vision route fits the Figma reference viewports', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [
      Size(390, 844),
      Size(768, 1024),
      Size(1440, 960),
      Size(1920, 1080),
    ]) {
      await tester.binding.setSurfaceSize(size);
      final container = ProviderContainer(
        overrides: [
          robotServiceProvider.overrideWithValue(
            RobotService(FixtureApiClient()),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RobotControlApp(),
        ),
      );
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go(AppRoutes.vision);
      await tester.pump();

      expect(find.byKey(const Key('vision-screen')), findsOneWidget);
      expect(find.text('Connecting to G1 camera...'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('vision-camera-viewport')),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull, reason: 'Viewport: $size');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
    }
  });

  test('Vision rejects unsupported depth mode with empty initial data', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final initialState = container.read(visionControllerProvider);
    expect(initialState.detections, isEmpty);
    expect(initialState.cameraInfo, isNull);
    expect(initialState.perceptionModel, isNull);
    expect(initialState.inferenceLatency, isNull);

    final accepted = container
        .read(visionControllerProvider.notifier)
        .selectMode(VisionMode.depth);

    expect(accepted, isFalse);
    expect(container.read(visionControllerProvider).activeMode, VisionMode.rgb);
  });
}
