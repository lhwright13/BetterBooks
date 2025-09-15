import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/logging_service.dart';

// Import models
import '../../data/models/book_models.dart';

// Import screens
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/auth/enhanced_auth_screen.dart';
import '../../presentation/screens/simple_test_auth_screen.dart';
import '../../presentation/screens/onboarding/welcome_screen.dart';
import '../../presentation/screens/onboarding/subscription_screen.dart';
import '../../presentation/screens/onboarding/preferences_screen.dart';
import '../../presentation/navigation/main_navigation.dart';
import '../../presentation/screens/enhanced_book_details_screen.dart';
import '../../presentation/screens/player/full_player_screen.dart';
import '../../presentation/screens/voice_chat_screen.dart';
import '../../presentation/screens/profile_tab/wishlist_screen.dart';
import '../../presentation/screens/profile_tab/listening_history_screen.dart';
import '../../presentation/screens/profile_tab/downloads_screen.dart';
import '../../presentation/screens/profile_tab/app_settings_screen.dart';
import '../../presentation/screens/profile_tab/help_support_screen.dart';

// Import navigation components
import 'routes.dart';
import 'route_guards.dart';
import 'transitions/platform_transitions.dart';

/// Main application router using GoRouter (Navigator 2.0)
class AppRouter {
  static final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> _mainNavigatorKey = GlobalKey<NavigatorState>();
  
  /// Get the root navigator key for navigation outside of widget tree
  static GlobalKey<NavigatorState> get rootNavigatorKey => _rootNavigatorKey;
  static GlobalKey<NavigatorState> get mainNavigatorKey => _mainNavigatorKey;
  
