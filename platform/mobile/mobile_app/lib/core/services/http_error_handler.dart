import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../exceptions/api_exceptions.dart';
import 'logging_service.dart';

/// Centralized HTTP error handling and retry logic
class HttpErrorHandler {
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);

  /// Handle HTTP response and convert to appropriate exception
  static void handleResponse(http.Response response, String context) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return; // Success
    }

    final statusCode = response.statusCode;
    final responseBody = response.body;
    
    logError('HTTP error in $context', 
      tag: 'HttpErrorHandler',
      error: 'Status: $statusCode, Body: $responseBody'
    );

    switch (statusCode) {
      case 401:
        throw UnauthorizedException(details: responseBody);
      case 403:
        throw ForbiddenException(details: responseBody);
      case 404:
        throw NotFoundException(details: responseBody);
      case 408:
        throw TimeoutException(details: responseBody);
      case >= 500:
        throw ServerException(statusCode: statusCode, details: responseBody);
      default:
        throw ApiException(
          message: 'HTTP $statusCode error in $context',
          type: ApiErrorType.unknown,
          statusCode: statusCode,
          details: responseBody,
        );
    }
  }

  /// Execute HTTP request with retry logic and error handling
  static Future<http.Response> executeWithRetry({
    required Future<http.Response> Function() request,
    required String context,
    int maxRetries = maxRetries,
  }) async {
    int attempts = 0;
    Duration delay = retryDelay;

    while (attempts < maxRetries) {
      attempts++;
      
      try {
        final response = await request();
        handleResponse(response, context);
        return response;
      } on SocketException catch (e) {
        logError('Network error in $context (attempt $attempts/$maxRetries)',
          tag: 'HttpErrorHandler', error: e);
        
        if (attempts >= maxRetries) {
          throw NetworkException(details: e.message);
        }
      } on TimeoutException catch (e) {
        logError('Timeout in $context (attempt $attempts/$maxRetries)',
          tag: 'HttpErrorHandler', error: e);
        
        if (attempts >= maxRetries) {
          throw TimeoutException(details: e.toString());
        }
      } on ApiException {
        // Don't retry on authentication/permission errors
        rethrow;
      } catch (e) {
        logError('Unexpected error in $context (attempt $attempts/$maxRetries)',
          tag: 'HttpErrorHandler', error: e);
        
        if (attempts >= maxRetries) {
          throw ApiException(
            message: 'Unexpected error in $context',
            type: ApiErrorType.unknown,
            details: e.toString(),
          );
        }
      }

      // Wait before retry with exponential backoff
      if (attempts < maxRetries) {
        logDebug('Retrying $context in ${delay.inMilliseconds}ms',
          tag: 'HttpErrorHandler');
        await Future.delayed(delay);
        delay = Duration(milliseconds: (delay.inMilliseconds * 1.5).round());
      }
    }

    // This should never be reached
    throw ApiException(
      message: 'All retry attempts failed for $context',
      type: ApiErrorType.unknown,
    );
  }

  /// Parse JSON response with error handling
  static Map<String, dynamic> parseJsonResponse(http.Response response, String context) {
    try {
      final decoded = response.body;
      if (decoded.isEmpty) {
        throw ParseException(details: 'Empty response body in $context');
      }
      
      // Try to parse as JSON
      final jsonData = jsonDecode(decoded);
      if (jsonData is! Map<String, dynamic>) {
        throw ParseException(details: 'Invalid JSON format in $context');
      }
      
      return jsonData;
    } catch (e) {
      logError('JSON parse error in $context', tag: 'HttpErrorHandler', error: e);
      throw ParseException(details: 'Failed to parse response: ${e.toString()}');
    }
  }
}