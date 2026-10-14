enum FailureCode {
  invalidInput,
  unauthenticated,
  forbidden,
  notFound,
  conflict,
  slotUnavailable,
  propertyUnavailable,
  soldOut,
  idempotencyConflict,
  policyNotConfigured,
  featureNotEnabled,
  rateLimited,
  timeout,
  offline,
  upstreamUnavailable,
  internalError,
}

final class FieldIssue {
  const FieldIssue({required this.field, required this.code});
  final String field;
  final String code;
}

/// UI uses code/fieldIssues and retains input; message is not an enum key.
final class XlandFailure implements Exception {
  const XlandFailure.notFound({
    String message = 'Resource not found',
    String? requestId,
  }) : this(code: FailureCode.notFound, message: message, requestId: requestId);
  const XlandFailure.forbidden({
    String message = 'Permission denied',
    String? requestId,
  }) : this(
         code: FailureCode.forbidden,
         message: message,
         requestId: requestId,
       );
  const XlandFailure.unauthenticated({
    String message = 'Sign in required',
    String? requestId,
  }) : this(
         code: FailureCode.unauthenticated,
         message: message,
         requestId: requestId,
       );
  const XlandFailure.conflict({
    String message = 'Resource conflict',
    String? requestId,
  }) : this(code: FailureCode.conflict, message: message, requestId: requestId);
  const XlandFailure({
    required this.code,
    required this.message,
    this.requestId,
    this.fieldIssues = const [],
    this.retryAfterSeconds,
  });
  final FailureCode code;
  final String message;
  final String? requestId;
  final List<FieldIssue> fieldIssues;
  final int? retryAfterSeconds;
}
