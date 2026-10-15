class HealthResponse {
  const HealthResponse({required this.status, required this.service});

  factory HealthResponse.fromJson(Map<String, dynamic> json) => HealthResponse(
    status: json['status'] as String,
    service: json['service'] as String,
  );

  final String status;
  final String service;

  bool get isHealthy => status == 'ok';
}
