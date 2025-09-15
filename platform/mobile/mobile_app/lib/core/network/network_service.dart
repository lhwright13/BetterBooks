import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/connectivity_service.dart';
import '../services/http_error_handler.dart';
import '../services/logging_service.dart';
import '../services/offline_queue_manager.dart';
import '../services/api_cache_manager.dart';
import '../exceptions/api_exceptions.dart';
import 'token_manager.dart';
import 'api_logger.dart';

/// Enhanced network service with comprehensive error handling, retry logic,
/// connectivity checking, and automatic token management
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final http.Client _client = http.Client();
  final TokenManager _tokenManager = TokenManager();
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineQueueManager _queueManager = OfflineQueueManager();
  final ApiCacheManager _cacheManager = ApiCacheManager();

  /// Initialize the network service
  Future<void> initialize() async {
    await _tokenManager.initialize();
    await _connectivityService.initialize();
    await _queueManager.initialize();
    await _cacheManager.initialize();
    logInfo('NetworkService initialized with offline support', tag: 'NetworkService');
  }

  /// Execute GET request with full error handling and retry logic
  Future<http.Response> get({
    required Uri uri,
    Map<String, String>? headers,
    bool requiresAuth = false,
    String context = 'GET Request',
    int maxRetries = 3,
    Duration? timeout,
    bool useCache = true,
    Duration? cacheDuration,
    bool allowOfflineQueue = false,
  }) async {
    return _executeRequestWithCaching(
      method: 'GET',
      uri: uri,
      headers: headers,
      requiresAuth: requiresAuth,
      context: context,
      maxRetries: maxRetries,
      timeout: timeout,
      useCache: useCache,
      cacheDuration: cacheDuration,
      allowOfflineQueue: allowOfflineQueue,
      requestBuilder: (finalHeaders) => _client.get(uri, headers: finalHeaders),
    );
  }

  /// Execute POST request with full error handling and retry logic
  Future<http.Response> post({
    required Uri uri,
    Map<String, String>? headers,
    String? body,
    bool requiresAuth = false,
    String context = 'POST Request',
    int maxRetries = 3,
    Duration? timeout,
    bool allowOfflineQueue = true,
  }) async {
    return _executeRequestWithCaching(
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
      requiresAuth: requiresAuth,
      context: context,
      maxRetries: maxRetries,
      timeout: timeout,
      allowOfflineQueue: allowOfflineQueue,
      requestBuilder: (finalHeaders) => _client.post(
        uri,
        headers: finalHeaders,
        body: body,
      ),
    );
  }

  /// Execute PUT request with full error handling and retry logic
  Future<http.Response> put({
    required Uri uri,
    Map<String, String>? headers,
    String? body,
    bool requiresAuth = false,
    String context = 'PUT Request',
    int maxRetries = 3,
    Duration? timeout,
  }) async {
    return _executeRequest(
      method: 'PUT',
      uri: uri,
      headers: headers,
      body: body,
      requiresAuth: requiresAuth,
      context: context,
      maxRetries: maxRetries,
      timeout: timeout,
      requestBuilder: (finalHeaders) => _client.put(
        uri,
        headers: finalHeaders,
        body: body,
      ),
    );
  }

  /// Execute DELETE request with full error handling and retry logic
  Future<http.Response> delete({
    required Uri uri,
    Map<String, String>? headers,
    bool requiresAuth = false,
    String context = 'DELETE Request',
    int maxRetries = 3,
    Duration? timeout,
  }) async {
    return _executeRequest(
      method: 'DELETE',
      uri: uri,
      headers: headers,
      requiresAuth: requiresAuth,
      context: context,
      maxRetries: maxRetries,
      timeout: timeout,
      requestBuilder: (finalHeaders) => _client.delete(uri, headers: finalHeaders),
    );
  }

  /// Check if device has network connectivity
  Future<bool> hasConnectivity() async {
    return await _connectivityService.checkConnectivity();
  }

  /// Get current connectivity status
  bool get isOnline => _connectivityService.isOnline;
  bool get isOffline => _connectivityService.isOffline;

  /// Core request execution with all enhancements
  Future<http.Response> _executeRequest({
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    String? body,
    required bool requiresAuth,
    required String context,
    required int maxRetries,
    Duration? timeout,
    required Future<http.Response> Function(Map<String, String>) requestBuilder,
  }) async {
    // Check connectivity first
    if (isOffline) {
      ApiLogger.logNetworkIssue(
        context: context,
        issue: 'No network connectivity',
        method: method,
        uri: uri,
      );
      throw NetworkException(details: 'No network connectivity available');
    }

    // Prepare headers
    final finalHeaders = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
    };

    // Add authentication if required
    if (requiresAuth) {
      final token = await _tokenManager.getValidAccessToken();
      if (token == null) {
        throw UnauthorizedException(details: 'No valid authentication token');
      }
      finalHeaders['Authorization'] = 'Bearer $token';
    }

    // Log the request
    ApiLogger.logRequest(
      method: method,
      uri: uri,
      headers: finalHeaders,
      body: body,
      context: context,
    );

    // Execute with retry logic
    return await HttpErrorHandler.executeWithRetry(
      maxRetries: maxRetries,
      context: context,
      request: () async {
        final stopwatch = Stopwatch()..start();
        
        try {
          final response = await requestBuilder(finalHeaders)
              .timeout(timeout ?? const Duration(seconds: 30));
          
          stopwatch.stop();
          
          // Log successful response
          ApiLogger.logResponse(
            response: response,
            duration: stopwatch.elapsed,
            context: context,
          );
          
          return response;
        } catch (e) {
          stopwatch.stop();
          
          // Log error
          ApiLogger.logError(
            context: context,
            error: e,
            method: method,
            uri: uri,
            duration: stopwatch.elapsed,
          );
          
          rethrow;
        }
      },
    );
  }

  /// Execute request with automatic authenticated retry
  /// If request fails with 401, will attempt token refresh and retry once
  Future<http.Response> executeWithAuthRetry({
    required Future<http.Response> Function() request,
    required String context,
  }) async {
    try {
      return await request();
    } on UnauthorizedException catch (e) {
      logInfo('Authentication failed, attempting token refresh', 
        tag: 'NetworkService');
      
      // Try to refresh token
      final refreshed = await _tokenManager.getValidAccessToken();
      if (refreshed == null) {
        logWarning('Token refresh failed, authentication required', 
          tag: 'NetworkService');
        rethrow;
      }
      
      logInfo('Token refreshed successfully, retrying request', 
        tag: 'NetworkService');
      
      // Retry the original request with new token
      return await request();
    }
  }

  /// Create cancellable request
  Future<http.Response> executeWithCancellation({
    required Future<http.Response> Function() request,
    required CancelToken cancelToken,
    required String context,
  }) async {
    if (cancelToken.isCancelled) {
      throw RequestCancelledException(details: 'Request was cancelled');
    }

    final completer = Completer<http.Response>();
    
    // Execute the request
    request().then((response) {
      if (!completer.isCompleted && !cancelToken.isCancelled) {
        completer.complete(response);
      }
    }).catchError((error) {
      if (!completer.isCompleted && !cancelToken.isCancelled) {
        completer.completeError(error);
      }
    });

    // Listen for cancellation
    cancelToken.onCancel = () {
      if (!completer.isCompleted) {
        completer.completeError(
          RequestCancelledException(details: 'Request was cancelled')
        );
      }
    };

    return completer.future;
  }

  /// Execute request with caching and offline queue support
  Future<http.Response> _executeRequestWithCaching({
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    String? body,
    required bool requiresAuth,
    required String context,
    required int maxRetries,
    Duration? timeout,
    bool useCache = false,
    Duration? cacheDuration,
    bool allowOfflineQueue = false,
    required Future<http.Response> Function(Map<String, String>) requestBuilder,
  }) async {
    // Prepare headers for cache key generation
    final finalHeaders = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
    };

    // For GET requests, check cache first
    if (method == 'GET' && useCache) {
      final cachedResponse = await _cacheManager.getCachedResponse(
        endpoint: uri.toString(),
        headers: finalHeaders,
      );
      
      if (cachedResponse != null) {
        logInfo('Returning cached response for $context', tag: 'NetworkService');
        return http.Response(cachedResponse, 200);
      }
    }

    // Check if we're offline and should queue the request
    if (isOffline && allowOfflineQueue) {
      final offlineRequest = OfflineRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        method: method,
        endpoint: uri.toString(),
        headers: finalHeaders,
        body: body,
        requiresAuth: requiresAuth,
        timeout: timeout,
      );
      
      await _queueManager.queueRequest(offlineRequest);
      
      logInfo('Request queued for offline processing: $context', tag: 'NetworkService');
      throw NetworkException(details: 'Request queued for when connectivity returns');
    }

    // Execute the request normally
    final response = await _executeRequest(
      method: method,
      uri: uri,
      headers: headers,
      body: body,
      requiresAuth: requiresAuth,
      context: context,
      maxRetries: maxRetries,
      timeout: timeout,
      requestBuilder: requestBuilder,
    );

    // Cache successful GET responses
    if (method == 'GET' && useCache && response.statusCode == 200) {
      await _cacheManager.cacheResponse(
        endpoint: uri.toString(),
        headers: finalHeaders,
        response: response.body,
        cacheDuration: cacheDuration,
      );
    }

    return response;
  }

  /// Dispose resources
  void dispose() {
    _client.close();
    _tokenManager.dispose();
    _connectivityService.dispose();
    _queueManager.dispose();
    _cacheManager.dispose();
    logInfo('NetworkService disposed', tag: 'NetworkService');
  }
}

/// Token for request cancellation
class CancelToken {
  bool _isCancelled = false;
  VoidCallback? onCancel;

  bool get isCancelled => _isCancelled;

  void cancel() {
    if (!_isCancelled) {
      _isCancelled = true;
      onCancel?.call();
    }
  }
}

/// Exception for cancelled requests
class RequestCancelledException extends ApiException {
  RequestCancelledException({String? details}) : super(
    message: 'Request was cancelled',
    type: ApiErrorType.cancelled,
    details: details,
  );
}

/// Global network service instance
final networkService = NetworkService();