import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

/// Centralized logging service with environment-based log levels
/// Replaces scattered print() statements throughout the app
class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  static LoggingService get instance => _instance;

  /// Log debug messages (only in debug builds)
  static void debug(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Log info messages
  static void info(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Log warning messages
  static void warning(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Log error messages
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Internal logging method
  static void _log(LogLevel level, String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    // Only log if appropriate for current environment
    if (!_shouldLog(level)) return;

    final tagPrefix = tag != null ? '[$tag] ' : '';
    final formattedMessage = '$tagPrefix$message';

    switch (level) {
      case LogLevel.debug:
        if (kDebugMode) {
          developer.log(formattedMessage, name: 'DEBUG', error: error, stackTrace: stackTrace);
        }
        break;
      case LogLevel.info:
        developer.log(formattedMessage, name: 'INFO', error: error, stackTrace: stackTrace);
        break;
      case LogLevel.warning:
        developer.log(formattedMessage, name: 'WARNING', error: error, stackTrace: stackTrace);
        break;
      case LogLevel.error:
        developer.log(formattedMessage, name: 'ERROR', error: error, stackTrace: stackTrace);
        break;
    }
  }

  /// Determine if we should log based on environment and level
  static bool _shouldLog(LogLevel level) {
    // Always log warnings and errors
    if (level == LogLevel.warning || level == LogLevel.error) {
      return true;
    }

    // Only log debug/info in debug builds
    return kDebugMode;
  }
}

/// Convenient static methods for quick access
void logDebug(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
  LoggingService.debug(message, tag: tag, error: error, stackTrace: stackTrace);
}

void logInfo(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
  LoggingService.info(message, tag: tag, error: error, stackTrace: stackTrace);
}

void logWarning(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
  LoggingService.warning(message, tag: tag, error: error, stackTrace: stackTrace);
}

void logError(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
  LoggingService.error(message, tag: tag, error: error, stackTrace: stackTrace);
}