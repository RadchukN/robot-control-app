import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/features/dashboard/dashboard_failure.dart';
import 'package:robot_control_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:robot_control_app/models/health_response.dart';
import 'package:robot_control_app/models/motion_summary.dart';
import 'package:robot_control_app/models/project_manifest.dart';
import 'package:robot_control_app/models/runtime_status_response.dart';
import 'package:robot_control_app/services/robot_service.dart';

import 'fixture_api_client.dart';

void main() {
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

  testWidgets('Dashboard renders live data and refreshes automatically', (
    tester,
  ) async {
    final client = FixtureApiClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          robotServiceProvider.overrideWithValue(RobotService(client)),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Online'), findsOneWidget);
    expect(find.text('running'), findsOneWidget);
    expect(find.text('medza'), findsOneWidget);
    expect(find.text('1.2.3'), findsOneWidget);
    expect(find.text('3.12'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Motion'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Motion'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Vision'), findsOneWidget);
    expect(find.text('Controller'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Services'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Services'), findsOneWidget);
    expect(client.requests.where((path) => path == '/health').length, 1);

    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(client.requests.where((path) => path == '/health').length, 2);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
