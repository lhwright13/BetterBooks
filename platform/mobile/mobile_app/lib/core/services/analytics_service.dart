import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/app_config.dart';

/// Centralized analytics and crash reporting service
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  FirebaseAnalyticsObserver? _observer;
  
  /// Initialize analytics services
  static Future<void> initialize() async {
    if (!AppConfig.isDebugMode) {
      try {
        // Initialize Firebase Analytics
        _instance._analytics = FirebaseAnalytics.instance;
        _instance._observer = FirebaseAnalyticsObserver(
          analytics: _instance._analytics!,
        );
        
        // Initialize Firebase Crashlytics
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
        
        // Pass all uncaught errors to Crashlytics
        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
        
        // Initialize Sentry if DSN is configured
        final sentryDsn = AppConfig.allEnvVars['SENTRY_DSN'];
        if (sentryDsn != null && sentryDsn.isNotEmpty) {
          await SentryFlutter.init(
            (options) {
              options.dsn = sentryDsn;
              options.environment = AppConfig.environmentName;
              options.tracesSampleRate = 0.3;
            },
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to initialize analytics: $e');
        }
      }
    }
  }
  
  /// Get the navigation observer for analytics
  static FirebaseAnalyticsObserver? get observer => _instance._observer;
  
  /// Log a custom event
  static Future<void> logEvent(String name, [Map<String, dynamic>? parameters]) async {
    if (_instance._analytics != null && !AppConfig.isDebugMode) {
      await _instance._analytics!.logEvent(
        name: name,
        parameters: parameters?.cast<String, Object>(),
      );
    }
  }
  
  /// Log screen view
  static Future<void> logScreenView(String screenName, [String? screenClass]) async {
    if (_instance._analytics != null && !AppConfig.isDebugMode) {
      await _instance._analytics!.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
    }
  }
  
  /// Log user action
  static Future<void> logUserAction(String action, {String? item, String? category}) async {
    await logEvent('user_action', {
      'action': action,
      if (item != null) 'item': item,
      if (category != null) 'category': category,
    });
  }
  
  /// Log book interaction
  static Future<void> logBookInteraction(String action, String bookId, String bookTitle) async {
    await logEvent('book_interaction', {
      'action': action,
      'book_id': bookId,
      'book_title': bookTitle,
    });
  }
  
  /// Log purchase event
  static Future<void> logPurchase(String bookId, double amount, String currency) async {
    if (_instance._analytics != null && !AppConfig.isDebugMode) {
      await _instance._analytics!.logPurchase(
        value: amount,
        currency: currency,
        items: [
          AnalyticsEventItem(
            itemId: bookId,
            itemCategory: 'audiobook',
          ),
        ],
      );
    }
  }
  
  /// Log sign up
  static Future<void> logSignUp(String method) async {
    if (_instance._analytics != null && !AppConfig.isDebugMode) {
      await _instance._analytics!.logSignUp(signUpMethod: method);
    }
  }
  
  /// Log login
  static Future<void> logLogin(String method) async {
    if (_instance._analytics != null && !AppConfig.isDebugMode) {
      await _instance._analytics!.logLogin(loginMethod: method);
    }
  }
  
  /// Set user properties
  static Future<void> setUserProperty(String name, String value) async {
    if (_instance._analytics != null && !AppConfig.isDebugMode) {
      await _instance._analytics!.setUserProperty(name: name, value: value);
    }
  }
  
  /// Set user ID for analytics
  static Future<void> setUserId(String? userId) async {
    if (_instance._analytics != null && !AppConfig.isDebugMode) {
      await _instance._analytics!.setUserId(id: userId);
    }
    
    // Also set for Sentry
    if (userId != null) {
      await Sentry.configureScope((scope) {
        scope.setUser(SentryUser(id: userId));
      });
    }
  }
  
  /// Log error to crash reporting
  static Future<void> logError(
    dynamic error, 
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!AppConfig.isDebugMode) {
      // Log to Firebase Crashlytics
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: fatal,
      );
      
      // Also log to Sentry if configured
      await Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          if (reason != null) {
            scope.setTag('reason', reason);
          }
          scope.level = fatal ? SentryLevel.fatal : SentryLevel.error;
        },
      );
    }
  }
  
  /// Log a breadcrumb for debugging
  static Future<void> addBreadcrumb(String message, {String? category, Map<String, dynamic>? data}) async {
    if (!AppConfig.isDebugMode) {
      await Sentry.addBreadcrumb(
        Breadcrumb(
          message: message,
          category: category,
          data: data,
        ),
      );
    }
  }
}