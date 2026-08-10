import 'package:robot_control_app/core/api/api_client.dart';

class FixtureApiClient implements ApiClient {
  final List<String> requests = [];

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    requests.add(path);
    return switch (path) {
      '/health' => {'status': 'ok', 'service': 'robot-control-api'},
      '/runtime/status' => {
        'status': 'running',
        'running': true,
        'pid': 4242,
        'uptime_seconds': 12.5,
        'exit_code': null,
      },
      '/runtime/project' => {
        'name': 'medza',
        'version': '1.2.3',
        'root_path': r'C:\dev\robot-control\unitree_g1',
        'python_version': '3.12',
      },
      '/motion/summary' => {
        'total': 7,
        'enabled': 6,
        'disabled': 1,
        'categories': [
          {'name': 'motion-files', 'count': 7},
        ],
      },
      _ => throw StateError('Unexpected object endpoint: $path'),
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getJsonList(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    requests.add(path);
    if (path != '/services') {
      throw StateError('Unexpected list endpoint: $path');
    }
    return [
      _service('system', 0),
      _service('motion', 7),
      _service('audio', 4),
      _service('vision', 3),
      _service('dialog', 2),
      _service('controller', 1),
    ];
  }

  Map<String, dynamic> _service(String name, int count) => {
    'service': name,
    'health': {
      'service': name,
      'healthy': true,
      'status': 'healthy',
      'detail': null,
    },
    'status': {
      'service': name,
      'status': 'available',
      'version': '1.2.3',
      'metadata': <String, dynamic>{},
    },
    'capability_count': count,
  };
}
