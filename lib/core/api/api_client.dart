import 'package:dio/dio.dart';

class ApiClient {
  const ApiClient(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get<Object?>(path, queryParameters: queryParameters);
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const ApiFormatException('Expected a JSON object response.');
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> getJsonList(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get<Object?>(path, queryParameters: queryParameters);
    final data = response.data;
    if (data is! List<dynamic>) {
      throw const ApiFormatException('Expected a JSON list response.');
    }
    return data.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const ApiFormatException('Expected every list item to be a JSON object.');
      }
      return item;
    }).toList(growable: false);
  }
}

class ApiFormatException implements Exception {
  const ApiFormatException(this.message);

  final String message;

  @override
  String toString() => 'ApiFormatException: $message';
}
