import 'dart:io';

import 'package:dio/dio.dart';
import 'package:robot_control_app/core/api/api_client.dart';

enum DashboardFailureKind { offline, timeout, http, invalidResponse, unknown }

class DashboardFailure implements Exception {
  const DashboardFailure({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  factory DashboardFailure.from(Object error) {
    if (error is DashboardFailure) {
      return error;
    }
    if (error is ApiFormatException ||
        error is TypeError ||
        error is FormatException) {
      return const DashboardFailure(
        kind: DashboardFailureKind.invalidResponse,
        message: 'The API returned an unexpected response.',
      );
    }
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.transformTimeout => const DashboardFailure(
          kind: DashboardFailureKind.timeout,
          message: 'The API did not respond in time.',
        ),
        DioExceptionType.connectionError => const DashboardFailure(
          kind: DashboardFailureKind.offline,
          message: 'Robot Control API is offline or unreachable.',
        ),
        DioExceptionType.badResponse => DashboardFailure(
          kind: DashboardFailureKind.http,
          message:
              'The API returned HTTP ${error.response?.statusCode ?? 'error'}.',
          statusCode: error.response?.statusCode,
        ),
        DioExceptionType.cancel => const DashboardFailure(
          kind: DashboardFailureKind.unknown,
          message: 'The dashboard request was cancelled.',
        ),
        DioExceptionType.badCertificate || DioExceptionType.unknown =>
          error.error is SocketException
              ? const DashboardFailure(
                  kind: DashboardFailureKind.offline,
                  message: 'Robot Control API is offline or unreachable.',
                )
              : DashboardFailure(
                  kind: DashboardFailureKind.unknown,
                  message: error.message ?? 'Unable to load the dashboard.',
                ),
      };
    }
    return DashboardFailure(
      kind: DashboardFailureKind.unknown,
      message: error.toString(),
    );
  }

  final DashboardFailureKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
