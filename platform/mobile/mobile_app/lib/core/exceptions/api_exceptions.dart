/// Custom exceptions for API operations
/// Provides structured error handling throughout the app

enum ApiErrorType {
  networkError,
  timeout,
  unauthorized, 
  forbidden,
  notFound,
  serverError,
  parseError,
  cancelled,
  unknown
}

/// Base API exception class
class ApiException implements Exception {
  final String message;
  final ApiErrorType type;
  final int? statusCode;
  final String? details;

  const ApiException({
    required this.message,
    required this.type,
    this.statusCode,
    this.details,
  });

  @override
  String toString() {
    return 'ApiException: $message (${type.name}${statusCode != null ? ', status: $statusCode' : ''})';
  }

  /// User-friendly error message for display
  String get userMessage {
    switch (type) {
      case ApiErrorType.networkError:
        return 'Please check your internet connection and try again.';
      case ApiErrorType.timeout:
        return 'Request timed out. Please try again.';
      case ApiErrorType.unauthorized:
        return 'Please sign in again to continue.';
      case ApiErrorType.forbidden:
        return 'You do not have permission to perform this action.';
      case ApiErrorType.notFound:
        return 'The requested content was not found.';
      case ApiErrorType.serverError:
        return 'Server error occurred. Please try again later.';
      case ApiErrorType.parseError:
        return 'Unable to process server response. Please try again.';
      case ApiErrorType.cancelled:
        return 'Request was cancelled.';
      case ApiErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}

/// Network connection error
class NetworkException extends ApiException {
  const NetworkException({String? details}) 
    : super(
        message: 'Network connection failed',
        type: ApiErrorType.networkError,
        details: details,
      );
}

/// Request timeout error  
class TimeoutException extends ApiException {
  const TimeoutException({String? details})
    : super(
        message: 'Request timed out',
        type: ApiErrorType.timeout,
        details: details,
      );
}

/// Authentication error
class UnauthorizedException extends ApiException {
  const UnauthorizedException({String? details})
    : super(
        message: 'Authentication required',
        type: ApiErrorType.unauthorized,
        statusCode: 401,
        details: details,
      );
}

/// Permission denied error
class ForbiddenException extends ApiException {
  const ForbiddenException({String? details})
    : super(
        message: 'Access forbidden',
        type: ApiErrorType.forbidden,
        statusCode: 403,
        details: details,
      );
}

/// Resource not found error
class NotFoundException extends ApiException {
  const NotFoundException({String? details})
    : super(
        message: 'Resource not found',
        type: ApiErrorType.notFound,
        statusCode: 404,
        details: details,
      );
}

/// Server error (5xx)
class ServerException extends ApiException {
  const ServerException({String? details, int? statusCode})
    : super(
        message: 'Server error occurred',
        type: ApiErrorType.serverError,
        statusCode: statusCode,
        details: details,
      );
}

/// JSON parsing error
class ParseException extends ApiException {
  const ParseException({String? details})
    : super(
        message: 'Failed to parse response',
        type: ApiErrorType.parseError,
        details: details,
      );
}