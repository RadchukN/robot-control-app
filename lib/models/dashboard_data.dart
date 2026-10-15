import 'package:robot_control_app/models/health_response.dart';
import 'package:robot_control_app/models/motion_summary.dart';
import 'package:robot_control_app/models/project_manifest.dart';
import 'package:robot_control_app/models/runtime_status_response.dart';
import 'package:robot_control_app/models/service_info.dart';

class DashboardData {
  const DashboardData({
    required this.updatedAt,
    this.health,
    this.runtime,
    this.project,
    this.services = const [],
    this.motionSummary,
    this.telemetry,
    this.telemetryConnected = false,
    this.telemetryHistory = const [],
  });

  final HealthResponse? health;
  final RuntimeStatusResponse? runtime;
  final ProjectManifest? project;
  final List<ServiceInfo> services;
  final MotionSummary? motionSummary;
  final DateTime updatedAt;
  final DashboardTelemetry? telemetry;
  final bool telemetryConnected;

  /// Up to 61 snapshots sampled about 5 seconds apart (5 minutes of history).
  /// Missing fields remain gaps in each series.
  final List<DashboardTelemetry> telemetryHistory;

  DashboardData copyWith({
    DashboardTelemetry? telemetry,
    bool? telemetryConnected,
    DateTime? updatedAt,
    List<DashboardTelemetry>? telemetryHistory,
  }) => DashboardData(
    health: health,
    runtime: runtime,
    project: project,
    services: services,
    motionSummary: motionSummary,
    updatedAt: updatedAt ?? this.updatedAt,
    telemetry: telemetry ?? this.telemetry,
    telemetryConnected: telemetryConnected ?? this.telemetryConnected,
    telemetryHistory: telemetryHistory ?? this.telemetryHistory,
  );

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

class DashboardTelemetry {
  const DashboardTelemetry({
    this.batterySoc,
    this.imuTemperature,
    this.batterySoh,
    this.maxBmsTemperature,
    this.maxMotorTemperature,
    this.activeMotorCount,
    this.networkType,
    this.networkInterface,
    this.networkSignalPercent,
  });

  factory DashboardTelemetry.fromJson(Map<String, dynamic> json) {
    final battery = json['battery'];
    final imu = json['imu'];
    final motors = json['motors'];
    final network = json['network'];
    num? number(dynamic value) => value is num && value.isFinite ? value : null;
    num? maximum(dynamic values) {
      if (values is! List) return null;
      num? result;
      for (final value in values) {
        final candidate = number(value);
        if (candidate != null && (result == null || candidate > result)) {
          result = candidate;
        }
      }
      return result;
    }

    final motorTemperatures = <num>[];
    final motorIndices = <int>{};
    if (motors is List) {
      for (final motor in motors) {
        if (motor is! Map<String, dynamic>) continue;
        final index = number(motor['index']);
        if (index == null || index < 0 || index != index.toInt()) continue;
        motorIndices.add(index.toInt());
        final temperature = maximum(motor['temperature']);
        if (temperature != null) motorTemperatures.add(temperature);
      }
    }
    return DashboardTelemetry(
      batterySoc: battery is Map<String, dynamic>
          ? number(battery['soc'])?.toInt()
          : null,
      imuTemperature: imu is Map<String, dynamic>
          ? number(imu['temperature'])
          : null,
      batterySoh: battery is Map<String, dynamic>
          ? number(battery['soh'])
          : null,
      maxBmsTemperature: battery is Map<String, dynamic>
          ? maximum(battery['temperatures'])
          : null,
      maxMotorTemperature: maximum(motorTemperatures),
      activeMotorCount: motors is List ? motorIndices.length : null,
      networkType: network is Map<String, dynamic> && network['type'] is String
          ? network['type'] as String
          : null,
      networkInterface:
          network is Map<String, dynamic> && network['interface'] is String
          ? network['interface'] as String
          : null,
      networkSignalPercent: network is Map<String, dynamic>
          ? number(network['signal_percent'])
          : null,
    );
  }

  final int? batterySoc;
  final num? imuTemperature;
  final num? batterySoh;
  final num? maxBmsTemperature;
  final num? maxMotorTemperature;

  /// Number of distinct motor indices reported in the telemetry snapshot.
  final int? activeMotorCount;
  final String? networkType;
  final String? networkInterface;
  final num? networkSignalPercent;
}
