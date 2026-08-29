// RemoteOS failure model (ARCHITECTURE.md § 13).
//
// Low-level exceptions (SocketException, HTTP status, JSON errors, …) should
// be mapped to a RemoteOsFailure subtype before they reach presentation code.
// UI must not render `exception.toString()` directly.

/// Base failure type returned by repositories and use cases.
sealed class RemoteOsFailure {
  const RemoteOsFailure({this.message, this.cause, this.stackTrace});

  /// Optional safe, user-meaningful message (can be empty).
  final String? message;

  /// Original cause for logging only; never displayed to users directly.
  final Object? cause;
  final StackTrace? stackTrace;
}

/// Network-level failure: connection refused, timeout, DNS errors, etc.
final class NetworkFailure extends RemoteOsFailure {
  const NetworkFailure({super.message, super.cause, super.stackTrace});
}

/// 401 / session expired / missing token.
final class UnauthorizedFailure extends RemoteOsFailure {
  const UnauthorizedFailure({super.message, super.cause, super.stackTrace});
}

/// 403 / operation not permitted after elevation check.
final class PermissionDeniedFailure extends RemoteOsFailure {
  const PermissionDeniedFailure({
    super.message,
    super.cause,
    super.stackTrace,
    this.requiresElevation = false,
  });

  final bool requiresElevation;
}

/// 400 / input validation failure.
final class ValidationFailure extends RemoteOsFailure {
  const ValidationFailure({super.message, super.cause, super.stackTrace});
}

/// 5xx / unexpected server-side failure; `ProblemDetails` preserved via
/// [message] for downstream presentation mapping.
final class ServerFailure extends RemoteOsFailure {
  const ServerFailure({
    super.message,
    super.cause,
    super.stackTrace,
    this.problemCode,
    this.statusCode,
  });

  final String? problemCode;
  final int? statusCode;
}

/// Operation is valid but not supported in this server/client combination.
final class UnsupportedOperationFailure extends RemoteOsFailure {
  const UnsupportedOperationFailure({super.message, super.cause, super.stackTrace});
}

/// Explicit cancellation (e.g. user dismissed a dialog mid-flight).
final class CancelledFailure extends RemoteOsFailure {
  const CancelledFailure({super.message, super.cause, super.stackTrace});
}

/// Convenience helpers for mapping low-level exceptions.
extension FailureFromException on Object {
  RemoteOsFailure asFailure({StackTrace? trace, String? message}) {
    final self = this;
    if (self is RemoteOsFailure) return self;
    return ServerFailure(
      message: message ?? self.toString(),
      cause: self,
      stackTrace: trace ?? StackTrace.current,
    );
  }
}
