/**
 * auth_service.dart - Authentication service for EchoWright mobile app
 * 
 * This service handles all authentication operations including:
 * - Google OAuth sign-in
 * - Apple Sign In
 * - Email/password authentication
 * - Token management and secure storage
 * - Session persistence and refresh
 * 
 * Key responsibilities:
 * - Integrate with device OAuth providers (Google, Apple)
 * - Securely store and manage JWT tokens
 * - Handle automatic token refresh
 * - Provide authentication state management
 * - Handle biometric authentication (future enhancement)
 * 
 * Backend integration:
 * - Communicates with EchoWright API Gateway authentication endpoints
 * - Sends OAuth tokens to backend for verification and account creation
 * - Manages JWT tokens received from backend
 * - Handles email verification flows
 */

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import '../api_config.dart';
import '../models/user.dart';

/// Authentication service for handling all authentication operations
/// Supports Google OAuth, Apple Sign In, and email/password authentication
class AuthService {
  static const Duration _timeoutDuration = Duration(seconds: 30);
  
  // Secure storage for tokens
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainItemAccessibility.first_unlock_this_device,
    ),
  );
  
  // Google Sign In configuration
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  // Storage keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';
  static const String _tokenExpiryKey = 'token_expiry';

  /// Check if user is currently authenticated
  static Future<bool> isAuthenticated() async {
    try {
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      if (accessToken == null) return false;

      // Check if token is expired
      final expiryString = await _secureStorage.read(key: _tokenExpiryKey);
      if (expiryString != null) {
        final expiry = DateTime.parse(expiryString);
        if (DateTime.now().isAfter(expiry)) {
          // Try to refresh token
          return await _refreshAccessToken();
        }
      }

      return true;
    } catch (e) {
      print('Error checking authentication: $e');
      return false;
    }
  }

  /// Get current user data from storage
  static Future<User?> getCurrentUser() async {
    try {
      final userDataString = await _secureStorage.read(key: _userDataKey);
      if (userDataString == null) return null;
      
      final userData = jsonDecode(userDataString);
      return User.fromJson(userData);
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  /// Get current access token
  static Future<String?> getAccessToken() async {
    try {
      // Check if token is expired and refresh if needed
      await isAuthenticated();
      return await _secureStorage.read(key: _accessTokenKey);
    } catch (e) {
      print('Error getting access token: $e');
      return null;
    }
  }

  /// Sign in with Google
  static Future<AuthResult> signInWithGoogle() async {
    try {
      // Sign in with Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.cancelled('User cancelled Google sign in');
      }

      // Get Google auth tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        return AuthResult.error('Failed to get Google ID token');
      }

      // Send to backend for verification and account creation
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/google/signin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': idToken,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Store tokens and user data
        await _storeAuthData(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
          expiresAt: data['expires_at'],
          userData: data['user'],
        );

        return AuthResult.success(User.fromJson(data['user']));
      } else {
        final error = jsonDecode(response.body);
        return AuthResult.error(error['detail'] ?? 'Google sign in failed');
      }
    } catch (e) {
      print('Google sign in error: $e');
      return AuthResult.error('Google sign in failed: $e');
    }
  }

  /// Sign in with Apple
  static Future<AuthResult> signInWithApple() async {
    try {
      // Generate nonce for Apple Sign In
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // Request Apple Sign In
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Send to backend for verification and account creation
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/apple/signin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': credential.identityToken,
          'nonce': rawNonce,
          'user_info': {
            'email': credential.email,
            'first_name': credential.givenName,
            'last_name': credential.familyName,
          }
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Store tokens and user data
        await _storeAuthData(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
          expiresAt: data['expires_at'],
          userData: data['user'],
        );

        return AuthResult.success(User.fromJson(data['user']));
      } else {
        final error = jsonDecode(response.body);
        return AuthResult.error(error['detail'] ?? 'Apple sign in failed');
      }
    } catch (e) {
      if (e is SignInWithAppleAuthorizationException) {
        if (e.code == AuthorizationErrorCode.canceled) {
          return AuthResult.cancelled('User cancelled Apple sign in');
        }
      }
      print('Apple sign in error: $e');
      return AuthResult.error('Apple sign in failed: $e');
    }
  }

  /// Sign up with email and password
  static Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/email/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'display_name': displayName,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Store tokens and user data
        await _storeAuthData(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
          expiresAt: data['expires_at'],
          userData: data['user'],
        );

        return AuthResult.success(User.fromJson(data['user']));
      } else {
        final error = jsonDecode(response.body);
        return AuthResult.error(error['detail'] ?? 'Email signup failed');
      }
    } catch (e) {
      print('Email signup error: $e');
      return AuthResult.error('Email signup failed: $e');
    }
  }

  /// Sign in with email and password
  static Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/email/signin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Store tokens and user data
        await _storeAuthData(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
          expiresAt: data['expires_at'],
          userData: data['user'],
        );

        return AuthResult.success(User.fromJson(data['user']));
      } else {
        final error = jsonDecode(response.body);
        return AuthResult.error(error['detail'] ?? 'Email signin failed');
      }
    } catch (e) {
      print('Email signin error: $e');
      return AuthResult.error('Email signin failed: $e');
    }
  }

  /// Send email verification
  static Future<bool> sendEmailVerification(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/email/send-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(_timeoutDuration);

      return response.statusCode == 200;
    } catch (e) {
      print('Send email verification error: $e');
      return false;
    }
  }

  /// Request password reset
  static Future<bool> requestPasswordReset(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/password/reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(_timeoutDuration);

      return response.statusCode == 200;
    } catch (e) {
      print('Password reset request error: $e');
      return false;
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      // Get refresh token for backend logout
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      
      if (refreshToken != null) {
        // Notify backend of logout
        await http.post(
          Uri.parse('$apiBaseUrl/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        ).timeout(_timeoutDuration);
      }

      // Sign out from Google if signed in
      await _googleSignIn.signOut();

      // Clear all stored data
      await _clearAuthData();
    } catch (e) {
      print('Sign out error: $e');
      // Clear local data even if backend request fails
      await _clearAuthData();
    }
  }

  /// Refresh access token
  static Future<bool> _refreshAccessToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Update stored tokens
        await _secureStorage.write(key: _accessTokenKey, value: data['access_token']);
        if (data['refresh_token'] != null) {
          await _secureStorage.write(key: _refreshTokenKey, value: data['refresh_token']);
        }
        if (data['expires_at'] != null) {
          await _secureStorage.write(key: _tokenExpiryKey, value: data['expires_at'].toString());
        }

        return true;
      } else {
        // Refresh failed, clear auth data
        await _clearAuthData();
        return false;
      }
    } catch (e) {
      print('Token refresh error: $e');
      await _clearAuthData();
      return false;
    }
  }

  /// Store authentication data securely
  static Future<void> _storeAuthData({
    required String accessToken,
    required String refreshToken,
    int? expiresAt,
    required Map<String, dynamic> userData,
  }) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    await _secureStorage.write(key: _userDataKey, value: jsonEncode(userData));
    
    if (expiresAt != null) {
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
      await _secureStorage.write(key: _tokenExpiryKey, value: expiryDate.toIso8601String());
    }
  }

  /// Clear all authentication data
  static Future<void> _clearAuthData() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _userDataKey);
    await _secureStorage.delete(key: _tokenExpiryKey);
  }

  /// Generate nonce for Apple Sign In
  static String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Generate SHA256 hash of string
  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

/// Result of authentication operations
class AuthResult {
  final bool success;
  final User? user;
  final String? error;
  final bool cancelled;

  AuthResult._({
    required this.success,
    this.user,
    this.error,
    this.cancelled = false,
  });

  factory AuthResult.success(User user) {
    return AuthResult._(success: true, user: user);
  }

  factory AuthResult.error(String error) {
    return AuthResult._(success: false, error: error);
  }

  factory AuthResult.cancelled(String message) {
    return AuthResult._(success: false, error: message, cancelled: true);
  }
}

/// Import for Random class
import 'dart:math';