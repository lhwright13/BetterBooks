/// Application route definitions and constants
/// This file centralizes all navigation routes for consistent routing throughout the app
class AppRoutes {
  static const String splash = '/';
  static const String auth = '/auth';
  static const String onboardingWelcome = '/onboarding/welcome';
  static const String onboardingSubscription = '/onboarding/subscription';
  static const String onboardingPreferences = '/onboarding/preferences';
  static const String main = '/main';
  
  // Tab routes - these are handled by the main navigation
  static const String home = '/main/home';
  static const String library = '/main/library';
  static const String discover = '/main/discover';
  static const String profile = '/main/profile';
  
  // Book-related routes
  static const String bookDetails = '/book/:bookId';
  static const String fullPlayer = '/player/:bookId';
  static const String voiceChat = '/chat/:bookId';
  
  // Profile sub-routes
  static const String wishlist = '/profile/wishlist';
  static const String listeningHistory = '/profile/history';
  static const String downloads = '/profile/downloads';
  static const String appSettings = '/profile/settings';
  static const String helpSupport = '/profile/help';
  
  // Auth sub-routes  
  static const String signIn = '/auth/signin';
  static const String signUp = '/auth/signup';
  static const String forgotPassword = '/auth/forgot-password';
  
  // Utility method to generate route with parameters
  static String bookDetailsRoute(String bookId) => '/book/$bookId';
  static String fullPlayerRoute(String bookId) => '/player/$bookId';
  static String voiceChatRoute(String bookId) => '/chat/$bookId';
  
  // Deep linking routes
  static const String deepLinkPrefix = 'echowright://';
  static const String webPrefix = 'https://app.echowright.com';
  
  // Route groups for access control
  static const List<String> publicRoutes = [
    splash,
    auth,
    signIn,
    signUp,
    forgotPassword,
  ];
  
  static const List<String> onboardingRoutes = [
    onboardingWelcome,
    onboardingSubscription,
    onboardingPreferences,
  ];
  
  static const List<String> authenticatedRoutes = [
    main,
    home,
    library,
    discover,
    profile,
    bookDetails,
    fullPlayer,
    voiceChat,
    wishlist,
    listeningHistory,
    downloads,
    appSettings,
    helpSupport,
  ];
  
  static const List<String> premiumRoutes = [
    fullPlayer,
    voiceChat,
    downloads,
  ];
}

/// Route parameter keys
class RouteParams {
  static const String bookId = 'bookId';
  static const String userId = 'userId';
  static const String category = 'category';
  static const String searchQuery = 'searchQuery';
  static const String tab = 'tab';
}

/// Route state for maintaining navigation context
class RouteState {
  final String location;
  final Map<String, String> pathParameters;
  final Map<String, String> queryParameters;
  final Object? extra;
  
  const RouteState({
    required this.location,
    this.pathParameters = const {},
    this.queryParameters = const {},
    this.extra,
  });
  
  /// Get a path parameter by key
  String? getPathParam(String key) => pathParameters[key];
  
  /// Get a query parameter by key
  String? getQueryParam(String key) => queryParameters[key];
  
  /// Check if route is in a specific group
  bool isPublicRoute() => AppRoutes.publicRoutes.contains(location);
  bool isOnboardingRoute() => AppRoutes.onboardingRoutes.contains(location);
  bool isAuthenticatedRoute() => AppRoutes.authenticatedRoutes.any((route) => location.startsWith(route.split(':').first));
  bool isPremiumRoute() => AppRoutes.premiumRoutes.any((route) => location.startsWith(route.split(':').first));
}