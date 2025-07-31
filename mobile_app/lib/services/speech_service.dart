/**
 * speech_service.dart - Speech recognition service stub for Muuchi
 * 
 * This file provides a simplified speech recognition interface for the Muuchi
 * audiobook companion app. Currently implemented as a stub that disables speech
 * recognition to avoid JavaScript interop complexity on certain platforms.
 * 
 * Key responsibilities:
 * - Provide speech recognition API interface
 * - Handle platform compatibility for voice input
 * - Fallback to text input when speech is unavailable
 * - Support future integration with platform-specific speech APIs
 * 
 * Current implementation:
 * - Returns false for speech support to force text input mode
 * - Throws exceptions when speech recognition is attempted
 * - Designed to be easily replaceable with full implementation
 * 
 * Future enhancements:
 * - Integrate with platform-specific speech recognition APIs
 * - Support real-time voice input for chat conversations
 * - Handle speech-to-text conversion for AI persona interactions
 * - Complement TTS output with voice input capabilities
 * 
 * Platform considerations:
 * - Web: Could use Web Speech API (currently disabled)
 * - Mobile: Could use speech_to_text package (future implementation)
 * - Desktop: Platform-specific speech recognition APIs
 * 
 * Note: For full speech functionality, see web_speech_service.dart
 */

/// Simplified speech recognition service that currently disables speech input
/// Serves as a stub implementation to avoid JavaScript interop issues
/// Can be replaced with full speech recognition functionality in the future
class SpeechService {
  /// Returns whether speech recognition is supported on this platform
  /// Currently always returns false to force text input mode
  /// This avoids JavaScript interop complexity while maintaining API compatibility
  static bool get isSupported {
    // For now, always return false to use text input
    // This avoids all the JavaScript interop issues
    return false;
  }

  /// Attempts to start speech recognition (currently throws exception)
  /// Returns recognized text when speech recognition is fully implemented
  /// Forces users to use text input until speech is properly supported
  static Future<String> startListening() async {
    throw Exception('Speech recognition not available - please use text input');
  }

  /// Stops speech recognition if it was active
  /// Currently a no-op since speech recognition is disabled
  static void stopListening() {
    // No-op - speech recognition is disabled
  }

  /// Returns whether speech recognition is currently active
  /// Always returns false since speech recognition is disabled
  static bool get isListening => false;
}