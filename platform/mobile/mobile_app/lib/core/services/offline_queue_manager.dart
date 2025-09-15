import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/network_service.dart';
import '../network/api_logger.dart';
import 'connectivity_service.dart';
import 'logging_service.dart';

/// Manages offline request queuing and automatic retry when connectivity returns
class OfflineQueueManager {
  static final OfflineQueueManager _instance = OfflineQueueManager._internal();
  factory OfflineQueueManager() => _instance;
  OfflineQueueManager._internal();

  static const String _queueKey = 'offline_request_queue';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 5);

  final NetworkService _networkService = NetworkService();
  final ConnectivityService _connectivity = ConnectivityService();
  
  SharedPreferences? _prefs;
  Timer? _processTimer;
  bool _isProcessing = false;

  /// Initialize the offline queue manager
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Listen for connectivity changes
    _connectivity.addListener(() {
      final isOnline = _connectivity.isOnline;
      if (isOnline && !_isProcessing) {
        _startProcessingQueue();
      } else if (!isOnline) {
        _stopProcessingQueue();
      }
    });

    // Start processing if online
    if (_connectivity.isOnline) {
      _startProcessingQueue();
    }

    logInfo('OfflineQueueManager initialized', tag: 'OfflineQueue');
  }

  /// Queue a request for later execution when offline
  Future<void> queueRequest(OfflineRequest request) async {
    if (_prefs == null) return;

    try {
      final queue = await _getQueue();
      queue.add(request);
      await _saveQueue(queue);
      
      logInfo('Request queued: ${request.method} ${request.endpoint}', 
        tag: 'OfflineQueue');
      
      // Try to process immediately if online
      if (_connectivity.isOnline) {
        _startProcessingQueue();
      }
    } catch (e) {
      logError('Failed to queue request', tag: 'OfflineQueue', error: e);
    }
  }

  /// Start processing queued requests
  void _startProcessingQueue() {
    if (_isProcessing) return;
    _isProcessing = true;
    
    _processTimer?.cancel();
    _processTimer = Timer.periodic(_retryDelay, (timer) {
      _processQueuedRequests();
    });

    // Process immediately
    _processQueuedRequests();
    
    logInfo('Started processing offline queue', tag: 'OfflineQueue');
  }

  /// Stop processing queued requests
  void _stopProcessingQueue() {
    _processTimer?.cancel();
    _isProcessing = false;
    logInfo('Stopped processing offline queue', tag: 'OfflineQueue');
  }

  /// Process all queued requests
  Future<void> _processQueuedRequests() async {
    if (!_connectivity.isOnline || _prefs == null) return;

    try {
      final queue = await _getQueue();
      if (queue.isEmpty) {
        _stopProcessingQueue();
        return;
      }

      final toRemove = <OfflineRequest>[];
      
      for (final request in queue) {
        if (request.retryCount >= _maxRetries) {
          logWarning('Request exceeded max retries, removing from queue: ${request.id}', 
            tag: 'OfflineQueue');
          toRemove.add(request);
          continue;
        }

        try {
          await _executeRequest(request);
          toRemove.add(request);
          logInfo('Successfully executed queued request: ${request.id}', 
            tag: 'OfflineQueue');
        } catch (e) {
          request.retryCount++;
          request.lastAttempt = DateTime.now();
          logWarning('Failed to execute queued request (retry ${request.retryCount}): ${request.id}', 
            tag: 'OfflineQueue', error: e);
          
          if (request.retryCount >= _maxRetries) {
            toRemove.add(request);
            _notifyRequestFailed(request, e);
          }
        }
      }

      // Remove completed/failed requests
      queue.removeWhere((req) => toRemove.contains(req));
      await _saveQueue(queue);

      if (queue.isEmpty) {
        _stopProcessingQueue();
      }
    } catch (e) {
      logError('Error processing offline queue', tag: 'OfflineQueue', error: e);
    }
  }

  /// Execute a single queued request
  Future<void> _executeRequest(OfflineRequest request) async {
    final uri = Uri.parse(request.endpoint);
    
    switch (request.method.toUpperCase()) {
      case 'GET':
        await _networkService.get(
          uri: uri,
          headers: request.headers,
          requiresAuth: request.requiresAuth,
          context: 'Offline Queue: ${request.id}',
          timeout: request.timeout,
        );
        break;
      case 'POST':
        await _networkService.post(
          uri: uri,
          headers: request.headers,
          body: request.body,
          requiresAuth: request.requiresAuth,
          context: 'Offline Queue: ${request.id}',
          timeout: request.timeout,
        );
        break;
      case 'PUT':
        await _networkService.put(
          uri: uri,
          headers: request.headers,
          body: request.body,
          requiresAuth: request.requiresAuth,
          context: 'Offline Queue: ${request.id}',
          timeout: request.timeout,
        );
        break;
      case 'DELETE':
        await _networkService.delete(
          uri: uri,
          headers: request.headers,
          requiresAuth: request.requiresAuth,
          context: 'Offline Queue: ${request.id}',
          timeout: request.timeout,
        );
        break;
      default:
        throw UnsupportedError('HTTP method ${request.method} not supported');
    }
  }

  /// Get the current queue from storage
  Future<List<OfflineRequest>> _getQueue() async {
    if (_prefs == null) return [];

    try {
      final queueJson = _prefs!.getString(_queueKey);
      if (queueJson == null) return [];

      final List<dynamic> queueData = jsonDecode(queueJson);
      return queueData.map((json) => OfflineRequest.fromJson(json)).toList();
    } catch (e) {
      logError('Failed to load offline queue', tag: 'OfflineQueue', error: e);
      return [];
    }
  }

  /// Save the queue to storage
  Future<void> _saveQueue(List<OfflineRequest> queue) async {
    if (_prefs == null) return;

    try {
      final queueJson = jsonEncode(queue.map((req) => req.toJson()).toList());
      await _prefs!.setString(_queueKey, queueJson);
    } catch (e) {
      logError('Failed to save offline queue', tag: 'OfflineQueue', error: e);
    }
  }

  /// Notify that a request failed permanently
  void _notifyRequestFailed(OfflineRequest request, dynamic error) {
    // Here you could emit events, show notifications, etc.
    logError('Request permanently failed: ${request.id}', 
      tag: 'OfflineQueue', error: error);
  }

  /// Get current queue status
  Future<OfflineQueueStatus> getQueueStatus() async {
    final queue = await _getQueue();
    return OfflineQueueStatus(
      queuedCount: queue.length,
      isProcessing: _isProcessing,
      isOnline: _connectivity.isOnline,
      failedRequests: queue.where((req) => req.retryCount >= _maxRetries).length,
    );
  }

  /// Clear all queued requests
  Future<void> clearQueue() async {
    if (_prefs == null) return;
    
    await _prefs!.remove(_queueKey);
    _stopProcessingQueue();
    logInfo('Offline queue cleared', tag: 'OfflineQueue');
  }

  /// Dispose resources
  void dispose() {
    _processTimer?.cancel();
    _connectivity.dispose();
    logInfo('OfflineQueueManager disposed', tag: 'OfflineQueue');
  }
}

