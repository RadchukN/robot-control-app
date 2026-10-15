import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  const AppConfig({
    required this.apiUrl,
    required this.debugMode,
    required this.applicationName,
    required this.version,
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
        apiUrl: String.fromEnvironment(
          'API_URL',
          defaultValue: 'http://127.0.0.1:8000',
        ),
        debugMode: bool.fromEnvironment(
          'DEBUG_MODE',
          defaultValue: kDebugMode,
        ),
        applicationName: String.fromEnvironment(
          'APP_NAME',
          defaultValue: 'Robot Control',
        ),
        version: String.fromEnvironment(
          'APP_VERSION',
          defaultValue: '0.1.0',
        ),
      );

  final String apiUrl;
  final bool debugMode;
  final String applicationName;
  final String version;
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
  name: 'AppConfigProvider',
);
