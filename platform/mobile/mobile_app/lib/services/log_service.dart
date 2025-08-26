import 'dart:developer' as developer;

/// Centralized logging service for the EchoWright mobile app
/// Provides different log levels and conditional logging based on build mode
class LogService {
  static const String _tag = 'EchoWright';
  
  // Log levels
  static const int _debug = 0;
  static const int _info = 1;
  static const int _warning = 2;
  static const int _error = 3;
  
  // Current log level (can be adjusted based on build mode)
  static int _currentLogLevel = _debug;
  
  /// Initialize logging service
  static void init({bool isDebugMode = true}) {
    _currentLogLevel = isDebugMode ? _debug : _info;
  }
  
  /// Debug level logging - only shown in debug builds
  static void debug(String message, [String? context]) {
    if (_currentLogLevel <= _debug) {
      final logMessage = context != null ? '[$context] $message' : message;
      developer.log(logMessage, name: '$_tag.DEBUG', level: 500);
    }
  }
  
  /// Info level logging - general app information
  static void info(String message, [String? context]) {
    if (_currentLogLevel <= _info) {
      final logMessage = context != null ? '[$context] $message' : message;
      developer.log(logMessage, name: '$_tag.INFO', level: 800);
    }
  }
  
  /// Warning level logging - potential issues
  static void warning(String message, [String? context]) {
    if (_currentLogLevel <= _warning) {
      final logMessage = context != null ? '[$context] $message' : message;
      developer.log(logMessage, name: '$_tag.WARNING', level: 900);
    }
  }
  
  /// Error level logging - serious issues
  static void error(String message, [String? context, Object? error]) {
    if (_currentLogLevel <= _error) {
      final logMessage = context != null ? '[$context] $message' : message;
      developer.log(
        logMessage, 
        name: '$_tag.ERROR', 
        level: 1000,
        error: error,
      );
    }
  }
  
  /// API call logging - specialized for network requests
  static void api(String method, String url, {int? statusCode, String? error}) {
    if (_currentLogLevel <= _info) {
      final status = statusCode != null ? ' ($statusCode)' : '';
      final errorText = error != null ? ' - ERROR: $error' : '';
      developer.log(
        '$method $url$status$errorText', 
        name: '$_tag.API', 
        level: statusCode != null && statusCode >= 400 ? 1000 : 800
      );
    }
  }
  
  /// Authentication logging - specialized for auth events
  static void auth(String event, {bool isError = false}) {
    final level = isError ? 1000 : 800;
    final name = isError ? '$_tag.AUTH.ERROR' : '$_tag.AUTH';
    developer.log(event, name: name, level: level);
  }
}