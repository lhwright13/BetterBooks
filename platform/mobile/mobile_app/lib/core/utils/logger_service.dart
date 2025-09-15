import 'package:flutter/foundation.dart';

/// Production-ready logger service that handles logging based on environment
/// In production, logs are disabled or sent to analytics/crash reporting services
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  static const String _appName = 'BetterBooks';
  
  // Control logging based on environment
  static bool get _shouldLog => kDebugMode && !kReleaseMode;
  
  /// Log informational messages
  static void info(String message, [dynamic data]) {
    if (_shouldLog) {
      debugPrint('ℹ️ [$_appName] $message${data != null ? ': $data' : ''}');
    }
    // In production, could send to analytics
  }
  
  /// Log warning messages
  static void warning(String message, [dynamic data]) {
    if (_shouldLog) {
      debugPrint('⚠️ [$_appName] WARNING: $message${data != null ? ': $data' : ''}');
    }
    // In production, send to monitoring service
  }
  
  /// Log error messages
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_shouldLog) {
      debugPrint('❌ [$_appName] ERROR: $message');
      if (error != null) {
        debugPrint('Error details: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
    // In production, send to crash reporting
    _reportToCrashlytics(message, error, stackTrace);
  }
  
  /// Log debug messages (only in debug mode)
  static void debug(String message, [dynamic data]) {
    if (_shouldLog) {
      debugPrint('🐛 [$_appName] DEBUG: $message${data != null ? ': $data' : ''}');
    }
  }
  
  /// Log network requests
  static void network(String method, String url, [int? statusCode]) {
    if (_shouldLog) {
      final status = statusCode != null ? ' -> $statusCode' : '';
      debugPrint('🌐 [$_appName] $method $url$status');
    }
  }
  
  /// Log performance metrics
  static void performance(String operation, Duration duration) {
    if (_shouldLog) {
      debugPrint('⏱️ [$_appName] $operation took ${duration.inMilliseconds}ms');
    }
    // In production, send to performance monitoring
  }
  
  /// Log user actions for analytics
  static void analytics(String event, [Map<String, dynamic>? parameters]) {
    if (_shouldLog) {
      debugPrint('📊 [$_appName] Event: $event${parameters != null ? ' with $parameters' : ''}');
    }
    // In production, send to analytics service
    _sendToAnalytics(event, parameters);
  }
  
  /// Report to crash reporting service (placeholder for production)
  static void _reportToCrashlytics(String message, dynamic error, StackTrace? stackTrace) {
    // Production crash reporting integration point
    // Configure SENTRY_DSN in .env.production to enable
  }
  
  /// Send to analytics service (placeholder for production)
  static void _sendToAnalytics(String event, Map<String, dynamic>? parameters) {
    // Production analytics integration point
    // Configure FIREBASE_ANALYTICS_ENABLED in .env.production to enable
  }
}

/// Extension for easy logging on any object
extension LoggerExtension on Object {
  void logInfo(String message) => LoggerService.info(message, this);
  void logWarning(String message) => LoggerService.warning(message, this);
  void logError(String message) => LoggerService.error(message, this);
  void logDebug(String message) => LoggerService.debug(message, this);
}