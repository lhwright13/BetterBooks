library;

/// Chat-related data models for voice and text conversations

class ChatMessage {
  final String id;
  final String content;
  final ChatMessageType type;
  final String? personaId;
  final String? personaName;
  final DateTime timestamp;
  final double? confidenceLevel; // For speech recognition confidence
  final Map<String, dynamic>? metadata;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    this.personaId,
    this.personaName,
    required this.timestamp,
    this.confidenceLevel,
    this.metadata,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      type: ChatMessageType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => ChatMessageType.text,
      ),
      personaId: json['persona_id']?.toString(),
      personaName: json['persona_name']?.toString(),
      timestamp: DateTime.parse(json['timestamp']),
      confidenceLevel: json['confidence_level']?.toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type.name,
      'persona_id': personaId,
      'persona_name': personaName,
      'timestamp': timestamp.toIso8601String(),
      'confidence_level': confidenceLevel,
      'metadata': metadata,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? content,
    ChatMessageType? type,
    String? personaId,
    String? personaName,
    DateTime? timestamp,
    double? confidenceLevel,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      personaId: personaId ?? this.personaId,
      personaName: personaName ?? this.personaName,
      timestamp: timestamp ?? this.timestamp,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      metadata: metadata ?? this.metadata,
    );
  }
}

enum ChatMessageType {
  text,        // Regular text message
  voice,       // Voice message (transcribed)
  system,      // System message
  error,       // Error message
}

/// Book-specific persona model with voice configuration
class BookPersona {
  final String id;
  final String personaId;
  final String personaName;
  final String personaDisplayName;
  final String? personaDescription;
  final bool isDefault;
  final String? customPrompt;
  final int sortOrder;
  final Map<String, dynamic>? voiceConfig;
  final Map<String, dynamic>? ttsConfig;
  final Map<String, dynamic>? generationConfig;

  const BookPersona({
    required this.id,
    required this.personaId,
    required this.personaName,
    required this.personaDisplayName,
    this.personaDescription,
    required this.isDefault,
    this.customPrompt,
    required this.sortOrder,
    this.voiceConfig,
    this.ttsConfig,
    this.generationConfig,
  });

  factory BookPersona.fromJson(Map<String, dynamic> json) {
    return BookPersona(
      id: json['id']?.toString() ?? '',
      personaId: json['persona_id']?.toString() ?? '',
      personaName: json['persona_name']?.toString() ?? '',
      personaDisplayName: json['persona_display_name']?.toString() ?? '',
      personaDescription: json['persona_description']?.toString(),
      isDefault: json['is_default'] ?? false,
      customPrompt: json['custom_prompt']?.toString(),
      sortOrder: json['sort_order'] ?? 0,
      voiceConfig: json['voice_config'] as Map<String, dynamic>?,
      ttsConfig: json['tts_config'] as Map<String, dynamic>?,
      generationConfig: json['generation_config'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'persona_id': personaId,
      'persona_name': personaName,
      'persona_display_name': personaDisplayName,
      'persona_description': personaDescription,
      'is_default': isDefault,
      'custom_prompt': customPrompt,
      'sort_order': sortOrder,
      'voice_config': voiceConfig,
      'tts_config': ttsConfig,
      'generation_config': generationConfig,
    };
  }
}

/// Response from book personas endpoint
class BookPersonasResponse {
  final String bookId;
  final String bookTitle;
  final List<BookPersona> personas;

  const BookPersonasResponse({
    required this.bookId,
    required this.bookTitle,
    required this.personas,
  });

  factory BookPersonasResponse.fromJson(Map<String, dynamic> json) {
    return BookPersonasResponse(
      bookId: json['book_id']?.toString() ?? '',
      bookTitle: json['book_title']?.toString() ?? '',
      personas: (json['personas'] as List<dynamic>?)
          ?.map((persona) => BookPersona.fromJson(persona))
          .toList() ?? [],
    );
  }
}

/// Chat session model for managing conversation state
class ChatSession {
  final String id;
  final String bookId;
  final String? chapterId;
  final String? personaId;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> context;

