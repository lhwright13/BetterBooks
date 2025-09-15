import 'package:flutter_test/flutter_test.dart';
import 'package:echowright_rebuilt/data/models/chat_models.dart';

void main() {
  group('ChatMessage Tests', () {
    test('should create ChatMessage from JSON', () {
      final json = {
        'id': '123',
        'content': 'Hello, world!',
        'type': 'text',
        'persona_id': 'gatsby',
        'persona_name': 'Jay Gatsby',
        'timestamp': '2024-01-01T12:00:00.000Z',
        'confidence_level': 0.95,
        'metadata': {'source': 'test'}
      };

      final message = ChatMessage.fromJson(json);

      expect(message.id, equals('123'));
      expect(message.content, equals('Hello, world!'));
      expect(message.type, equals(ChatMessageType.text));
      expect(message.personaId, equals('gatsby'));
      expect(message.personaName, equals('Jay Gatsby'));
      expect(message.confidenceLevel, equals(0.95));
      expect(message.metadata?['source'], equals('test'));
    });

    test('should convert ChatMessage to JSON', () {
      final message = ChatMessage(
        id: '123',
        content: 'Test message',
        type: ChatMessageType.voice,
        personaId: 'nick',
        personaName: 'Nick Carraway',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        confidenceLevel: 0.8,
        metadata: {'test': true},
      );

      final json = message.toJson();

      expect(json['id'], equals('123'));
      expect(json['content'], equals('Test message'));
      expect(json['type'], equals('voice'));
      expect(json['persona_id'], equals('nick'));
      expect(json['persona_name'], equals('Nick Carraway'));
      expect(json['confidence_level'], equals(0.8));
      expect(json['metadata']['test'], isTrue);
    });

    test('should copy ChatMessage with modifications', () {
      final original = ChatMessage(
        id: '123',
        content: 'Original',
        type: ChatMessageType.text,
        timestamp: DateTime(2024, 1, 1),
      );

      final modified = original.copyWith(content: 'Modified');

      expect(original.content, equals('Original'));
      expect(modified.content, equals('Modified'));
      expect(modified.id, equals(original.id));
      expect(modified.type, equals(original.type));
    });
  });

  group('BookPersona Tests', () {
    test('should create BookPersona from JSON', () {
      final json = {
        'id': '1',
        'persona_id': 'gatsby',
        'persona_name': 'jay_gatsby',
        'persona_display_name': 'Jay Gatsby',
        'persona_description': 'Millionaire with a mysterious past',
        'is_default': true,
        'sort_order': 1,
        'voice_config': {'voice': 'male-1'},
        'tts_config': {'speech_rate': 1.2, 'pitch': 1.0},
        'generation_config': {'temperature': 0.8}
      };

      final persona = BookPersona.fromJson(json);

      expect(persona.id, equals('1'));
      expect(persona.personaId, equals('gatsby'));
      expect(persona.personaName, equals('jay_gatsby'));
      expect(persona.personaDisplayName, equals('Jay Gatsby'));
      expect(persona.personaDescription, equals('Millionaire with a mysterious past'));
      expect(persona.isDefault, isTrue);
      expect(persona.sortOrder, equals(1));
      expect(persona.voiceConfig?['voice'], equals('male-1'));
      expect(persona.ttsConfig?['speech_rate'], equals(1.2));
      expect(persona.generationConfig?['temperature'], equals(0.8));
    });

    test('should convert BookPersona to JSON', () {
      final persona = BookPersona(
        id: '1',
        personaId: 'gatsby',
        personaName: 'jay_gatsby',
        personaDisplayName: 'Jay Gatsby',
        isDefault: true,
        sortOrder: 1,
        voiceConfig: {'voice': 'male-1'},
        ttsConfig: {'speech_rate': 1.2},
      );

      final json = persona.toJson();

      expect(json['id'], equals('1'));
      expect(json['persona_id'], equals('gatsby'));
      expect(json['persona_display_name'], equals('Jay Gatsby'));
      expect(json['is_default'], isTrue);
      expect(json['voice_config']['voice'], equals('male-1'));
      expect(json['tts_config']['speech_rate'], equals(1.2));
    });
  });

  group('ChatSession Tests', () {
    test('should add message to session', () {
      final session = ChatSession(
        id: '1',
        bookId: 'gatsby',
        messages: [],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        context: {},
      );

      final message = ChatMessage(
        id: '1',
        content: 'Hello',
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
      );

      final updatedSession = session.addMessage(message);

      expect(updatedSession.messages.length, equals(1));
      expect(updatedSession.messages.first.content, equals('Hello'));
      expect(updatedSession.updatedAt.isAfter(session.updatedAt), isTrue);
    });
  });

  group('VoiceChatConfig Tests', () {
    test('should create default config', () {
      final config = VoiceChatConfig.defaultConfig();

      expect(config.vadSensitivity, equals('medium'));
      expect(config.silenceTimeoutMs, equals(2000));
      expect(config.maxConversationLength, equals(50));
      expect(config.continuousListening, isTrue);
      expect(config.interruptEnabled, isTrue);
      expect(config.voiceChatEnabled, isTrue);
      expect(config.personaVoiceSwitching, isTrue);
      expect(config.responseTimeoutSeconds, equals(30));
    });

    test('should create config from JSON', () {
      final json = {
        'vad_sensitivity': 'high',
        'silence_timeout_ms': 3000,
        'max_conversation_length': 100,
        'continuous_listening': false,
        'interrupt_enabled': false,
        'voice_chat_enabled': true,
        'persona_voice_switching': false,
        'response_timeout_seconds': 60,
      };

      final config = VoiceChatConfig.fromJson(json);

      expect(config.vadSensitivity, equals('high'));
      expect(config.silenceTimeoutMs, equals(3000));
      expect(config.maxConversationLength, equals(100));
      expect(config.continuousListening, isFalse);
      expect(config.interruptEnabled, isFalse);
      expect(config.personaVoiceSwitching, isFalse);
      expect(config.responseTimeoutSeconds, equals(60));
    });
  });

  group('CompletionRequest Tests', () {
    test('should convert to JSON', () {
      final request = CompletionRequest(
        prompt: 'Hello, Gatsby',
        personaId: 'gatsby',
        context: {
          'book_id': 'great-gatsby',
          'chapter_id': '1',
          'reading_position': 0.5,
        },
        generationConfig: {
          'temperature': 0.7,
          'max_tokens': 1000,
        },
      );

      final json = request.toJson();

      expect(json['prompt'], equals('Hello, Gatsby'));
      expect(json['persona_id'], equals('gatsby'));
      expect(json['context']['book_id'], equals('great-gatsby'));
      expect(json['generation_config']['temperature'], equals(0.7));
    });
  });

  group('CompletionResponse Tests', () {
    test('should create from JSON', () {
      final json = {
        'response': 'Hello, old sport!',
        'persona_id': 'gatsby',
        'persona_name': 'Jay Gatsby',
        'metadata': {'confidence': 0.9},
      };

      final response = CompletionResponse.fromJson(json);

      expect(response.response, equals('Hello, old sport!'));
      expect(response.personaId, equals('gatsby'));
      expect(response.personaName, equals('Jay Gatsby'));
      expect(response.metadata?['confidence'], equals(0.9));
    });
  });
}