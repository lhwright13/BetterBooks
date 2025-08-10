/**
 * audio_player_service.dart - Web-based audio playback service for EchoWright
 * 
 * This file provides audio playback functionality specifically for the web platform
 * in the EchoWright audiobook companion app. It handles base64-encoded audio data
 * from the TTS Service and plays it through the browser's HTML5 audio API.
 * 
 * Key responsibilities:
 * - Play base64-encoded audio data from TTS synthesis
 * - Handle web-specific audio playback using HTML5 AudioElement
 * - Manage audio lifecycle (play, pause, stop, cleanup)
 * - Convert base64 audio to playable blob URLs
 * - Handle platform compatibility (web-only implementation)
 * 
 * Platform support:
 * - Web: Full support using HTML5 AudioElement
 * - Mobile/Desktop: Limited support (prints warning message)
 * - Audio format: Supports WAV files from TTS Service
 * 
 * Backend integration:
 * - Receives base64 audio data from TTS Service via API Gateway
 * - Audio data represents synthesized speech from AI personas
 * - Complements voice input/output in chat conversations
 * 
 * Note: This is a web-specific implementation. For full mobile support,
 * see audio_player_service_stub.dart which uses the audioplayers package.
 */

import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;

// Platform-specific imports for web HTML5 audio functionality
import 'dart:html' as html if (dart.library.html) 'dart:html';

/// Service for playing base64-encoded audio data in web browsers
/// Handles TTS audio playback using HTML5 AudioElement API
class AudioPlayerService {
  static dynamic _audioElement; // Current HTML AudioElement for playback

  /// Plays base64-encoded audio data from TTS Service
  /// Converts base64 to blob URL and plays through HTML5 AudioElement
  /// Only supported on web platform; shows warning on mobile/desktop
  static Future<void> playBase64Audio(String base64Audio) async {
    try {
      // Platform compatibility check - only web platform supports HTML5 audio
      if (Platform.isIOS || Platform.isAndroid || Platform.isMacOS) {
        print('Audio playback not supported on this platform');
        return;
      }
      
      // Stop any currently playing audio to avoid overlaps
      _audioElement?.pause();
      
      // Create new HTML5 AudioElement for playback
      _audioElement = html.AudioElement();
      
      // Convert base64 audio data to binary and create blob URL
      final bytes = base64Decode(base64Audio);
      final blob = html.Blob([bytes], 'audio/wav'); // WAV format from TTS
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      // Configure audio element and start playback
      _audioElement!.src = url;
      _audioElement!.autoplay = true;
      
      // Wait for audio playback to complete
      await _waitForAudioEnd();
      
      // Clean up blob URL to prevent memory leaks
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      throw Exception('Failed to play audio: $e');
    }
  }

  /// Waits for audio playback to complete using event listeners
  /// Returns when audio ends or encounters an error
  /// Used to properly sequence TTS audio playback
  static Future<void> _waitForAudioEnd() async {
    if (_audioElement == null) return;
    
    final completer = Completer<void>();
    
    _audioElement!.onEnded.listen((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    
    _audioElement!.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError('Audio playback error');
      }
    });
    
    return completer.future;
  }

  /// Stops current audio playback and cleans up resources
  /// Pauses the audio element and releases references
  static void stop() {
    _audioElement?.pause();
    _audioElement = null;
  }
}