  /// Create the main router instance
  static GoRouter createRouter() {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: AppRoutes.splash,
      debugLogDiagnostics: true,
      // Temporarily disable redirect to debug navigation issues
      // redirect: _handleRouteRedirect,
      routes: _createRoutes(),
      errorPageBuilder: (context, state) {
        // Log navigation errors
        LoggingService.error('Navigation error', error: state.error);
        return _buildErrorPage(context, state);
      },
    );
  }
  
  /// Handle route redirects based on authentication and guards
  static Future<String?> _handleRouteRedirect(
    BuildContext context,
    GoRouterState state,
  ) async {
    final location = state.uri.toString();
    final routeState = RouteState(
      location: location,
      pathParameters: state.pathParameters,
      queryParameters: state.uri.queryParameters,
      extra: state.extra,
    );
    
    // Check if we need to redirect based on route guards
    if (!await RouteGuardManager.canNavigateToRoute(routeState)) {
      final redirectRoute = await RouteGuardManager.getRedirectRoute(routeState);
      if (redirectRoute != null && redirectRoute != location) {
        return redirectRoute;
      }
    }
    
    return null; // No redirect needed
  }
  
  /// Create all application routes
  static List<RouteBase> _createRoutes() {
    return [
      // Splash route
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => _createPage(
          child: const SplashScreen(),
          type: TransitionType.fade,
          settings: RouteSettings(name: AppRoutes.splash),
        ),
      ),
      
      // Auth route - using simple test screen for debugging
      GoRoute(
        path: AppRoutes.auth,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const SimpleTestAuthScreen(),
        ),
      ),
      
      // Onboarding routes
      GoRoute(
        path: AppRoutes.onboardingWelcome,
        pageBuilder: (context, state) => _createPage(
          child: const WelcomeScreen(),
          type: TransitionType.push,
          settings: RouteSettings(name: AppRoutes.onboardingWelcome),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboardingSubscription,
        pageBuilder: (context, state) => _createPage(
          child: const SubscriptionScreen(),
          type: TransitionType.push,
          settings: RouteSettings(name: AppRoutes.onboardingSubscription),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboardingPreferences,
        pageBuilder: (context, state) => _createPage(
          child: const PreferencesScreen(),
          type: TransitionType.push,
          settings: RouteSettings(name: AppRoutes.onboardingPreferences),
        ),
      ),
      
      // Main navigation route
      GoRoute(
        path: AppRoutes.main,
        pageBuilder: (context, state) => _createPage(
          child: const MainNavigation(),
          type: TransitionType.fade,
          settings: RouteSettings(name: AppRoutes.main),
        ),
      ),
      
      // Book details route
      GoRoute(
        path: AppRoutes.bookDetails,
        pageBuilder: (context, state) {
          final bookId = state.pathParameters[RouteParams.bookId] ?? '';
          return _createPage(
            child: EnhancedBookDetailsScreen(bookId: bookId),
            type: TransitionType.push,
            settings: RouteSettings(name: AppRoutes.bookDetails),
          );
        },
      ),
      
      // Full player route
      GoRoute(
        path: AppRoutes.fullPlayer,
        pageBuilder: (context, state) {
          final bookId = state.pathParameters[RouteParams.bookId] ?? '';
          final book = state.extra as BrowseBook?;
          if (book != null) {
            return _createPage(
              child: FullPlayerScreen(book: book), 
              type: TransitionType.modal,
            );
          }
          // Redirect to book details if no book provided
          return _createPage(
            child: EnhancedBookDetailsScreen(bookId: bookId),
            type: TransitionType.push,
          );
        },
      ),
      
      // Voice chat route
      GoRoute(
        path: AppRoutes.voiceChat,
        pageBuilder: (context, state) {
          final bookId = state.pathParameters[RouteParams.bookId] ?? '';
          final book = state.extra as BrowseBook?;
          if (book != null) {
            return _createPage(
              child: VoiceChatScreen(book: book),
              type: TransitionType.modal,
            );
          }
          // Redirect to book details if no book provided
          return _createPage(
            child: EnhancedBookDetailsScreen(bookId: bookId),
            type: TransitionType.push,
          );
        },
      ),
      
      // Profile sub-routes
      GoRoute(
        path: AppRoutes.wishlist,
        pageBuilder: (context, state) => _createPage(
          child: const WishlistScreen(),
          type: TransitionType.push,
          settings: RouteSettings(name: AppRoutes.wishlist),
        ),
      ),
      GoRoute(
        path: AppRoutes.listeningHistory,
        pageBuilder: (context, state) => _createPage(
          child: const ListeningHistoryScreen(),
          type: TransitionType.push,
          settings: RouteSettings(name: AppRoutes.listeningHistory),
        ),
      ),
      GoRoute(
        path: AppRoutes.downloads,
        pageBuilder: (context, state) => _createPage(
          child: const DownloadsScreen(),
          type: TransitionType.push,
          settings: RouteSettings(name: AppRoutes.downloads),
        ),
      ),
      GoRoute(
        path: AppRoutes.appSettings,
        pageBuilder: (context, state) => _createPage(
          child: const AppSettingsScreen(),
          type: TransitionType.push,
          settings: RouteSettings(name: AppRoutes.appSettings),
        ),
      ),
      GoRoute(
        path: AppRoutes.helpSupport,
        pageBuilder: (context, state) => _createPage(
          child: const HelpSupportScreen(),
          type: TransitionType.push,
          settings: RouteSettings(name: AppRoutes.helpSupport),
        ),
      ),
    ];
  }
  
  /// Create a page with the appropriate transition
  static Page<dynamic> _createPage({
    required Widget child,
    required TransitionType type,
    RouteSettings? settings,
    Duration? duration,
  }) {
    return CustomTransitionPage(
      child: child,
      transitionType: type,
      duration: duration,
    );
  }
  
  /// Build error page for navigation errors
  static Page<dynamic> _buildErrorPage(BuildContext context, GoRouterState state) {
    return MaterialPage(
      key: state.pageKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Page Not Found'),
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Page Not Found',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'The page "${state.uri}" could not be found.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go(AppRoutes.main),
                  child: const Text('Go to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom transition page that uses platform-appropriate transitions
class CustomTransitionPage<T> extends Page<T> {
  final Widget child;
  final TransitionType transitionType;
  final Duration? duration;
  
  const CustomTransitionPage({
    required this.child,
    required this.transitionType,
    this.duration,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });
  
  @override
  Route<T> createRoute(BuildContext context) {
    return PlatformTransitions.createTransition(
      child: child,
      type: transitionType,
      settings: this,
      duration: duration,
    ) as Route<T>;
  }
}


/// Extension on GoRouter for additional functionality
extension AppRouterExtensions on GoRouter {
  /// Navigate with loading state
  Future<void> pushWithLoading(String location, {Object? extra}) async {
    // Show loading overlay if needed
    // Implementation would depend on loading system
    push(location, extra: extra);
  }
  
  /// Replace with loading state
  Future<void> pushReplacementWithLoading(String location, {Object? extra}) async {
    // Show loading overlay if needed
    pushReplacement(location, extra: extra);
  }
}