import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/logging_service.dart';

/// Comprehensive API request/response logger with security considerations
class ApiLogger {
  static const List<String> _sensitiveHeaders = [
    'authorization',
    'cookie',
    'x-api-key',
    'x-auth-token',
  ];

  static const List<String> _sensitiveFields = [
    'password',
    'token',
    'refresh_token',
    'access_token',
    'secret',
    'key',
    'pin',
    'ssn',
    'card_number',
  ];

  /// Log HTTP request with sanitized sensitive data
  static void logRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
    required String context,
  }) {
    if (!kDebugMode) return;

    final sanitizedHeaders = _sanitizeHeaders(headers);
    final sanitizedBody = _sanitizeBody(body);

    final logMessage = StringBuffer();
    logMessage.writeln('📤 API REQUEST [$context]');
    logMessage.writeln('Method: $method');
    logMessage.writeln('URL: $uri');
    logMessage.writeln('Headers: $sanitizedHeaders');
    
    if (sanitizedBody != null) {
      logMessage.writeln('Body: $sanitizedBody');
    }

    logDebug(logMessage.toString(), tag: 'ApiLogger');
  }

  /// Log HTTP response with timing and sanitized data
  static void logResponse({
    required http.Response response,
    required Duration duration,
    required String context,
  }) {
    if (!kDebugMode) return;

    final statusCode = response.statusCode;
    final isSuccess = statusCode >= 200 && statusCode < 300;
    final sanitizedHeaders = _sanitizeHeaders(response.headers);
    final sanitizedBody = _sanitizeResponseBody(response.body);

    final logMessage = StringBuffer();
    logMessage.writeln('📥 API RESPONSE [$context]');
    logMessage.writeln('Status: $statusCode ${isSuccess ? '✅' : '❌'}');
    logMessage.writeln('Duration: ${duration.inMilliseconds}ms');
    logMessage.writeln('Headers: $sanitizedHeaders');
    
    if (sanitizedBody != null) {
      logMessage.writeln('Body: $sanitizedBody');
    }

    if (isSuccess) {
      logDebug(logMessage.toString(), tag: 'ApiLogger');
    } else {
      logWarning(logMessage.toString(), tag: 'ApiLogger');
    }
  }

  /// Log API error with full context
  static void logError({
    required String context,
    required Object error,
    StackTrace? stackTrace,
    String? method,
    Uri? uri,
    Duration? duration,
  }) {
    final logMessage = StringBuffer();
    logMessage.writeln('💥 API ERROR [$context]');
    
    if (method != null && uri != null) {
      logMessage.writeln('Request: $method $uri');
    }
    
    if (duration != null) {
      logMessage.writeln('Duration: ${duration.inMilliseconds}ms');
    }
    
    logMessage.writeln('Error: $error');

    LoggingService.error(
      logMessage.toString(),
      tag: 'ApiLogger',
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log network connectivity issues
  static void logNetworkIssue({
    required String context,
    required String issue,
    String? method,
    Uri? uri,
  }) {
    final logMessage = StringBuffer();
    logMessage.writeln('🌐 NETWORK ISSUE [$context]');
    
    if (method != null && uri != null) {
      logMessage.writeln('Request: $method $uri');
    }
    
    logMessage.writeln('Issue: $issue');

    logWarning(logMessage.toString(), tag: 'ApiLogger');
  }

  /// Log retry attempts
  static void logRetryAttempt({
    required String context,
    required int attempt,
    required int maxAttempts,
    required String reason,
    Duration? delay,
  }) {
    final logMessage = StringBuffer();
    logMessage.writeln('🔄 RETRY ATTEMPT [$context]');
    logMessage.writeln('Attempt: $attempt/$maxAttempts');
    logMessage.writeln('Reason: $reason');
    
    if (delay != null) {
      logMessage.writeln('Delay: ${delay.inMilliseconds}ms');
    }

    logInfo(logMessage.toString(), tag: 'ApiLogger');
  }

  /// Sanitize headers by removing sensitive information
  static Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    final sanitized = <String, String>{};
    
    headers.forEach((key, value) {
      if (_sensitiveHeaders.contains(key.toLowerCase())) {
        sanitized[key] = _maskSensitiveValue(value);
      } else {
        sanitized[key] = value;
      }
    });
    
    return sanitized;
  }

  /// Sanitize request body by removing sensitive fields
  static String? _sanitizeBody(String? body) {
    if (body == null || body.isEmpty) return null;

    try {
      final jsonData = jsonDecode(body);
      if (jsonData is Map<String, dynamic>) {
        final sanitized = _sanitizeJsonObject(jsonData);
        return jsonEncode(sanitized);
      }
      return body; // Return as-is if not JSON
    } catch (e) {
      // Not valid JSON, return as-is but truncate if too long
      return body.length > 500 ? '${body.substring(0, 500)}...[truncated]' : body;
    }
  }

  /// Sanitize response body - be more conservative with response data
  static String? _sanitizeResponseBody(String body) {
    if (body.isEmpty) return null;

    try {
      final jsonData = jsonDecode(body);
      if (jsonData is Map<String, dynamic>) {
        final sanitized = _sanitizeJsonObject(jsonData);
        final sanitizedJson = jsonEncode(sanitized);
        
        // Truncate very long responses
        return sanitizedJson.length > 1000 
            ? '${sanitizedJson.substring(0, 1000)}...[truncated]' 
            : sanitizedJson;
      } else if (jsonData is List) {
        // For arrays, just show length and first few items
        final length = jsonData.length;
        if (length == 0) return '[]';
        
        final preview = jsonData.take(3).toList();
        return '[${preview.map((item) => item.runtimeType).join(', ')}] (${length} items)';
      }
      
      return body.length > 500 ? '${body.substring(0, 500)}...[truncated]' : body;
    } catch (e) {
      // Not valid JSON, return truncated
      return body.length > 500 ? '${body.substring(0, 500)}...[truncated]' : body;
    }
  }

  /// Recursively sanitize JSON object
  static Map<String, dynamic> _sanitizeJsonObject(Map<String, dynamic> obj) {
    final sanitized = <String, dynamic>{};
    
    obj.forEach((key, value) {
      if (_sensitiveFields.any((field) => key.toLowerCase().contains(field))) {
        sanitized[key] = _maskSensitiveValue(value.toString());
      } else if (value is Map<String, dynamic>) {
        sanitized[key] = _sanitizeJsonObject(value);
      } else if (value is List) {
        sanitized[key] = value.map((item) {
          return item is Map<String, dynamic> ? _sanitizeJsonObject(item) : item;
        }).toList();
      } else {
        sanitized[key] = value;
      }
    });
    
    return sanitized;
  }

  /// Mask sensitive values while preserving some structure
  static String _maskSensitiveValue(String value) {
    if (value.length <= 4) return '****';
    
    // For tokens, show first 4 and last 4 characters
    if (value.length > 20) {
      return '${value.substring(0, 4)}${'*' * (value.length - 8)}${value.substring(value.length - 4)}';
    }
    
    // For shorter values, show first 2 characters
    return '${value.substring(0, 2)}${'*' * (value.length - 2)}';
  }
}