import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Simplified Firebase service manager for essential services only
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Service instances
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  FirebaseStorage? _storage;
  FirebaseAnalytics? _analytics;
  FirebaseCrashlytics? _crashlytics;

  // Initialization flag
  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialize Firebase and essential services
  static Future<bool> initialize() async {
    if (_instance._initialized) {
      return true;
    }

    try {
      // Initialize Firebase app
      await Firebase.initializeApp();
      
      // Initialize individual services
      await _instance._initializeServices();
      
      _instance._initialized = true;
      
      if (kDebugMode) {
        print('✅ Firebase services initialized successfully');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase initialization error: $e');
      }
      return false;
    }
  }

  /// Initialize individual Firebase services
  Future<void> _initializeServices() async {
    try {
      // Initialize Auth
      _auth = FirebaseAuth.instance;
      
      // Initialize Firestore with settings
      _firestore = FirebaseFirestore.instance;
      _firestore!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      // Initialize Storage
      _storage = FirebaseStorage.instance;
      
      // Initialize Analytics
      _analytics = FirebaseAnalytics.instance;
      await _analytics!.setAnalyticsCollectionEnabled(!kDebugMode);
      
      // Initialize Crashlytics
      _crashlytics = FirebaseCrashlytics.instance;
      if (!kDebugMode) {
        await _crashlytics!.setCrashlyticsCollectionEnabled(true);
        FlutterError.onError = _crashlytics!.recordFlutterError;
      } else {
        await _crashlytics!.setCrashlyticsCollectionEnabled(false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error initializing Firebase services: $e');
      }
    }
  }

  // Service Getters
  FirebaseAuth get auth {
    if (_auth == null) {
      throw StateError('Firebase Auth not initialized. Call FirebaseService.initialize() first.');
    }
    return _auth!;
  }

  FirebaseFirestore get firestore {
    if (_firestore == null) {
      throw StateError('Firestore not initialized. Call FirebaseService.initialize() first.');
    }
    return _firestore!;
  }

  FirebaseStorage get storage {
    if (_storage == null) {
      throw StateError('Firebase Storage not initialized. Call FirebaseService.initialize() first.');
    }
    return _storage!;
  }

  FirebaseAnalytics get analytics {
    if (_analytics == null) {
      throw StateError('Firebase Analytics not initialized. Call FirebaseService.initialize() first.');
    }
    return _analytics!;
  }

  FirebaseCrashlytics get crashlytics {
    if (_crashlytics == null) {
      throw StateError('Firebase Crashlytics not initialized. Call FirebaseService.initialize() first.');
    }
    return _crashlytics!;
  }

  /// Log an analytics event
  Future<void> logEvent(String name, {Map<String, dynamic>? parameters}) async {
    try {
      final Map<String, Object>? analyticsParams = parameters?.map(
        (key, value) => MapEntry(key, value as Object),
      );
      
      await analytics.logEvent(
        name: name,
        parameters: analyticsParams,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error logging event: $e');
      }
    }
  }

  /// Log an error to Crashlytics
  Future<void> logError(dynamic error, StackTrace? stackTrace, {String? reason}) async {
    try {
      await crashlytics.recordError(
        error,
        stackTrace,
        reason: reason,
        printDetails: kDebugMode,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error logging to Crashlytics: $e');
      }
    }
  }

  /// Set user properties for analytics and crashlytics
  Future<void> setUserProperties({
    String? userId,
    Map<String, String>? properties,
  }) async {
    try {
      if (userId != null) {
        await analytics.setUserId(id: userId);
        await crashlytics.setUserIdentifier(userId);
      }
      
      if (properties != null) {
        for (final entry in properties.entries) {
          await analytics.setUserProperty(
            name: entry.key,
            value: entry.value,
          );
          await crashlytics.setCustomKey(entry.key, entry.value);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error setting user properties: $e');
      }
    }
  }

  /// Clean up and dispose resources
  Future<void> dispose() async {
    _initialized = false;
  }
}

/// Extension for easy access to Firebase services
extension FirebaseServiceExtension on BuildContext {
  FirebaseService get firebase => FirebaseService();
  FirebaseAuth get auth => FirebaseService().auth;
  FirebaseFirestore get firestore => FirebaseService().firestore;
  FirebaseStorage get storage => FirebaseService().storage;
  FirebaseAnalytics get analytics => FirebaseService().analytics;
}