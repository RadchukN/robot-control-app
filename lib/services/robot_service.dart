import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/core/api/api_client.dart';
import 'package:robot_control_app/core/api/api_providers.dart';

class RobotService {
  const RobotService(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> health() => _apiClient.getJson('/health');

  Future<Map<String, dynamic>> runtime() => _apiClient.getJson('/runtime/info');

  Future<Map<String, dynamic>> project() => _apiClient.getJson('/runtime/project');

  Future<List<Map<String, dynamic>>> services() => _apiClient.getJsonList('/services');

  Future<List<Map<String, dynamic>>> motions() => _apiClient.getJsonList('/motion');
}

final robotServiceProvider = Provider<RobotService>(
  (ref) => RobotService(ref.watch(apiClientProvider)),
  name: 'RobotServiceProvider',
);
