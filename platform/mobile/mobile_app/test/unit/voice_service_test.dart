import 'package:flutter_test/flutter_test.dart';
import 'package:echowright_rebuilt/services/voice_service.dart';

void main() {
  late VoiceService voiceService;

  setUp(() {
    voiceService = VoiceService();
  });

  group('VoiceService Tests', () {
    test('should initialize with idle state', () {
      expect(voiceService.state, equals(VoiceChatState.idle));
      expect(voiceService.isListening, isFalse);
      expect(voiceService.isSpeaking, isFalse);
      expect(voiceService.wordsSpoken, isEmpty);
      expect(voiceService.confidenceLevel, equals(0.0));
    });

    test('should reset to idle state', () {
      // Simulate some activity
      voiceService.reset();
      
      expect(voiceService.state, equals(VoiceChatState.idle));
      expect(voiceService.wordsSpoken, isEmpty);
      expect(voiceService.confidenceLevel, equals(0.0));
    });
  });

  group('VoiceChatState Extension Tests', () {
    test('should provide correct display names', () {
      expect(VoiceChatState.idle.displayName, equals('Ready'));
      expect(VoiceChatState.listening.displayName, equals('Listening...'));
      expect(VoiceChatState.processing.displayName, equals('Processing...'));
      expect(VoiceChatState.speaking.displayName, equals('Speaking...'));
      expect(VoiceChatState.error.displayName, equals('Error'));
    });
  });

  tearDown(() {
    voiceService.dispose();
  });
}