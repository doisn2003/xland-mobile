/// Adapter boundary only, implemented with HTTP in Phase 2.
/// No Supabase tables, implicit mocks or client owner IDs.
abstract interface class ApiTransport {
  Future<ApiResponse> send(ApiRequest request);
}

final class ApiRequest {
  const ApiRequest({
    required this.method,
    required this.path,
    this.query = const {},
    this.body,
    this.idempotencyKey,
  });
  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, Object?>? body;
  final String? idempotencyKey;
}

final class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.body,
    this.requestId,
  });
  final int statusCode;
  final Map<String, Object?> body;
  final String? requestId;
}
