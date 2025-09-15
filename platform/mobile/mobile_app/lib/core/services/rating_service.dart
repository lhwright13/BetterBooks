import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';
import 'analytics_service.dart';
import 'logging_service.dart';

/// Service to manage app rating prompts
class RatingService {
  static final RatingService _instance = RatingService._internal();
  factory RatingService() => _instance;
  RatingService._internal();
  
  static const String _keyFirstLaunchDate = 'first_launch_date';
  static const String _keyLaunchCount = 'launch_count';
  static const String _keyHasRated = 'has_rated';
  static const String _keyLastPromptDate = 'last_prompt_date';
  static const String _keyBooksCompleted = 'books_completed';
  
  final InAppReview _inAppReview = InAppReview.instance;
  
  /// Initialize rating service and track app launch
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Track first launch
    if (!prefs.containsKey(_keyFirstLaunchDate)) {
      await prefs.setInt(_keyFirstLaunchDate, DateTime.now().millisecondsSinceEpoch);
    }
    
    // Increment launch count
    final launchCount = prefs.getInt(_keyLaunchCount) ?? 0;
    await prefs.setInt(_keyLaunchCount, launchCount + 1);
    
    LoggingService.info('Rating service initialized. Launch count: ${launchCount + 1}');
  }
  
  /// Check if we should show rating prompt
  static Future<bool> shouldShowRatingPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Don't show if already rated
    if (prefs.getBool(_keyHasRated) ?? false) {
      return false;
    }
    
    // Check minimum requirements
    final launchCount = prefs.getInt(_keyLaunchCount) ?? 0;
    final booksCompleted = prefs.getInt(_keyBooksCompleted) ?? 0;
    final firstLaunchTime = prefs.getInt(_keyFirstLaunchDate);
    
    if (firstLaunchTime == null) return false;
    
    final daysSinceFirstLaunch = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(firstLaunchTime)
    ).inDays;
    
    // Show if:
    // - At least 7 days since first launch
    // - At least 5 app launches
    // - At least 1 book completed
    // - Haven't prompted in last 30 days
    
    if (daysSinceFirstLaunch < 7 || launchCount < 5 || booksCompleted < 1) {
      return false;
    }
    
    // Check last prompt date
    final lastPromptTime = prefs.getInt(_keyLastPromptDate);
    if (lastPromptTime != null) {
      final daysSinceLastPrompt = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(lastPromptTime)
      ).inDays;
      
      if (daysSinceLastPrompt < 30) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Show rating prompt
  static Future<void> showRatingPrompt(BuildContext context) async {
    final shouldShow = await shouldShowRatingPrompt();
    if (!shouldShow) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    // Show custom dialog first
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enjoying EchoWright?'),
        content: const Text(
          'We\'d love to hear your feedback! Would you mind rating us on the App Store?'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              AnalyticsService.logEvent('rating_prompt_declined');
            },
            child: const Text('Not Now'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              AnalyticsService.logEvent('rating_prompt_accepted');
            },
            child: const Text('Rate App'),
          ),
        ],
      ),
    );
    
    // Update last prompt date
    await prefs.setInt(_keyLastPromptDate, DateTime.now().millisecondsSinceEpoch);
    
    if (result == true) {
      await requestRating();
      await prefs.setBool(_keyHasRated, true);
    }
  }
  
  /// Request rating using native prompt
  static Future<void> requestRating() async {
    try {
      final available = await _instance._inAppReview.isAvailable();
      
      if (available) {
        await _instance._inAppReview.requestReview();
        AnalyticsService.logEvent('rating_requested');
        LoggingService.info('Rating prompt shown');
      } else {
        // Fallback to opening app store
        await _instance._inAppReview.openStoreListing();
        AnalyticsService.logEvent('store_listing_opened');
        LoggingService.info('Store listing opened');
      }
    } catch (e) {
      LoggingService.error('Failed to show rating prompt', error: e);
    }
  }
  
  /// Track book completion for rating triggers
  static Future<void> trackBookCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    final booksCompleted = prefs.getInt(_keyBooksCompleted) ?? 0;
    await prefs.setInt(_keyBooksCompleted, booksCompleted + 1);
    
    AnalyticsService.logEvent('book_completed', {
      'total_completed': booksCompleted + 1,
    });
    
    LoggingService.info('Book completion tracked. Total: ${booksCompleted + 1}');
  }
  
  /// Reset rating status (for testing)
  static Future<void> resetRatingStatus() async {
    if (LoggingService.instance == null) return; // Only in debug
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHasRated);
    await prefs.remove(_keyLastPromptDate);
    LoggingService.debug('Rating status reset');
  }
}