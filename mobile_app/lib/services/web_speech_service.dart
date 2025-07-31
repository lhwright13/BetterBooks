/**
 * web_speech_service.dart - Web-based speech recognition and synthesis for Muuchi
 * 
 * This file provides full speech functionality for the Muuchi audiobook companion
 * app when running on web platforms. It uses the browser's Web Speech API for
 * both speech recognition (voice input) and speech synthesis (TTS output).
 * 
 * Key responsibilities:
 * - Voice input recognition using Web Speech Recognition API
 * - Text-to-speech synthesis using Web Speech Synthesis API
 * - Handle browser compatibility and feature detection
 * - Manage speech recognition lifecycle and events
 * - Provide alternative to backend TTS Service for web platforms
 * 
 * Features:
 * - Real-time speech recognition for chat input
 * - Browser-based text-to-speech synthesis
 * - Support for both webkit and standard Speech Recognition APIs
 * - Configurable voice parameters (rate, pitch, volume)
 * - Error handling and platform compatibility checks
 * 
 * Browser support:
 * - Chrome/Edge: Full support (webkitSpeechRecognition)
 * - Firefox: Limited support (SpeechRecognition standard)
 * - Safari: Partial support depending on version
 * - Mobile browsers: Variable support
 * 
 * Backend integration:
 * - Can complement or replace TTS Service calls
 * - Speech recognition results sent to LLM Gateway for AI responses
 * - Provides client-side speech processing to reduce server load
 * 
 * Note: This is web-specific. For cross-platform stub, see speech_service.dart
 */

import 'dart:async';
import 'dart:io' show Platform;

// Web-only imports for JavaScript interop with browser Speech APIs
import 'dart:js' as js;

/// Web-based speech recognition service using browser's Web Speech API
/// Provides voice input functionality for chat conversations
class WebSpeechService {
  static dynamic _recognition;           // JavaScript SpeechRecognition object
  static Completer<String>? _completer;   // Async completion handler for recognition results
  static bool _isListening = false;       // Track whether speech recognition is active

  /// Checks if Web Speech Recognition API is available in current browser
  /// Tests for both webkit and standard SpeechRecognition implementations
  /// Returns false on non-web platforms to prevent JavaScript errors
  static bool get isSupported {
    try {
      // Only supported on web platform
      if (Platform.isIOS || Platform.isAndroid || Platform.isMacOS) {
        return false;
      }
      final hasWebkit = js.context.hasProperty('webkitSpeechRecognition');
      final hasStandard = js.context.hasProperty('SpeechRecognition');
      print('DEBUG: webkitSpeechRecognition: $hasWebkit, SpeechRecognition: $hasStandard');
      return hasWebkit || hasStandard;
    } catch (e) {
      print('DEBUG: Speech support check failed: $e');
      return false;
    }
  }

  /// Starts speech recognition and returns the recognized text
  /// Uses browser's microphone to capture and transcribe speech
  /// Throws exception if already listening or speech not supported
  static Future<String> startListening() async {
    if (!isSupported) {
      throw Exception('Speech recognition not supported');
    }

    if (_isListening) {
      throw Exception('Already listening');
    }

    _completer = Completer<String>();
    _isListening = true;

    try {
      // Create JavaScript SpeechRecognition object (try webkit first, then standard)
      final recognitionClass = js.context['webkitSpeechRecognition'] ?? js.context['SpeechRecognition'];
      _recognition = js.JsObject(recognitionClass);

      // Configure recognition settings
      _recognition!['continuous'] = false;      // Stop after one result
      _recognition!['interimResults'] = false;  // Only return final results
      _recognition!['lang'] = 'en-US';          // Set language for recognition

      _recognition!['onresult'] = js.allowInterop((event) {
        try {
          final results = event['results'];
          if (results != null && results['length'] > 0) {
            final result = results[results['length'] - 1];
            if (result['isFinal'] == true) {
              final transcript = result[0]['transcript'];
              if (transcript != null && transcript.toString().trim().isNotEmpty) {
                if (!_completer!.isCompleted) {
                  _completer!.complete(transcript.toString().trim());
                }
              }
            }
          }
        } catch (e) {
          if (!_completer!.isCompleted) {
            _completer!.completeError('Error processing speech: $e');
          }
        }
      });

      _recognition!['onerror'] = js.allowInterop((event) {
        final error = event['error'] ?? 'unknown error';
        if (!_completer!.isCompleted) {
          _completer!.completeError('Speech error: $error');
        }
      });

      _recognition!['onend'] = js.allowInterop((event) {
        _isListening = false;
        if (!_completer!.isCompleted) {
          _completer!.completeError('Speech ended without result');
        }
      });

      _recognition!.callMethod('start');
      return await _completer!.future;
    } catch (e) {
      _isListening = false;
      _completer = null;
      throw Exception('Speech recognition failed: $e');
    }
  }

  static void stop() {
    try {
      _recognition?.callMethod('stop');
    } catch (e) {
      // Ignore stop errors
    }
    _isListening = false;
  }

  static bool get isListening => _isListening;
}

/// Web-based text-to-speech synthesis using browser's Speech Synthesis API
/// Provides an alternative to backend TTS Service for web platforms
/// Offers client-side speech synthesis with configurable voice parameters
class WebSpeechSynthesis {
  /// Checks if Web Speech Synthesis API is available in current browser
  /// Most modern browsers support speech synthesis functionality
  static bool get isSupported {
    try {
      return js.context['speechSynthesis'] != null;
    } catch (e) {
      return false;
    }
  }

  /// Converts text to speech using browser's synthesis engine
  /// Provides configurable voice parameters for natural-sounding speech
  /// Alternative to backend TTS Service for reduced server load
  static Future<void> speak(String text) async {
    if (!isSupported) {
      throw Exception('Speech synthesis not supported');
    }

    try {
      final synthesis = js.context['speechSynthesis'];
      final utteranceClass = js.context['SpeechSynthesisUtterance'];
      final utterance = js.JsObject(utteranceClass, [text]);
      
      // Configure voice settings for natural speech
      utterance['rate'] = 0.9;    // Slightly slower than default for clarity
      utterance['pitch'] = 1.0;   // Normal pitch
      utterance['volume'] = 0.8;  // Comfortable volume level

      final completer = Completer<void>();

      utterance['onend'] = js.allowInterop((event) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      utterance['onerror'] = js.allowInterop((event) {
        if (!completer.isCompleted) {
          completer.completeError('Speech synthesis error');
        }
      });

      synthesis.callMethod('speak', [utterance]);
      return completer.future;
    } catch (e) {
      throw Exception('Speech synthesis failed: $e');
    }
  }

  /// Stops any active speech synthesis
  /// Cancels current speech output immediately
  static void stop() {
    try {
      final synthesis = js.context['speechSynthesis'];
      synthesis?.callMethod('cancel');
    } catch (e) {
      // Ignore stop errors
    }
  }
}