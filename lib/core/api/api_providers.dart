import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/core/api/api_client.dart';
import 'package:robot_control_app/core/config/app_config.dart';
import 'package:robot_control_app/core/constants/app_constants.dart';

final apiClientProvider = Provider<ApiClient>(
  (ref) {
    final config = ref.watch(appConfigProvider);
    final dio = Dio(
      BaseOptions(
        baseUrl: config.apiUrl,
        connectTimeout: AppConstants.requestTimeout,
        receiveTimeout: AppConstants.requestTimeout,
        sendTimeout: AppConstants.requestTimeout,
        headers: const {'Accept': 'application/json'},
      ),
    );
    if (config.debugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: false),
      );
    }
    ref.onDispose(() => dio.close());
    return ApiClient(dio);
  },
  name: 'ApiClientProvider',
);
