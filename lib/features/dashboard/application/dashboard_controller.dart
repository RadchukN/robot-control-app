import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/features/dashboard/dashboard_failure.dart';
import 'package:robot_control_app/models/dashboard_data.dart';
import 'package:robot_control_app/models/health_response.dart';
import 'package:robot_control_app/models/motion_summary.dart';
import 'package:robot_control_app/models/project_manifest.dart';
import 'package:robot_control_app/models/runtime_status_response.dart';
import 'package:robot_control_app/models/service_info.dart';
import 'package:robot_control_app/services/robot_service.dart';

const dashboardRefreshInterval = Duration(seconds: 10);

class DashboardController extends AsyncNotifier<DashboardData> {
  Timer? _refreshTimer;
  bool _refreshing = false;

  @override
  Future<DashboardData> build() async {
    _refreshTimer = Timer.periodic(
      dashboardRefreshInterval,
      (_) => refresh(showLoading: false),
    );
    ref.onDispose(() => _refreshTimer?.cancel());
    return _fetchDashboard();
  }

  Future<void> refresh({bool showLoading = true}) async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    if (showLoading) {
      state = const AsyncLoading();
    }
    state = await AsyncValue.guard(_fetchDashboard);
    _refreshing = false;
  }

  Future<DashboardData> _fetchDashboard() async {
    try {
      final service = ref.read(robotServiceProvider);
      final responses = await Future.wait<Object>([
        service.health(),
        service.runtimeStatus(),
        service.project(),
        service.services(),
        service.motionSummary(),
      ]);
      return DashboardData(
        health: responses[0] as HealthResponse,
        runtime: responses[1] as RuntimeStatusResponse,
        project: responses[2] as ProjectManifest,
        services: responses[3] as List<ServiceInfo>,
        motionSummary: responses[4] as MotionSummary,
        updatedAt: DateTime.now(),
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(DashboardFailure.from(error), stackTrace);
    }
  }
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardData>(
      DashboardController.new,
      name: 'DashboardControllerProvider',
    );
