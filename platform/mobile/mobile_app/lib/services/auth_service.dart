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
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import '../api_config.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'log_service.dart';

/// Authentication service for handling all authentication operations
/// Supports Google OAuth, Apple Sign In, and email/password authentication
class AuthService {
  static const Duration _timeoutDuration = Duration(seconds: 30);
  
  // Secure storage for tokens
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
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

      // Set the token in ApiService for API calls
      ApiService.setAuthToken(accessToken);
      return true;
    } catch (e) {
      LogService.auth('Error checking authentication: $e', isError: true);
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
      LogService.auth('Error getting current user: $e', isError: true);
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
      LogService.error('Error getting access token: $e', 'AuthService');
      return null;
    }
  }

  /// Sign in with Google
  static Future<AuthResult> signInWithGoogle() async {
    try {
      // Check if Google Services are available
      if (!await _googleSignIn.isSignedIn()) {
        LogService.debug('Google Sign In: User not currently signed in');
      }

      // Sign out any existing user first to ensure clean state
      try {
        await _googleSignIn.signOut();
        LogService.debug('Google Sign In: Successfully signed out existing user');
      } catch (signOutError) {
        LogService.debug('Google Sign In: Error during signOut (continuing): $signOutError');
      }
      
      // Trigger the authentication flow with error recovery
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signIn();
      } catch (signInError) {
        LogService.auth('Google Sign In flow error: $signInError', isError: true);
        return AuthResult.error('Google Sign In failed. Please check your internet connection and try again.');
      }
      
      if (googleUser == null) {
        return AuthResult.cancelled('User cancelled Google sign in');
      }

      // Get authentication details with error handling
      GoogleSignInAuthentication? googleAuth;
      try {
        googleAuth = await googleUser.authentication;
      } catch (authError) {
        LogService.auth('Google Auth token error: $authError', isError: true);
        return AuthResult.error('Failed to get Google authentication tokens. Please try again.');
      }

      // Validate tokens exist
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        LogService.auth('Google Auth tokens are null', isError: true);
        return AuthResult.error('Failed to get Google authentication tokens. Please try again.');
      }

      // Send to backend for verification and account creation
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': googleAuth.idToken,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Store tokens and user data
        await _storeAuthData(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
          expiresAt: data['expires_in'],
          userData: data['user'],
        );

        LogService.debug('Google OAuth successful: ${data['user']['email']}');
        return AuthResult.success(User.fromJson(data['user']));
      } else {
        final error = jsonDecode(response.body);
        LogService.auth('Google OAuth backend error: ${error['detail']}', isError: true);
        
        return AuthResult.error(error['detail'] ?? 'Google sign in failed');
      }
    } on PlatformException catch (e) {
      LogService.auth('Google Sign In Platform Error: ${e.code} - ${e.message}', isError: true);
      if (e.code == 'sign_in_failed') {
        return AuthResult.error('Google Sign In failed. Please check your internet connection and try again.');
      } else if (e.code == 'network_error') {
        return AuthResult.error('Network error. Please check your internet connection and try again.');
      } else if (e.code == 'sign_in_canceled') {
        return AuthResult.cancelled('User cancelled Google sign in');
      }
      return AuthResult.error('Google Sign In error: ${e.message ?? e.code}');
    } catch (e) {
      LogService.auth('Google sign in unexpected error: $e', isError: true);
      return AuthResult.error('Google sign in failed. Please try again.');
    }
  }

  /// Sign in with Apple
  static Future<AuthResult> signInWithApple() async {
    try {
      // Check if Apple Sign In is available
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        return AuthResult.error('Apple Sign In is not available on this device');
      }

      // Generate nonce for Apple Sign In
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // Request Apple Sign In with error handling
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'com.betterbooks.app', 
          redirectUri: Uri.parse('https://echowright-app.firebaseapp.com/__/auth/handler'),
        ),
      );

      // Send to backend for verification and account creation
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/apple'),
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
          expiresAt: data['expires_in'],
          userData: data['user'],
        );

        LogService.debug('Apple OAuth successful: ${data['user']['email']}');
        return AuthResult.success(User.fromJson(data['user']));
      } else {
        final error = jsonDecode(response.body);
        LogService.auth('Apple OAuth backend error: ${error['detail']}', isError: true);
        
        return AuthResult.error(error['detail'] ?? 'Apple sign in failed');
      }
    } catch (e) {
      if (e is SignInWithAppleAuthorizationException) {
        if (e.code == AuthorizationErrorCode.canceled) {
          return AuthResult.cancelled('User cancelled Apple sign in');
        } else if (e.code == AuthorizationErrorCode.failed) {
          return AuthResult.error('Apple Sign In failed. Please ensure you are signed into iCloud.');
        } else if (e.code == AuthorizationErrorCode.invalidResponse) {
          return AuthResult.error('Invalid response from Apple. Please try again.');
        } else if (e.code == AuthorizationErrorCode.notHandled) {
          return AuthResult.error('Apple Sign In is not properly configured for this app.');
        } else if (e.code == AuthorizationErrorCode.unknown) {
          return AuthResult.error('Unknown Apple Sign In error. Please ensure you are signed into iCloud and try again.');
        }
        return AuthResult.error('Apple Sign In error (${e.code}): ${e.message}');
      }
      LogService.auth('Apple sign in error: $e', isError: true);
      return AuthResult.error('Apple sign in failed: Please ensure you are signed into iCloud and try again.');
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
        Uri.parse('$apiBaseUrl/auth/signup'),
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

        LogService.debug('Email registration successful: ${data['user']['email']}');
        return AuthResult.success(User.fromJson(data['user']));
      } else {
        final error = jsonDecode(response.body);
        LogService.auth('Email registration error: ${error['detail']}', isError: true);
        return AuthResult.error(error['detail'] ?? 'Registration failed');
      }
    } catch (e) {
      LogService.auth('Registration error: $e', isError: true);
      return AuthResult.error('Registration failed: $e');
    }
  }

  /// Sign in with email and password
  static Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/signin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Set auth token for subsequent requests
        ApiService.setAuthToken(data['access_token']);
        
        // Use user data from login response (it's already included)
        final userData = data['user'];
        if (userData != null) {
          // Store tokens and user data
          await _storeAuthData(
            accessToken: data['access_token'],
            refreshToken: data['refresh_token'],
            expiresAt: data['expires_at'], // Note: this is expires_at not expires_in
            userData: userData,
          );

          LogService.auth('Email sign-in successful: ${userData['email']}');
          return AuthResult.success(User.fromJson(userData));
        } else {
          LogService.auth('No user data in login response', isError: true);
          return AuthResult.error('Login successful but failed to fetch user data');
        }
      } else {
        final error = jsonDecode(response.body);
        LogService.auth('Email sign-in error: ${error['detail']}', isError: true);
        return AuthResult.error(error['detail'] ?? 'Login failed');
      }
    } catch (e) {
      LogService.auth('Login error: $e', isError: true);
      return AuthResult.error('Login failed: $e');
    }
  }

  /// Send email verification
  static Future<bool> sendEmailVerification(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/email/send-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(_timeoutDuration);

      return response.statusCode == 200;
    } catch (e) {
      LogService.error('Send email verification error: $e', 'AuthService');
      return false;
    }
  }

  /// Request password reset
  static Future<bool> requestPasswordReset(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/password/reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(_timeoutDuration);

      return response.statusCode == 200;
    } catch (e) {
      LogService.error('Password reset request error: $e', 'AuthService');
      return false;
    }
  }

  /// Fetch current user data from server
  static Future<User?> fetchCurrentUser() async {
    try {
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      if (accessToken == null) return null;

      final response = await http.get(
        Uri.parse('$apiBaseUrl/auth/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        final user = User.fromJson(userData);
        
        // Update stored user data
        await _secureStorage.write(
          key: _userDataKey, 
          value: jsonEncode(userData),
        );
        
        LogService.auth('User data fetched successfully: ${user.email}');
        return user;
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          // Retry the request
          return await fetchCurrentUser();
        }
        return null;
      } else if (response.statusCode == 404) {
        // /auth/me endpoint doesn't exist on this backend version
        LogService.auth('/auth/me endpoint not available, using stored user data');
        return await getCurrentUser();
      } else {
        LogService.auth('Failed to fetch user data: ${response.statusCode}', isError: true);
        // Fallback to stored user data
        return await getCurrentUser();
      }
    } catch (e) {
      LogService.auth('Error fetching user data: $e, using fallback', isError: true);
      // Fallback to stored user data  
      return await getCurrentUser();
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      // Get refresh token for backend logout
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      if (accessToken != null) {
        // Notify backend of logout
        await http.post(
          Uri.parse('$apiBaseUrl/auth/logout'),
          headers: {'Authorization': 'Bearer $accessToken'},
          body: jsonEncode({'refresh_token': refreshToken}),
        ).timeout(_timeoutDuration);
      }

      // Sign out from Google if signed in
      await _googleSignIn.signOut();

      // Clear all stored data
      await _clearAuthData();
    } catch (e) {
      LogService.error('Sign out error: $e', 'AuthService');
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
        headers: {'Authorization': 'Bearer $refreshToken'},
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
      LogService.error('Token refresh error: $e', 'AuthService');
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
    
    // Update ApiService with the access token for API calls
    ApiService.setAuthToken(accessToken);
  }

  /// Clear all authentication data
  static Future<void> _clearAuthData() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _userDataKey);
    await _secureStorage.delete(key: _tokenExpiryKey);
    
    // Clear the ApiService token as well
    ApiService.clearAuthToken();
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

  /// Get user's credit balance
  static Future<Map<String, dynamic>> getCreditBalance() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/bookstore/user/credits'),
        headers: await _getAuthHeaders(),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get credit balance: ${response.statusCode}');
      }
    } catch (e) {
      LogService.error('Credit balance error: $e', 'AuthService');
      // Return default values for development
      return {
        'total_credits': 5,
        'used_credits': 0,
        'available_credits': 5,
      };
    }
  }

  /// Initialize credits for a new user
  static Future<Map<String, dynamic>> initializeCredits() async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/bookstore/user/initialize-credits'),
        headers: await _getAuthHeaders(),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to initialize credits: ${response.statusCode}');
      }
    } catch (e) {
      LogService.error('Credit initialization error: $e', 'AuthService');
      return {'message': 'Credits initialized locally', 'credits': 5};
    }
  }

  /// Get user library from the backend
  static Future<Map<String, dynamic>> getUserLibrary({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/bookstore/user/library'),
        headers: await _getAuthHeaders(),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'books': data['books'] ?? [],
          'total_count': data['total_books'] ?? 0,
          'limit': limit,
          'offset': offset,
          'has_more': (data['total_books'] ?? 0) > (offset + limit),
        };
      } else {
        throw Exception('Failed to load user library: ${response.statusCode}');
      }
    } catch (e) {
      LogService.error('Get user library error: $e', 'AuthService');
      throw Exception('Failed to load user library: $e');
    }
  }

  /// Purchase a book using credits
  static Future<Map<String, dynamic>> purchaseBook(
    String bookId, {
    int creditsToUse = 1,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/bookstore/purchase'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'book_id': bookId,
          'payment_method': 'credit',
          'credits_to_use': creditsToUse,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Book purchased successfully',
          'purchase_id': data['transaction_id'] ?? data['purchase_id'],
          'book_id': bookId,
          'credits_used': creditsToUse,
          'remaining_credits': data['remaining_credits'] ?? 0,
          'download_url': data['download_url'],
        };
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Purchase failed');
      }
    } catch (e) {
      LogService.error('Purchase book error: $e', 'AuthService');
      return {
        'success': false,
        'message': 'Purchase failed',
        'error': e.toString(),
      };
    }
  }

  /// Check if user owns a book by checking their library
  static Future<bool> checkBookOwnership(String bookId) async {
    try {
      final library = await getUserLibrary(limit: 100);
      final books = library['books'] as List<dynamic>;
      
      return books.any((book) => book['id'] == bookId);
    } catch (e) {
      LogService.error('Check book ownership error: $e', 'AuthService');
      return false; // Assume not owned if we can't check
    }
  }

  /// Get auth headers with current access token
  static Future<Map<String, String>> _getAuthHeaders() async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    final token = await getAccessToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
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