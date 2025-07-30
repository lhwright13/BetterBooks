// Simplified speech service - just checks if speech might be available
class SpeechService {
  static bool get isSupported {
    // For now, always return false to use text input
    // This avoids all the JavaScript interop issues
    return false;
  }

  static Future<String> startListening() async {
    throw Exception('Speech recognition not available - please use text input');
  }

  static void stopListening() {
    // No-op
  }

  static bool get isListening => false;
}