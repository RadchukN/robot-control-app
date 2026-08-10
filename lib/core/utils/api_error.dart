class ApiError {
  const ApiError({required this.message, this.statusCode});

  final String message;
  final int? statusCode;
}
