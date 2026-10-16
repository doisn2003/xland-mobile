import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../domain/failures/xland_failure.dart';
import '../local/session_store.dart';
import 'api_transport.dart';

final class HttpApiTransport implements ApiTransport {
  HttpApiTransport({
    required this.baseUrl,
    required this.client,
    required this.sessions,
    this.timeout = const Duration(seconds: 15),
    bool allowLocalHttp = false,
  }) {
    final loopback = [
      'localhost',
      '127.0.0.1',
      '10.0.2.2',
      '::1',
    ].contains(baseUrl.host);
    if (baseUrl.scheme != 'https' &&
        !(allowLocalHttp && baseUrl.scheme == 'http' && loopback)) {
      throw ArgumentError(
        'API base URL requires HTTPS or explicit local development HTTP',
      );
    }
  }
  final Uri baseUrl;
  final http.Client client;
  final SessionStore sessions;
  final Duration timeout;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final root = baseUrl.toString().replaceFirst(RegExp(r'/$'), '');
    final uri = Uri.parse('$root${request.path}')
        .replace(queryParameters: request.query.isEmpty ? null : request.query);
    final headers = <String, String>{'Accept': 'application/json'};
    if (request.body != null) headers['Content-Type'] = 'application/json';
    if (request.idempotencyKey != null) {
      headers['Idempotency-Key'] = request.idempotencyKey!;
    }
    final login = request.method == 'POST' && request.path == '/auth/sessions';
    if (!login) {
      final token = await sessions.readAccessToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    String? requestId;
    try {
      final outgoing = http.Request(request.method, uri)
        ..headers.addAll(headers);
      if (request.body != null) outgoing.body = jsonEncode(request.body);
      final response = await client
          .send(outgoing)
          .then(http.Response.fromStream)
          .timeout(timeout);
      requestId = response.headers['x-request-id'];
      final parsed = jsonDecode(response.body);
      if (parsed is! Map<String, Object?>) {
        throw const FormatException('Invalid API envelope');
      }
      if (response.statusCode >= 400) {
        final error = parsed['error'];
        if (error is! Map<String, Object?>) {
          throw const FormatException('Invalid error envelope');
        }
        final rawCode = error['code'];
        const codes = <String, FailureCode>{
          'INVALID_INPUT': FailureCode.invalidInput,
          'PAYLOAD_TOO_LARGE': FailureCode.invalidInput,
          'UNAUTHENTICATED': FailureCode.unauthenticated,
          'FORBIDDEN': FailureCode.forbidden,
          'NOT_FOUND': FailureCode.notFound,
          'CONFLICT': FailureCode.conflict,
          'SLOT_UNAVAILABLE': FailureCode.slotUnavailable,
          'PROPERTY_UNAVAILABLE': FailureCode.propertyUnavailable,
          'SOLD_OUT': FailureCode.soldOut,
          'IDEMPOTENCY_CONFLICT': FailureCode.idempotencyConflict,
          'POLICY_NOT_CONFIGURED': FailureCode.policyNotConfigured,
          'FEATURE_NOT_ENABLED': FailureCode.featureNotEnabled,
          'RATE_LIMITED': FailureCode.rateLimited,
          'UPSTREAM_UNAVAILABLE': FailureCode.upstreamUnavailable,
          'INTERNAL_ERROR': FailureCode.internalError,
        };
        final code = codes[rawCode] ?? FailureCode.internalError;
        if (code == FailureCode.unauthenticated && !login) {
          await sessions.clear();
        }
        final details = error['details'];
        final issues = <FieldIssue>[];
        if (details is List<Object?>) {
          for (final issue in details) {
            if (issue is Map<String, Object?> &&
                issue['field'] is String &&
                issue['code'] is String) {
              issues.add(
                FieldIssue(
                  field: issue['field']! as String,
                  code: issue['code']! as String,
                ),
              );
            }
          }
        }
        throw XlandFailure(
          code: code,
          message: error['message'] is String
              ? error['message']! as String
              : 'Yêu cầu không thành công',
          requestId: requestId,
          fieldIssues: issues,
          retryAfterSeconds: int.tryParse(
            response.headers['retry-after'] ?? '',
          ),
        );
      }
      return ApiResponse(
        statusCode: response.statusCode,
        body: parsed,
        requestId: requestId,
      );
    } on XlandFailure {
      rethrow;
    } on TimeoutException {
      throw const XlandFailure(
        code: FailureCode.timeout,
        message: 'Kết nối quá thời gian; hãy thử lại',
      );
    } on http.ClientException {
      throw const XlandFailure(
        code: FailureCode.offline,
        message: 'Không thể kết nối máy chủ',
      );
    } on FormatException {
      throw XlandFailure(
        code: FailureCode.internalError,
        message: 'Dữ liệu máy chủ không hợp lệ',
        requestId: requestId,
      );
    }
  }
}
