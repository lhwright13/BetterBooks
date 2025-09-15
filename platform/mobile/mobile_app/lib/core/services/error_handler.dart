import 'package:flutter/foundation.dart';
import '../exceptions/api_exceptions.dart';
import 'logging_service.dart';

enum ErrorLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  void logError(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    ErrorLevel level = ErrorLevel.error,
    String? tag,
  }) {
    switch (level) {
      case ErrorLevel.debug:
        LoggingService.debug(message, tag: tag, error: error, stackTrace: stackTrace);
        break;
      case ErrorLevel.info:
        LoggingService.info(message, tag: tag, error: error, stackTrace: stackTrace);
        break;
      case ErrorLevel.warning:
        LoggingService.warning(message, tag: tag, error: error, stackTrace: stackTrace);
        break;
      case ErrorLevel.error:
        LoggingService.error(message, tag: tag, error: error, stackTrace: stackTrace);
        break;
      case ErrorLevel.critical:
        LoggingService.error(message, tag: tag, error: error, stackTrace: stackTrace);
        // In production, critical errors should trigger immediate alerts
        if (!kDebugMode) {
          // FirebaseCrashlytics.instance.recordError(error, stackTrace);
        }
        break;
    }
  }

  String getErrorMessage(dynamic error) {
    if (error is ApiException) {
      return error.userMessage;
    }
    
    if (error is FormatException) {
      return 'Data format error. Please try refreshing.';
    }
    
    if (error is TypeError) {
      return 'Data processing error. Please try again.';
    }
    
    // Generic error message
    return 'An error occurred. Please try again.';
  }

  bool isRetryableError(dynamic error) {
    if (error is ApiException) {
      return error.type == ApiErrorType.networkError ||
             error.type == ApiErrorType.timeout ||
             error.type == ApiErrorType.serverError;
    }
    return false;
  }
}