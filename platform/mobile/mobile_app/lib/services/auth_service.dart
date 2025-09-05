import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/api/api_client.dart';
import '../data/models/auth_models.dart';

/// Authentication service handling login, signup, and token management
class AuthService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';
  
  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await _storage.read(key: _accessTokenKey);
    return token != null;
  }
  
  /// Get stored access token
  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }
  
  /// Sign up new user
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await ApiClient.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      
      // Store tokens securely
      await _storage.write(key: _accessTokenKey, value: response.accessToken);
      await _storage.write(key: _refreshTokenKey, value: response.refreshToken);
      await _storage.write(key: _userDataKey, value: response.user.toString());
      
      // Set token in API client
      ApiClient.setAuthToken(response.accessToken);
      
      return response;
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }
  
  /// Sign in existing user
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiClient.signIn(
        email: email,
        password: password,
      );
      
      // Store tokens securely
      await _storage.write(key: _accessTokenKey, value: response.accessToken);
      await _storage.write(key: _refreshTokenKey, value: response.refreshToken);
      await _storage.write(key: _userDataKey, value: response.user.toString());
      
      // Set token in API client
      ApiClient.setAuthToken(response.accessToken);
      
      return response;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }
  
  /// Initialize auth on app start
  static Future<void> initialize() async {
    final token = await getAccessToken();
    if (token != null) {
      ApiClient.setAuthToken(token);
    }
  }
  
  /// Logout user
  static Future<void> logout() async {
    try {
      // Call API logout
      await ApiClient.logout();
    } catch (e) {
      // Continue with local logout even if API call fails
      // Note: In production, use proper logging framework
      debugPrint('API logout failed: $e');
    }
    
    // Clear local storage
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userDataKey);
    
    // Clear API client token
    ApiClient.setAuthToken('');
  }
  
  /// Refresh access token if expired
  static Future<bool> refreshTokenIfNeeded() async {
    try {
      final refreshToken = await _storage.read(key: _refreshTokenKey);
      if (refreshToken == null) {
        return false;
      }
      
      final response = await ApiClient.refreshToken(refreshToken);
      
      // Store new tokens
      await _storage.write(key: _accessTokenKey, value: response.accessToken);
      await _storage.write(key: _refreshTokenKey, value: response.refreshToken);
      await _storage.write(key: _userDataKey, value: response.user.toString());
      
      // Update API client token
      ApiClient.setAuthToken(response.accessToken);
      
      return true;
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      // If refresh fails, user needs to log in again
      await logout();
      return false;
    }
  }
  
  /// Make authenticated API call with automatic token refresh
  static Future<T> makeAuthenticatedRequest<T>(
    Future<T> Function() apiCall,
  ) async {
    try {
      return await apiCall();
    } on Exception catch (e) {
      final errorMessage = e.toString();
      
      // Check if the error is related to token expiration
      if (errorMessage.contains('Token has expired') || 
          errorMessage.contains('401') ||
          errorMessage.contains('Unauthorized')) {
        
        // Try to refresh the token
        final refreshSuccess = await refreshTokenIfNeeded();
        
        if (refreshSuccess) {
          // Retry the original API call with new token
          return await apiCall();
        } else {
          // Refresh failed, user needs to log in again
          throw Exception('Authentication expired. Please log in again.');
        }
      }
      
      // If it's not a token issue, rethrow the original exception
      rethrow;
    }
  }

  /// Get current user data
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      return await makeAuthenticatedRequest(() => ApiClient.getCurrentUser());
    } catch (e) {
      debugPrint('Failed to get current user: $e');
      return null;
    }
  }
}