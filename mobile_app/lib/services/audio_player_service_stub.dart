import 'dart:async';

class AudioPlayerService {
  static Future<void> playBase64Audio(String base64Audio) async {
    print('Audio playback not supported on this platform');
    // For mobile platforms, we could integrate with the audioplayers package
    // but for now just log that it's not implemented
  }

  static void stop() {
    // No-op for non-web platforms
  }
}