import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'logging_service.dart';

/// Service for monitoring network connectivity status
/// Provides real-time connectivity updates throughout the app
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  bool _isOnline = true;
  Timer? _connectivityTimer;
  
  /// Current connectivity status
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    await _checkConnectivity();
    _startPeriodicChecks();
    logInfo('ConnectivityService initialized', tag: 'ConnectivityService');
  }

  /// Check connectivity by attempting to reach a reliable endpoint
  Future<bool> checkConnectivity() async {
    return await _checkConnectivity();
  }

  /// Internal connectivity check
  Future<bool> _checkConnectivity() async {
    try {
      // Try to connect to a reliable endpoint
      final result = await InternetAddress.lookup('google.com');
      final wasOnline = _isOnline;
      
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      // Notify listeners if status changed
      if (wasOnline != _isOnline) {
        logInfo('Connectivity changed: ${_isOnline ? 'online' : 'offline'}', 
          tag: 'ConnectivityService');
        notifyListeners();
      }
      
      return _isOnline;
    } catch (e) {
      final wasOnline = _isOnline;
      _isOnline = false;
      
      if (wasOnline != _isOnline) {
        logWarning('Network connectivity lost', 
          tag: 'ConnectivityService', error: e);
        notifyListeners();
      }
      
      return false;
    }
  }

  /// Start periodic connectivity checks
  void _startPeriodicChecks() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 30), 
      (_) => _checkConnectivity()
    );
  }

  /// Stop periodic checks
  void stopMonitoring() {
    _connectivityTimer?.cancel();
    _connectivityTimer = null;
    logInfo('ConnectivityService monitoring stopped', tag: 'ConnectivityService');
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}

/// Global connectivity instance for easy access
final connectivityService = ConnectivityService();