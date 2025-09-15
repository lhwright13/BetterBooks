import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../navigation/app_router.dart';
import '../navigation/routes.dart';
import '../../presentation/widgets/navigation_loading_overlay.dart';

/// Centralized navigation service for consistent routing throughout the app
/// Updated to work with GoRouter and new navigation system
class NavigationService {
  static final NavigationLoadingManager _loadingManager = NavigationLoadingManager();
  
  /// Get the router instance
  static GoRouter get router => GoRouter.of(AppRouter.rootNavigatorKey.currentContext!);
  
  /// Get current navigation context
  static BuildContext? get currentContext => AppRouter.rootNavigatorKey.currentContext;
  
  /// Get loading manager instance
  static NavigationLoadingManager get loadingManager => _loadingManager;
  
  // MARK: - Basic Navigation
  
  /// Navigate to a route by path
  static Future<void> go(String location, {Object? extra}) async {
    try {
      router.go(location, extra: extra);
    } catch (e) {
      debugPrint('Navigation error: $e');
    }
  }
  
  /// Push a new route
  static Future<T?> push<T extends Object?>(String location, {Object? extra}) async {
    try {
      return await router.push<T>(location, extra: extra);
    } catch (e) {
      debugPrint('Navigation error: $e');
      return null;
    }
  }
  
  /// Replace current route
  static Future<T?> pushReplacement<T extends Object?>(String location, {Object? extra}) async {
    try {
      return await router.pushReplacement<T>(location, extra: extra);
    } catch (e) {
      debugPrint('Navigation error: $e');
      return null;
    }
  }
  
  /// Navigate back
  static void pop<T extends Object?>([T? result]) {
    try {
      router.pop(result);
    } catch (e) {
      debugPrint('Navigation error: $e');
    }
  }
  
  /// Check if we can navigate back
  static bool canPop() {
    try {
      return router.canPop();
    } catch (e) {
      debugPrint('Navigation error: $e');
      return false;
    }
  }
  
  // MARK: - Navigation with Loading
  
  /// Navigate with loading state
  static Future<void> goWithLoading(
    String location, {
    Object? extra,
    String? loadingText,
    Duration? loadingDuration,
  }) async {
    _loadingManager.showLoading(text: loadingText);
    
    try {
      // Add slight delay for loading animation
      if (loadingDuration != null) {
        await Future.delayed(loadingDuration);
      }
      
      router.go(location, extra: extra);
    } finally {
      _loadingManager.hideLoading();
    }
  }
  
  /// Push with loading state
  static Future<T?> pushWithLoading<T extends Object?>(
    String location, {
    Object? extra,
    String? loadingText,
    Duration? loadingDuration,
  }) async {
    _loadingManager.showLoading(text: loadingText);
    
    try {
      if (loadingDuration != null) {
        await Future.delayed(loadingDuration);
      }
      
      return await router.push<T>(location, extra: extra);
    } finally {
      _loadingManager.hideLoading();
    }
  }
  
  // MARK: - Convenience Methods
  
  /// Navigate to book details
  static Future<void> goToBookDetails(String bookId, {bool withLoading = true}) {
    final route = AppRoutes.bookDetailsRoute(bookId);
    if (withLoading) {
      return goWithLoading(route, loadingText: 'Loading book details...');
    }
    return go(route);
  }
  
  /// Navigate to full player with book object
  static Future<void> goToFullPlayer(String bookId, {Object? book, bool withLoading = true}) {
    final route = AppRoutes.fullPlayerRoute(bookId);
    if (withLoading) {
      return pushWithLoading(route, extra: book, loadingText: 'Opening player...');
    }
    return push(route, extra: book);
  }
  
  /// Navigate to voice chat with book object
  static Future<void> goToVoiceChat(String bookId, {Object? book, bool withLoading = true}) {
    final route = AppRoutes.voiceChatRoute(bookId);
    if (withLoading) {
      return pushWithLoading(route, extra: book, loadingText: 'Starting voice chat...');
    }
    return push(route, extra: book);
  }
  
  /// Navigate to authentication
  static Future<void> goToAuth({bool replace = false}) {
    if (replace) {
      return pushReplacement(AppRoutes.auth);
    }
    return go(AppRoutes.auth);
  }
  
  /// Navigate to main app
  static Future<void> goToMain({bool replace = true}) {
    if (replace) {
      return pushReplacement(AppRoutes.main);
    }
    return go(AppRoutes.main);
  }
  
  /// Navigate to onboarding
  static Future<void> goToOnboarding({bool replace = false}) {
    final route = AppRoutes.onboardingWelcome;
    if (replace) {
      return pushReplacement(route);
    }
    return go(route);
  }
  
  // MARK: - Profile Navigation
  
  /// Navigate to wishlist
  static Future<void> goToWishlist() => push(AppRoutes.wishlist);
  
  /// Navigate to listening history
  static Future<void> goToHistory() => push(AppRoutes.listeningHistory);
  
  /// Navigate to downloads
  static Future<void> goToDownloads() => push(AppRoutes.downloads);
  
  /// Navigate to app settings
  static Future<void> goToAppSettings() => push(AppRoutes.appSettings);
  
  /// Navigate to help & support
  static Future<void> goToHelp() => push(AppRoutes.helpSupport);
  
  // MARK: - Error Handling
  
  /// Show navigation error dialog
  static Future<void> showNavigationError(String message) async {
    final context = currentContext;
    if (context == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Navigation Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Global callback for tab switching in main navigation
/// Set by MainNavigation widget to allow child widgets to switch tabs
void Function(int)? switchToTab;

/// Helper methods for switching to specific tabs
class TabNavigation {
  /// Switch to Home tab (index 0)
  static void goToHome() {
    switchToTab?.call(0);
  }

  /// Switch to Library tab (index 1)
  static void goToLibrary() {
    switchToTab?.call(1);
  }

  /// Switch to Discover tab (index 2)
  static void goToDiscover() {
    switchToTab?.call(2);
  }

  /// Switch to Profile tab (index 3)
  static void goToProfile() {
    switchToTab?.call(3);
  }
}