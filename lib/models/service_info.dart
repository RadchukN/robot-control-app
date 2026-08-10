class ServiceHealth {
  const ServiceHealth({
    required this.service,
    required this.healthy,
    required this.status,
    this.detail,
  });

  factory ServiceHealth.fromJson(Map<String, dynamic> json) => ServiceHealth(
    service: json['service'] as String,
    healthy: json['healthy'] as bool,
    status: json['status'] as String,
    detail: json['detail'] as String?,
  );

  final String service;
  final bool healthy;
  final String status;
  final String? detail;
}

class ServiceStatus {
  const ServiceStatus({
    required this.service,
    required this.status,
    this.version,
    this.metadata = const {},
  });

  factory ServiceStatus.fromJson(Map<String, dynamic> json) => ServiceStatus(
    service: json['service'] as String,
    status: json['status'] as String,
    version: json['version'] as String?,
    metadata: Map<String, dynamic>.from(
      json['metadata'] as Map<String, dynamic>? ?? const {},
    ),
  );

  final String service;
  final String status;
  final String? version;
  final Map<String, dynamic> metadata;
}

class ServiceInfo {
  const ServiceInfo({
    required this.service,
    required this.health,
    required this.status,
    required this.capabilityCount,
  });

  factory ServiceInfo.fromJson(Map<String, dynamic> json) => ServiceInfo(
    service: json['service'] as String,
    health: ServiceHealth.fromJson(json['health'] as Map<String, dynamic>),
    status: ServiceStatus.fromJson(json['status'] as Map<String, dynamic>),
    capabilityCount: json['capability_count'] as int,
  );

  final String service;
  final ServiceHealth health;
  final ServiceStatus status;
  final int capabilityCount;
}