/// Represents a request that can be queued for offline execution
class OfflineRequest {
  final String id;
  final String method;
  final String endpoint;
  final Map<String, String>? headers;
  final String? body;
  final bool requiresAuth;
  final Duration? timeout;
  final DateTime createdAt;
  
  int retryCount;
  DateTime? lastAttempt;

  OfflineRequest({
    required this.id,
    required this.method,
    required this.endpoint,
    this.headers,
    this.body,
    this.requiresAuth = false,
    this.timeout,
    DateTime? createdAt,
    this.retryCount = 0,
    this.lastAttempt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory OfflineRequest.fromJson(Map<String, dynamic> json) {
    return OfflineRequest(
      id: json['id'],
      method: json['method'],
      endpoint: json['endpoint'],
      headers: json['headers'] != null 
          ? Map<String, String>.from(json['headers'])
          : null,
      body: json['body'],
      requiresAuth: json['requiresAuth'] ?? false,
      timeout: json['timeout'] != null 
          ? Duration(milliseconds: json['timeout'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      retryCount: json['retryCount'] ?? 0,
      lastAttempt: json['lastAttempt'] != null 
          ? DateTime.parse(json['lastAttempt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'method': method,
      'endpoint': endpoint,
      'headers': headers,
      'body': body,
      'requiresAuth': requiresAuth,
      'timeout': timeout?.inMilliseconds,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'lastAttempt': lastAttempt?.toIso8601String(),
    };
  }
}

/// Status information about the offline queue
class OfflineQueueStatus {
  final int queuedCount;
  final bool isProcessing;
  final bool isOnline;
  final int failedRequests;

  const OfflineQueueStatus({
    required this.queuedCount,
    required this.isProcessing,
    required this.isOnline,
    required this.failedRequests,
  });
}

/// Global offline queue manager instance
final offlineQueueManager = OfflineQueueManager();