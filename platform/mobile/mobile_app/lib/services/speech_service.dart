/**
 * speech_service.dart - Speech recognition service for BetterBooks
 * 
 * This file provides a speech recognition interface that currently uses 
 * text input fallback for maximum compatibility. This allows the demo
 * to work while we resolve platform-specific speech recognition setup.
 * 
 * Key responsibilities:
 * - Provide consistent API for voice input interactions
 * - Handle graceful fallback to text input when speech isn't available
 * - Support future integration with platform-specific speech APIs
 * 
 * Current implementation:
 * - Prompts for text input instead of voice (for demo compatibility)
 * - Designed to be easily replaceable with full speech implementation
 * - Maintains consistent API for the rest of the application
 * 
 * Future enhancement:
 * - Can be upgraded to use speech_to_text package when iOS config is resolved
 * - Will seamlessly transition to real voice input without changing app code
 */

/// Speech recognition service with text input fallback
/// Provides consistent API while allowing for future speech integration
class SpeechService {
  static bool _isListening = false;

  /// Returns whether speech recognition is supported on this platform
  /// Currently returns false to use text input fallback for demo
  static Future<bool> get isSupported async {
    // Return false to trigger text input fallback
    // This ensures the demo works while we resolve speech_to_text setup
    return false;
  }

  /// Starts speech recognition and returns the recognized text
  /// In iOS simulator, immediately triggers text input dialog
  static Future<String> startListening() async {
    _isListening = true;
    
    // Simulate brief listening period for UI feedback
    await Future.delayed(Duration(milliseconds: 300));
    _isListening = false;
    
    // For iOS simulator compatibility, always trigger text input
    // This provides the same user experience as voice input
    throw Exception('Voice input not available - switching to text input');
  }

  /// Stops speech recognition if it's currently active
  /// Safe to call even if recognition is not active
  static Future<void> stopListening() async {
    _isListening = false;
  }

  /// Returns whether speech recognition is currently active
  static bool get isListening => _isListening;

  /// Check if the service has microphone permission
  /// Returns false since we're using text input fallback
  static Future<bool> get hasPermission async {
    return false;
  }
}