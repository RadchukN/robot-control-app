import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/core/api/api_client.dart';
import 'package:robot_control_app/core/api/api_providers.dart';
import 'package:robot_control_app/models/health_response.dart';
import 'package:robot_control_app/models/motion_summary.dart';
import 'package:robot_control_app/models/project_manifest.dart';
import 'package:robot_control_app/models/runtime_status_response.dart';
import 'package:robot_control_app/models/service_info.dart';

class RobotService {
  const RobotService(this._apiClient);

  final ApiClient _apiClient;

  Future<HealthResponse> health() async =>
      HealthResponse.fromJson(await _apiClient.getJson('/health'));

  Future<RuntimeStatusResponse> runtimeStatus() async =>
      RuntimeStatusResponse.fromJson(
        await _apiClient.getJson('/runtime/status'),
      );

  Future<ProjectManifest> project() async =>
      ProjectManifest.fromJson(await _apiClient.getJson('/runtime/project'));

  Future<List<ServiceInfo>> services() async => (await _apiClient.getJsonList(
    '/services',
  )).map(ServiceInfo.fromJson).toList(growable: false);

  Future<MotionSummary> motionSummary() async =>
      MotionSummary.fromJson(await _apiClient.getJson('/motion/summary'));
}

final robotServiceProvider = Provider<RobotService>(
  (ref) => RobotService(ref.watch(apiClientProvider)),
  name: 'RobotServiceProvider',
);
