import 'package:robot_control_app/models/health_response.dart';
import 'package:robot_control_app/models/motion_summary.dart';
import 'package:robot_control_app/models/project_manifest.dart';
import 'package:robot_control_app/models/runtime_status_response.dart';
import 'package:robot_control_app/models/service_info.dart';

class DashboardData {
  const DashboardData({
    required this.health,
    required this.runtime,
    required this.project,
    required this.services,
    required this.motionSummary,
    required this.updatedAt,
  });

  final HealthResponse health;
  final RuntimeStatusResponse runtime;
  final ProjectManifest project;
  final List<ServiceInfo> services;
  final MotionSummary motionSummary;
  final DateTime updatedAt;

  int capabilityCount(String serviceName) {
    for (final service in services) {
      if (service.service == serviceName) {
        return service.capabilityCount;
      }
    }
    return 0;
  }

  int get audioCount => capabilityCount('audio');
  int get visionCount => capabilityCount('vision');
  int get controllerCount => capabilityCount('controller');
}
