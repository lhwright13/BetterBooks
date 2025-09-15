import 'package:flutter/foundation.dart';
import '../services/logging_service.dart';

enum AppEnvironment {
  development,
  staging,
  production,
}

/// Production-ready app configuration that loads from environment files
class AppConfig {
  static AppEnvironment? _currentEnvironment;
  static bool _isInitialized = false;

  /// Initialize app configuration - must be called before using any other methods
  static Future<void> initialize({AppEnvironment? environment}) async {
    _currentEnvironment = environment ?? _detectEnvironment();
    _isInitialized = true;
    
    // Logging handled by LoggerService in production
  }

  /// Detect environment based on build mode and flavor
  static AppEnvironment _detectEnvironment() {
    if (kDebugMode) {
      return AppEnvironment.development;
    } else if (kProfileMode) {
      return AppEnvironment.staging;
    } else {
      return AppEnvironment.production;
    }
  }


  static void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'AppConfig not initialized. Call AppConfig.initialize() first.'
      );
    }
  }

  // Environment Info
  static AppEnvironment get currentEnvironment {
    _ensureInitialized();
    return _currentEnvironment!;
  }

  static String get environmentName {
    switch (currentEnvironment) {
      case AppEnvironment.development:
        return 'Development';
      case AppEnvironment.staging:
        return 'Staging';
      case AppEnvironment.production:
        return 'Production';
    }
  }

  // API Configuration
  static String get apiBaseUrl {
    _ensureInitialized();
    return 'http://128.203.92.141:8000'; // Azure cloud backend
  }

  // App Configuration
  static String get appName {
    _ensureInitialized();
    return 'EchoWright';
  }

  static String get appVersion => '1.0.0';

  // Feature Flags
  static bool get isDebugMode {
    _ensureInitialized();
    return currentEnvironment != AppEnvironment.production;
  }

  static bool get enableDetailedLogging {
    _ensureInitialized();
    return currentEnvironment == AppEnvironment.development;
  }

  static bool get enableMockData {
    _ensureInitialized();
    return false; // Always use real data
  }

  static bool get enableVoiceChat {
    _ensureInitialized();
    return true; // Voice chat enabled
  }

  static bool get enableOfflineMode {
    _ensureInitialized();
    return false; // Offline mode disabled for MVP
  }

  static bool get enablePushNotifications {
    _ensureInitialized();
    return false; // Push notifications disabled for MVP
  }

  // Network Configuration
  static Duration get httpTimeout {
    _ensureInitialized();
    return const Duration(seconds: 30);
  }

  static Duration get downloadTimeout {
    _ensureInitialized();
    return const Duration(minutes: 10);
  }

  static int get maxCacheSize {
    _ensureInitialized();
    return 100 * 1024 * 1024; // 100MB in bytes
  }

  static int get maxDownloadRetries {
    _ensureInitialized();
    return 3;
  }

  // Audio Configuration
  static double get defaultPlaybackSpeed {
    _ensureInitialized();
    return 1.0;
  }

  static List<double> get availablePlaybackSpeeds => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  // UI Configuration
  static int get booksPerPage {
    _ensureInitialized();
    return 20;
  }

  static int get searchResultsPerPage {
    _ensureInitialized();
    return 20;
  }

  // Storage Configuration
  static String get openLibraryBaseUrl => 'https://covers.openlibrary.org';

  /// Get all configuration values (for debugging)
  static Map<String, String> get allConfigVars {
    _ensureInitialized();
    return {
      'API_BASE_URL': apiBaseUrl,
      'ENVIRONMENT': environmentName,
      'APP_NAME': appName,
      'APP_VERSION': appVersion,
    };
  }

  /// Validate that all required configuration is present
  static bool validateConfiguration() {
    _ensureInitialized();
    
    if (apiBaseUrl.isEmpty || appName.isEmpty) {
      LoggingService.error('Missing required configuration values');
      return false;
    }

    LoggingService.info('All required configuration values are present');
    
    return true;
  }
}