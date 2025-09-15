import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/logging_service.dart';
import '../../data/api/api_client.dart';
import '../../data/models/auth_models.dart';

/// Centralized token management with automatic refresh and lifecycle handling
class TokenManager {
  static final TokenManager _instance = TokenManager._internal();
  factory TokenManager() => _instance;
  TokenManager._internal();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _userDataKey = 'user_data';

  Timer? _refreshTimer;
  String? _currentAccessToken;
  DateTime? _tokenExpiry;

  /// Initialize token manager and start automatic refresh
  Future<void> initialize() async {
    await _loadTokensFromStorage();
    _scheduleTokenRefresh();
    logInfo('TokenManager initialized', tag: 'TokenManager');
  }

  /// Get current access token, refreshing if needed
  Future<String?> getValidAccessToken() async {
    if (_currentAccessToken == null) {
      await _loadTokensFromStorage();
    }

    if (_isTokenExpired()) {
      logInfo('Token expired, attempting refresh', tag: 'TokenManager');
      final refreshed = await _refreshToken();
      if (!refreshed) {
        logWarning('Token refresh failed', tag: 'TokenManager');
        return null;
      }
    }

    return _currentAccessToken;
  }

  /// Store new tokens from authentication response
  Future<void> storeTokens(AuthResponse authResponse) async {
    _currentAccessToken = authResponse.accessToken;
    
    // Calculate expiry time (assuming token is valid for 1 hour if not specified)
    _tokenExpiry = DateTime.now().add(const Duration(hours: 1));

    // Store in secure storage
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: authResponse.accessToken),
      _storage.write(key: _refreshTokenKey, value: authResponse.refreshToken),
      _storage.write(key: _tokenExpiryKey, value: _tokenExpiry!.toIso8601String()),
      _storage.write(key: _userDataKey, value: authResponse.user.toString()),
    ]);

    // Update API client
    ApiClient.setAuthToken(authResponse.accessToken);
    
    _scheduleTokenRefresh();
    logInfo('Tokens stored successfully', tag: 'TokenManager');
  }

  /// Clear all tokens (logout)
  Future<void> clearTokens() async {
    _currentAccessToken = null;
    _tokenExpiry = null;
    _refreshTimer?.cancel();
    
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _tokenExpiryKey),
      _storage.delete(key: _userDataKey),
    ]);

    ApiClient.setAuthToken('');
    logInfo('Tokens cleared', tag: 'TokenManager');
  }

  /// Check if user has valid tokens
  Future<bool> hasValidTokens() async {
    final accessToken = await getValidAccessToken();
    return accessToken != null;
  }

  /// Get stored user data
  Future<String?> getUserData() async {
    return await _storage.read(key: _userDataKey);
  }

  /// Load tokens from secure storage
  Future<void> _loadTokensFromStorage() async {
    try {
      final accessToken = await _storage.read(key: _accessTokenKey);
      final expiryString = await _storage.read(key: _tokenExpiryKey);

      if (accessToken != null) {
        _currentAccessToken = accessToken;
        ApiClient.setAuthToken(accessToken);
        
        if (expiryString != null) {
          _tokenExpiry = DateTime.parse(expiryString);
        }
        
        logDebug('Tokens loaded from storage', tag: 'TokenManager');
      }
    } catch (e) {
      logError('Failed to load tokens from storage', tag: 'TokenManager', error: e);
      await clearTokens();
    }
  }

  /// Check if current token is expired or will expire soon
  bool _isTokenExpired() {
    if (_tokenExpiry == null) return true;
    
    // Consider token expired if it expires in the next 5 minutes
    final expiryBuffer = DateTime.now().add(const Duration(minutes: 5));
    return _tokenExpiry!.isBefore(expiryBuffer);
  }

  /// Refresh the access token using refresh token
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: _refreshTokenKey);
      if (refreshToken == null) {
        logWarning('No refresh token available', tag: 'TokenManager');
        return false;
      }

      // Use ApiClient to refresh token
      final authResponse = await ApiClient.refreshToken(refreshToken);
      await storeTokens(authResponse);
      
      logInfo('Token refreshed successfully', tag: 'TokenManager');
      return true;
    } catch (e) {
      logError('Token refresh failed', tag: 'TokenManager', error: e);
      await clearTokens();
      return false;
    }
  }

  /// Schedule automatic token refresh
  void _scheduleTokenRefresh() {
    _refreshTimer?.cancel();
    
    if (_tokenExpiry == null) return;

    // Schedule refresh 10 minutes before expiry
    final refreshTime = _tokenExpiry!.subtract(const Duration(minutes: 10));
    final now = DateTime.now();
    
    if (refreshTime.isAfter(now)) {
      final delay = refreshTime.difference(now);
      _refreshTimer = Timer(delay, () async {
        logInfo('Automatic token refresh triggered', tag: 'TokenManager');
        await _refreshToken();
      });
      
      logDebug('Token refresh scheduled in ${delay.inMinutes} minutes', 
        tag: 'TokenManager');
    }
  }

  /// Dispose resources
  void dispose() {
    _refreshTimer?.cancel();
    logInfo('TokenManager disposed', tag: 'TokenManager');
  }
}

/// Global token manager instance
final tokenManager = TokenManager();