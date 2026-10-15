class RuntimeStatusResponse {
  const RuntimeStatusResponse({
    required this.status,
    required this.running,
    required this.uptimeSeconds,
    this.pid,
    this.exitCode,
  });

  factory RuntimeStatusResponse.fromJson(Map<String, dynamic> json) =>
      RuntimeStatusResponse(
        status: json['status'] as String,
        running: json['running'] as bool,
        pid: json['pid'] as int?,
        uptimeSeconds: (json['uptime_seconds'] as num).toDouble(),
        exitCode: json['exit_code'] as int?,
      );

  final String status;
  final bool running;
  final int? pid;
  final double uptimeSeconds;
  final int? exitCode;
}
