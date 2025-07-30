import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;

// Platform-specific imports
import 'dart:html' as html if (dart.library.html) 'dart:html';

class AudioPlayerService {
  static dynamic _audioElement;

  static Future<void> playBase64Audio(String base64Audio) async {
    try {
      // Only supported on web platform
      if (Platform.isIOS || Platform.isAndroid || Platform.isMacOS) {
        print('Audio playback not supported on this platform');
        return;
      }
      
      // Stop any existing audio
      _audioElement?.pause();
      
      // Create audio element
      _audioElement = html.AudioElement();
      
      // Convert base64 to blob URL
      final bytes = base64Decode(base64Audio);
      final blob = html.Blob([bytes], 'audio/wav');
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      // Set audio source and play
      _audioElement!.src = url;
      _audioElement!.autoplay = true;
      
      // Wait for audio to finish playing
      await _waitForAudioEnd();
      
      // Clean up
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      throw Exception('Failed to play audio: $e');
    }
  }

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

  static void stop() {
    _audioElement?.pause();
    _audioElement = null;
  }
}