  const ChatSession({
    required this.id,
    required this.bookId,
    this.chapterId,
    this.personaId,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    required this.context,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id']?.toString() ?? '',
      bookId: json['book_id']?.toString() ?? '',
      chapterId: json['chapter_id']?.toString(),
      personaId: json['persona_id']?.toString(),
      messages: (json['messages'] as List<dynamic>?)
          ?.map((message) => ChatMessage.fromJson(message))
          .toList() ?? [],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      context: json['context'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter_id': chapterId,
      'persona_id': personaId,
      'messages': messages.map((message) => message.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'context': context,
    };
  }

  ChatSession copyWith({
    String? id,
    String? bookId,
    String? chapterId,
    String? personaId,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? context,
  }) {
    return ChatSession(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      personaId: personaId ?? this.personaId,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      context: context ?? this.context,
    );
  }

  ChatSession addMessage(ChatMessage message) {
    return copyWith(
      messages: [...messages, message],
      updatedAt: DateTime.now(),
    );
  }
}

/// Voice chat configuration from backend
class VoiceChatConfig {
  final String vadSensitivity;
  final int silenceTimeoutMs;
  final int maxConversationLength;
  final bool continuousListening;
  final bool interruptEnabled;
  final bool voiceChatEnabled;
  final bool personaVoiceSwitching;
  final int responseTimeoutSeconds;

  const VoiceChatConfig({
    required this.vadSensitivity,
    required this.silenceTimeoutMs,
    required this.maxConversationLength,
    required this.continuousListening,
    required this.interruptEnabled,
    required this.voiceChatEnabled,
    required this.personaVoiceSwitching,
    required this.responseTimeoutSeconds,
  });

  factory VoiceChatConfig.fromJson(Map<String, dynamic> json) {
    return VoiceChatConfig(
      vadSensitivity: json['vad_sensitivity'] ?? 'medium',
      silenceTimeoutMs: json['silence_timeout_ms'] ?? 2000,
      maxConversationLength: json['max_conversation_length'] ?? 50,
      continuousListening: json['continuous_listening'] ?? true,
      interruptEnabled: json['interrupt_enabled'] ?? true,
      voiceChatEnabled: json['voice_chat_enabled'] ?? true,
      personaVoiceSwitching: json['persona_voice_switching'] ?? true,
      responseTimeoutSeconds: json['response_timeout_seconds'] ?? 30,
    );
  }

  factory VoiceChatConfig.defaultConfig() {
    return const VoiceChatConfig(
      vadSensitivity: 'medium',
      silenceTimeoutMs: 2000,
      maxConversationLength: 50,
      continuousListening: true,
      interruptEnabled: true,
      voiceChatEnabled: true,
      personaVoiceSwitching: true,
      responseTimeoutSeconds: 30,
    );
  }
}

/// AI completion request model
class CompletionRequest {
  final String prompt;
  final String? personaId;
  final Map<String, dynamic> context;
  final Map<String, dynamic>? generationConfig;

  const CompletionRequest({
    required this.prompt,
    this.personaId,
    required this.context,
    this.generationConfig,
  });

  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      'persona_id': personaId,
      'context': context,
      'generation_config': generationConfig,
    };
  }
}

/// AI completion response model
class CompletionResponse {
  final String response;
  final String? personaId;
  final String? personaName;
  final Map<String, dynamic>? metadata;

  const CompletionResponse({
    required this.response,
    this.personaId,
    this.personaName,
    this.metadata,
  });

  factory CompletionResponse.fromJson(Map<String, dynamic> json) {
    return CompletionResponse(
      response: json['response']?.toString() ?? json['text']?.toString() ?? '',
      personaId: json['persona_id']?.toString(),
      personaName: json['persona_name']?.toString(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Voice chat response model
class VoiceChatResponse {
  final String transcription;
  final String responseText;
  final String? responseAudio; // Base64 or URL to audio response
  final String? personaId;
  final String? personaName;
  final Map<String, dynamic>? metadata;

  const VoiceChatResponse({
    required this.transcription,
    required this.responseText,
    this.responseAudio,
    this.personaId,
    this.personaName,
    this.metadata,
  });

  factory VoiceChatResponse.fromJson(Map<String, dynamic> json) {
    return VoiceChatResponse(
      transcription: json['transcription']?.toString() ?? '',
      responseText: json['response_text']?.toString() ?? json['response']?.toString() ?? '',
      responseAudio: json['response_audio']?.toString(),
      personaId: json['persona_id']?.toString(),
      personaName: json['persona_name']?.toString(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transcription': transcription,
      'response_text': responseText,
      'response_audio': responseAudio,
      'persona_id': personaId,
      'persona_name': personaName,
      'metadata': metadata,
    };
  }
}