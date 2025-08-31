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
import '../services/log_service.dart';

/// Global authentication state provider
/// Manages user authentication state and provides auth methods to the UI
class AuthProvider extends ChangeNotifier {
  // Current user state
  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;
  
  // Credit system
  int _totalCredits = 0;
  int _usedCredits = 0;
  int _availableCredits = 0;

  // Getters for current state
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  
  // Credit system getters
  int get totalCredits => _totalCredits;
  int get usedCredits => _usedCredits;
  int get availableCredits => _availableCredits;

  /// Initialize authentication state on app startup
  /// Checks for existing valid session and restores user state
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _setLoading(true);
    
    try {
      // Check if user has valid authentication
      final isAuth = await AuthService.isAuthenticated();
      
      if (isAuth) {
        // Try to fetch fresh user data from server first
        final freshUser = await AuthService.fetchCurrentUser();
        if (freshUser != null) {
          _setAuthenticatedUser(freshUser);
        } else {
          // Fallback to stored user data
          final user = await AuthService.getCurrentUser();
          if (user != null) {
            _setAuthenticatedUser(user);
          } else {
            _setUnauthenticated();
          }
        }
      } else {
        _setUnauthenticated();
      }
    } catch (e) {
      LogService.debug('Auth initialization error: $e');
      _setUnauthenticated();
    } finally {
      _isInitialized = true;
      _setLoading(false);
    }
  }

  /// Sign in with Google OAuth - Coming Soon
  Future<bool> signInWithGoogle() async {
    _setError('Google Sign In coming soon! Please use email registration for now.');
    return false;
  }

  /// Sign in with Apple - Coming Soon
  Future<bool> signInWithApple() async {
    _setError('Apple Sign In coming soon! Please use email registration for now.');
    return false;
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
        
        // Fetch fresh user data from server to ensure we have latest info
        _fetchFreshUserData();
        
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
        
        // Fetch fresh user data from server to ensure we have latest info
        _fetchFreshUserData();
        
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
      LogService.debug('Sign out error: $e');
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
      LogService.debug('Error refreshing user: $e');
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

  /// Load user's credit balance
  Future<void> loadCreditBalance() async {
    try {
      final response = await AuthService.getCreditBalance();
      _totalCredits = response['total_credits'] ?? 0;
      _usedCredits = response['used_credits'] ?? 0;
      _availableCredits = response['available_credits'] ?? 0;
      
      // Note: All credits should be 0 since all books are free
      LogService.debug('Credit balance loaded: Total=$_totalCredits, Used=$_usedCredits, Available=$_availableCredits');
      notifyListeners();
    } catch (e) {
      LogService.debug('Error loading credit balance: $e');
      // Set defaults (all 0 since books are free)
      _totalCredits = 0;
      _usedCredits = 0;
      _availableCredits = 0;
      notifyListeners();
    }
  }

  /// Update credit balance after a purchase
  void updateCredits(int totalCredits, int usedCredits, int availableCredits) {
    _totalCredits = totalCredits;
    _usedCredits = usedCredits;
    _availableCredits = availableCredits;
    notifyListeners();
  }

  /// Initialize credits for a new user
  Future<void> initializeCredits() async {
    try {
      await AuthService.initializeCredits();
      await loadCreditBalance(); // Refresh balance (should show 0 credits)
      LogService.debug('Credits initialized for new user (all books are free in EchoWright)');
    } catch (e) {
      LogService.debug('Error initializing credits: $e');
      // Set default 0 credits since all books are free
      _totalCredits = 0;
      _usedCredits = 0;
      _availableCredits = 0;
      notifyListeners();
    }
  }

  /// Get user's library of owned books
  Future<Map<String, dynamic>> getUserLibrary({int limit = 50, int offset = 0}) async {
    try {
      return await AuthService.getUserLibrary(limit: limit, offset: offset);
    } catch (e) {
      LogService.debug('Error getting user library: $e');
      return {'books': [], 'total_count': 0};
    }
  }

  /// Purchase a book (free with EchoWright)
  Future<Map<String, dynamic>> purchaseBook(String bookId) async {
    try {
      final result = await AuthService.purchaseBook(bookId);
      
      if (result['success'] == true) {
        // Refresh credit balance (though it should remain 0)
        await loadCreditBalance();
        LogService.debug('Book purchased successfully: $bookId (Free with EchoWright)');
      }
      
      return result;
    } catch (e) {
      LogService.debug('Error purchasing book: $e');
      return {
        'success': false,
        'message': 'Purchase failed: $e',
      };
    }
  }

  /// Check if user owns a specific book
  Future<bool> checkBookOwnership(String bookId) async {
    try {
      return await AuthService.checkBookOwnership(bookId);
    } catch (e) {
      LogService.debug('Error checking book ownership: $e');
      return false;
    }
  }

  /// Fetch fresh user data from server in background
  void _fetchFreshUserData() async {
    try {
      final freshUser = await AuthService.fetchCurrentUser();
      if (freshUser != null && _isAuthenticated) {
        _currentUser = freshUser;
        notifyListeners();
        LogService.debug('User data refreshed from server');
      }
    } catch (e) {
      LogService.debug('Failed to refresh user data: $e');
      // Don't show error to user - this is a background refresh
    }
  }

  /// Manually refresh user data from server
  Future<bool> refreshUserData() async {
    if (!_isAuthenticated) return false;
    
    _setLoading(true);
    
    try {
      final freshUser = await AuthService.fetchCurrentUser();
      if (freshUser != null) {
        _currentUser = freshUser;
        notifyListeners();
        LogService.debug('User data refreshed manually');
        return true;
      }
      return false;
    } catch (e) {
      LogService.debug('Failed to refresh user data: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}