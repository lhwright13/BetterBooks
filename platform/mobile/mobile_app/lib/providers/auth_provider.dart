/**
 * auth_provider.dart - Authentication state provider for EchoWright mobile app
 * 
 * This provider manages global authentication state using Flutter's Provider pattern.
 * It serves as the central source of truth for user authentication status and provides
 * methods for login, logout, and authentication state changes.
 * 
 * Key responsibilities:
 * - Manage global authentication state (user, loading states)
 * - Provide authentication methods to UI components
 * - Handle automatic session restoration on app startup
 * - Notify listeners of authentication state changes
 * - Integrate with AuthService for actual authentication operations
 * 
 * State management:
 * - Uses ChangeNotifier for reactive state updates
 * - Provides loading states for UI feedback during auth operations
 * - Handles error states and messages
 * - Persists authentication state across app restarts
 */

import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

/// Global authentication state provider
/// Manages user authentication state and provides auth methods to the UI
class AuthProvider extends ChangeNotifier {
  // Current user state
  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  // Getters for current state
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;

  /// Initialize authentication state on app startup
  /// Checks for existing valid session and restores user state
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _setLoading(true);
    
    try {
      // Check if user has valid authentication
      final isAuth = await AuthService.isAuthenticated();
      
      if (isAuth) {
        // Get user data from secure storage
        final user = await AuthService.getCurrentUser();
        if (user != null) {
          _setAuthenticatedUser(user);
        } else {
          _setUnauthenticated();
        }
      } else {
        _setUnauthenticated();
      }
    } catch (e) {
      print('Auth initialization error: $e');
      _setUnauthenticated();
    } finally {
      _isInitialized = true;
      _setLoading(false);
    }
  }

  /// Sign in with Google OAuth
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();
    
    try {
      final result = await AuthService.signInWithGoogle();
      
      if (result.success && result.user != null) {
        _setAuthenticatedUser(result.user!);
        return true;
      } else {
        _setError(result.error ?? 'Google sign in failed');
        return false;
      }
    } catch (e) {
      _setError('Google sign in failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign in with Apple
  Future<bool> signInWithApple() async {
    _setLoading(true);
    _clearError();
    
    try {
      final result = await AuthService.signInWithApple();
      
      if (result.success && result.user != null) {
        _setAuthenticatedUser(result.user!);
        return true;
      } else if (result.cancelled) {
        // Don't show error for user cancellation
        return false;
      } else {
        _setError(result.error ?? 'Apple sign in failed');
        return false;
      }
    } catch (e) {
      _setError('Apple sign in failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign up with email and password
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final result = await AuthService.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      
      if (result.success && result.user != null) {
        _setAuthenticatedUser(result.user!);
        return true;
      } else {
        _setError(result.error ?? 'Email signup failed');
        return false;
      }
    } catch (e) {
      _setError('Email signup failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final result = await AuthService.signInWithEmail(
        email: email,
        password: password,
      );
      
      if (result.success && result.user != null) {
        _setAuthenticatedUser(result.user!);
        return true;
      } else {
        _setError(result.error ?? 'Email signin failed');
        return false;
      }
    } catch (e) {
      _setError('Email signin failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Send email verification
  Future<bool> sendEmailVerification(String email) async {
    _setLoading(true);
    _clearError();
    
    try {
      final success = await AuthService.sendEmailVerification(email);
      if (!success) {
        _setError('Failed to send verification email');
      }
      return success;
    } catch (e) {
      _setError('Failed to send verification email: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Request password reset
  Future<bool> requestPasswordReset(String email) async {
    _setLoading(true);
    _clearError();
    
    try {
      final success = await AuthService.requestPasswordReset(email);
      if (!success) {
        _setError('Failed to send password reset email');
      }
      return success;
    } catch (e) {
      _setError('Failed to send password reset email: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    _setLoading(true);
    _clearError();
    
    try {
      await AuthService.signOut();
      _setUnauthenticated();
    } catch (e) {
      print('Sign out error: $e');
      // Force local logout even if backend request fails
      _setUnauthenticated();
    } finally {
      _setLoading(false);
    }
  }

  /// Update user information (after profile changes)
  Future<void> updateUser(User updatedUser) async {
    _currentUser = updatedUser;
    notifyListeners();
  }

  /// Refresh user data from backend
  Future<void> refreshUser() async {
    if (!_isAuthenticated) return;
    
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      }
    } catch (e) {
      print('Error refreshing user: $e');
    }
  }

  /// Check if current user needs email verification
  bool get needsEmailVerification {
    return _currentUser?.email != null && !(_currentUser?.emailVerified ?? true);
  }

  /// Check if current user has premium subscription
  bool get isPremiumUser {
    return _currentUser?.isPremium ?? false;
  }

  /// Get current user's display name
  String get userDisplayName {
    return _currentUser?.displayName ?? _currentUser?.firstName ?? 'User';
  }

  /// Get current user's initials for avatar
  String get userInitials {
    return _currentUser?.initials ?? 'U';
  }

  /// Set authenticated user state
  void _setAuthenticatedUser(User user) {
    _currentUser = user;
    _isAuthenticated = true;
    _clearError();
    notifyListeners();
  }

  /// Set unauthenticated state
  void _setUnauthenticated() {
    _currentUser = null;
    _isAuthenticated = false;
    _clearError();
    notifyListeners();
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear error (public method for UI)
  void clearError() {
    _clearError();
  }

  @override
  void dispose() {
    super.dispose();
  }
}