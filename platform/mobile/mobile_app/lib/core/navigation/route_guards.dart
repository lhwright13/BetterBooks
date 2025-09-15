import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'routes.dart';

/// Abstract base class for route guards
abstract class RouteGuard {
  /// Check if navigation is allowed
  Future<bool> canNavigate(RouteState routeState);
  
  /// Get redirect route if navigation is blocked
  String? getRedirectRoute(RouteState routeState);
  
  /// Handle guard failure (optional custom handling)
  Future<void> onGuardFailure(BuildContext context, RouteState routeState) async {
    // Default: no action
  }
}

/// Authentication guard - ensures user is authenticated
class AuthGuard extends RouteGuard {
  @override
  Future<bool> canNavigate(RouteState routeState) async {
    return await AuthService.isAuthenticated();
  }

  @override
  String? getRedirectRoute(RouteState routeState) {
    return AppRoutes.auth;
  }

  @override
  Future<void> onGuardFailure(BuildContext context, RouteState routeState) async {
    // Could show login prompt or store intended destination
    await _storeIntendedRoute(routeState.location);
  }
  
  Future<void> _storeIntendedRoute(String route) async {
    // Store intended route for redirect after login
    // This could be implemented with shared preferences or secure storage
  }
}

/// Onboarding guard - ensures user has completed onboarding
class OnboardingGuard extends RouteGuard {
  @override
  Future<bool> canNavigate(RouteState routeState) async {
    if (!await AuthService.isAuthenticated()) {
      return false;
    }
    
    // Check if user has completed onboarding
    final user = await AuthService.getCurrentUser();
    return user?['onboarding_completed'] == true;
  }

  @override
  String? getRedirectRoute(RouteState routeState) {
    return AppRoutes.onboardingWelcome;
  }

  @override
  Future<void> onGuardFailure(BuildContext context, RouteState routeState) async {
    // Could show onboarding reminder
  }
}

/// Subscription guard - ensures user has active subscription for premium content
class SubscriptionGuard extends RouteGuard {
  @override
  Future<bool> canNavigate(RouteState routeState) async {
    if (!await AuthService.isAuthenticated()) {
      return false;
    }
    
    // Check if user has active subscription or credits
    try {
      // For now, return true for authenticated users
      // This should be replaced with actual credit checking
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  String? getRedirectRoute(RouteState routeState) {
    return AppRoutes.onboardingSubscription;
  }

  @override
  Future<void> onGuardFailure(BuildContext context, RouteState routeState) async {
    // Show subscription prompt
    await _showSubscriptionPrompt(context);
  }
  
  Future<void> _showSubscriptionPrompt(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium Feature'),
        content: const Text('This feature requires credits. Would you like to get more credits?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed(AppRoutes.onboardingSubscription);
            },
            child: const Text('Get Credits'),
          ),
        ],
      ),
    );
  }
}

/// Guest access guard - blocks guests from certain features
class GuestAccessGuard extends RouteGuard {
  @override
  Future<bool> canNavigate(RouteState routeState) async {
    final isAuthenticated = await AuthService.isAuthenticated();
    if (!isAuthenticated) {
      // Allow guest access to certain routes
      return _isGuestAllowedRoute(routeState.location);
    }
    return true;
  }

  @override
  String? getRedirectRoute(RouteState routeState) {
    return AppRoutes.auth;
  }

  @override
  Future<void> onGuardFailure(BuildContext context, RouteState routeState) async {
    await _showGuestLimitationDialog(context);
  }
  
  bool _isGuestAllowedRoute(String route) {
    const guestAllowedRoutes = [
      AppRoutes.discover,
      AppRoutes.bookDetails,
      // Add other routes that guests can access
    ];
    
    return guestAllowedRoutes.any((allowedRoute) => 
      route.startsWith(allowedRoute.split(':').first));
  }
  
  Future<void> _showGuestLimitationDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign In Required'),
        content: const Text('Please sign in to access this feature.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed(AppRoutes.auth);
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}

/// Route guard manager - manages and applies guards
class RouteGuardManager {
  static final Map<String, List<RouteGuard>> _routeGuards = {
    // Authenticated routes require auth guard
    AppRoutes.main: [AuthGuard(), OnboardingGuard()],
    AppRoutes.library: [AuthGuard(), OnboardingGuard()],
    AppRoutes.profile: [AuthGuard(), OnboardingGuard()],
    AppRoutes.wishlist: [AuthGuard(), OnboardingGuard()],
    AppRoutes.listeningHistory: [AuthGuard(), OnboardingGuard()],
    AppRoutes.downloads: [AuthGuard(), OnboardingGuard()],
    AppRoutes.appSettings: [AuthGuard(), OnboardingGuard()],
    
    // Premium routes require subscription
    AppRoutes.fullPlayer: [AuthGuard(), OnboardingGuard(), SubscriptionGuard()],
    AppRoutes.voiceChat: [AuthGuard(), OnboardingGuard(), SubscriptionGuard()],
    
    // Guest-limited routes
    AppRoutes.bookDetails: [GuestAccessGuard()],
  };
  
  /// Check if navigation to route is allowed
  static Future<bool> canNavigateToRoute(RouteState routeState) async {
    final guards = _getGuardsForRoute(routeState.location);
    
    for (final guard in guards) {
      if (!await guard.canNavigate(routeState)) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Get redirect route if navigation is blocked
  static Future<String?> getRedirectRoute(RouteState routeState) async {
    final guards = _getGuardsForRoute(routeState.location);
    
    for (final guard in guards) {
      if (!await guard.canNavigate(routeState)) {
        return guard.getRedirectRoute(routeState);
      }
    }
    
    return null;
  }
  
  /// Handle guard failures
  static Future<void> handleGuardFailure(
    BuildContext context,
    RouteState routeState,
  ) async {
    final guards = _getGuardsForRoute(routeState.location);
    
    for (final guard in guards) {
      if (!await guard.canNavigate(routeState)) {
        await guard.onGuardFailure(context, routeState);
        break; // Handle only the first failing guard
      }
    }
  }
  
  /// Get guards for a specific route
  static List<RouteGuard> _getGuardsForRoute(String route) {
    final guards = <RouteGuard>[];
    
    for (final entry in _routeGuards.entries) {
      if (route.startsWith(entry.key.split(':').first)) {
        guards.addAll(entry.value);
      }
    }
    
    return guards;
  }
  
  /// Add custom guard to route
  static void addGuard(String route, RouteGuard guard) {
    _routeGuards[route] ??= [];
    _routeGuards[route]!.add(guard);
  }
  
  /// Remove guard from route
  static void removeGuard(String route, RouteGuard guard) {
    _routeGuards[route]?.remove(guard);
  }
}