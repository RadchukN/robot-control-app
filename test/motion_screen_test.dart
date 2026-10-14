import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/app.dart';
import 'package:robot_control_app/core/routing/app_router.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';
import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/features/motion/application/motion_state.dart';
import 'package:robot_control_app/models/dashboard_data.dart';
import 'package:robot_control_app/services/robot_service.dart';

import 'fixture_api_client.dart';

// These UI/local-editing tests must never connect to the live robot.
class _OfflineDashboardController extends DashboardController {
  @override
  Future<DashboardData> build() async =>
      DashboardData(updatedAt: DateTime(2026), telemetryConnected: true);

  @override
  Future<List<String>> getMotionCatalog() async => ['fake_hello.json'];
}

void main() {
  testWidgets('Motion route fits the approved reference viewports', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [
      Size(390, 844),
      Size(768, 1024),
      Size(1440, 960),
      Size(1792, 920),
    ]) {
      await tester.binding.setSurfaceSize(size);
      final container = ProviderContainer(
        overrides: [
          dashboardControllerProvider.overrideWith(
            _OfflineDashboardController.new,
          ),
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
      container.read(appRouterProvider).go(AppRoutes.motion);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('motion-screen')), findsOneWidget);
      expect(find.text('Quick gestures'), findsOneWidget);
      expect(find.textContaining('Saved motions'), findsOneWidget);
      expect(find.text('Motion status'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Viewport: $size');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
    }
  });

  test(
    'Motion controller supports local duplicate and record-save without commands',
    () async {
      final container = ProviderContainer(
        overrides: [
          dashboardControllerProvider.overrideWith(
            _OfflineDashboardController.new,
          ),
          robotServiceProvider.overrideWithValue(
            RobotService(FixtureApiClient()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(motionProvider.notifier);
      await pumpEventQueue();
      final initial = container.read(motionProvider);
      final selectedId = initial.selectedMotionId!;

      controller.duplicate(selectedId);
      final duplicated = container.read(motionProvider);
      expect(
        duplicated.savedMotions,
        hasLength(initial.savedMotions.length + 1),
      );
      expect(duplicated.selectedMotion?.name, 'fake_hello_copy.json');

      controller.setMotionName('local_wave');
      controller.setMotionCategory('Gesture');
      controller.startRecording();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      controller.stopRecording();
      expect(controller.saveRecording(), isTrue);

      final saved = container.read(motionProvider);
      expect(saved.savedMotions, hasLength(initial.savedMotions.length + 2));
      expect(saved.selectedMotion?.name, 'local_wave.json');
      expect(saved.selectedMotion?.type, 'Gesture');
      expect(saved.recording, isFalse);
    },
  );
}
