import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/features/dashboard/dashboard_failure.dart';
import 'package:robot_control_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:robot_control_app/models/health_response.dart';
import 'package:robot_control_app/models/dashboard_data.dart';
import 'package:robot_control_app/models/motion_summary.dart';
import 'package:robot_control_app/models/project_manifest.dart';
import 'package:robot_control_app/models/runtime_status_response.dart';
import 'package:robot_control_app/services/robot_service.dart';

import 'fixture_api_client.dart';
import 'landscape/landscape_harness.dart'
    show RecordingRobot, loadRealFonts, layoutErrors;

class _DashboardFixture extends RecordingRobot {
  void receiveBattery(int percent) {
    state = AsyncData(
      DashboardData(
        updatedAt: DateTime(2026),
        telemetryConnected: true,
        telemetry: DashboardTelemetry(batterySoc: percent),
      ),
    );
  }
}

void main() {
  setUpAll(loadRealFonts);
  test(
    'RobotService parses every dashboard endpoint into typed models',
    () async {
      final client = FixtureApiClient();
      final service = RobotService(client);

      expect(await service.health(), isA<HealthResponse>());
      expect(await service.runtimeStatus(), isA<RuntimeStatusResponse>());
      expect(await service.project(), isA<ProjectManifest>());
      expect((await service.services()).length, 6);
      expect(await service.motionSummary(), isA<MotionSummary>());
      expect(client.requests, [
        '/health',
        '/runtime/status',
        '/runtime/project',
        '/services',
        '/motion/summary',
      ]);
    },
  );

  test('DashboardFailure classifies timeout and HTTP errors', () {
    final timeout = DashboardFailure.from(
      DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.receiveTimeout,
      ),
    );
    final http = DashboardFailure.from(
      DioException.badResponse(
        statusCode: 503,
        requestOptions: RequestOptions(),
        response: Response<void>(
          requestOptions: RequestOptions(),
          statusCode: 503,
        ),
      ),
    );

    expect(timeout.kind, DashboardFailureKind.timeout);
    expect(http.kind, DashboardFailureKind.http);
    expect(http.statusCode, 503);
  });

  testWidgets(
    'Dashboard renders the Figma sections and updates with telemetry',
    (tester) async {
      final client = FixtureApiClient();
      final controller = _DashboardFixture();
      final errors = await layoutErrors(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dashboardControllerProvider.overrideWith(() => controller),
              robotServiceProvider.overrideWithValue(RobotService(client)),
            ],
            child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.text('G1 Gustav'), findsOneWidget);
        expect(find.text('Connected'), findsOneWidget);
        expect(find.text('Safety unavailable'), findsOneWidget);
        expect(find.text('Safety nominal'), findsNothing);
        controller.receiveBattery(42);
        await tester.pumpAndSettle();
        expect(find.text('42%'), findsWidgets);
        await tester.scrollUntilVisible(
          find.text('Active mission'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Active mission'), findsOneWidget);
        expect(find.text('Quick actions'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Recent activity'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Recent activity'), findsOneWidget);
        // Telemetry updates the UI without the retired HTTP polling flow.
        expect(client.requests, isEmpty);

        await tester.pumpWidget(const SizedBox.shrink());
      });
      expect(errors, isEmpty);
    },
  );
}
