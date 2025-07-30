import 'dart:async';

class WebSpeechService {
  static bool get isSupported => false;

  static Future<String> startListening() async {
    throw Exception('Speech recognition not supported on this platform');
  }

  static void stopListening() {
    // No-op for non-web platforms
  }

  static void stop() {
    // No-op for non-web platforms
  }

  static bool get isTTSSupported => false;

  static Future<void> speak(String text, {double rate = 1.0, double pitch = 1.0}) async {
    throw Exception('Text-to-speech not supported on this platform');
  }

  static void stopSpeaking() {
    // No-op for non-web platforms
  }
}

class WebSpeechSynthesis {
  static bool get isSupported => false;

  static Future<void> speak(String text, {double rate = 1.0, double pitch = 1.0}) async {
    print('WebSpeechSynthesis not supported on this platform');
  }

  static void cancel() {
    // No-op for non-web platforms
  }
}