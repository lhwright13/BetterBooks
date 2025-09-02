/**
 * persona.dart - AI persona configuration model for EchoWright
 * 
 * This file defines the Persona model that represents different AI characters
 * users can interact with in the EchoWright audiobook companion app. Each persona
 * has unique personality traits, voice settings, and conversation styles.
 * 
 * Key responsibilities:
 * - Model AI persona configurations and metadata
 * - Handle voice synthesis settings for text-to-speech
 * - Support loading persona configs from backend
 * - Enable persona selection in chat interfaces
 * 
 * Backend integration:
 * - Persona configs loaded from LLM Gateway service
 * - Voice settings used by TTS Service for speech synthesis
 * - Persona names map to configuration files in llm_configs/
 * - Display data used in UI persona selection screens
 * 
 * Examples:
 * - "Nick Carraway" persona for Great Gatsby discussions
 * - "English Teacher" persona for literary analysis
 * - "Language Tutor" persona for vocabulary help
 */

/// Represents an AI persona that users can chat with about books
/// Each persona has distinct personality, voice, and conversation style
class Persona {
  final String id;                      // Database UUID identifier
  final String name;                    // Internal persona identifier (maps to config file)
  final String displayName;             // User-friendly name shown in UI
  final String description;             // Description of persona's role and style
  final String? basePrompt;             // Full persona system prompt (optional for UI)
  final String voice;                   // Voice model ID for text-to-speech synthesis
  final Map<String, dynamic> voiceConfig; // Additional voice synthesis parameters
  final Map<String, dynamic> generationConfig; // LLM generation parameters
  final Map<String, dynamic> ttsConfig; // Text-to-speech configuration
  final bool isGlobal;                  // True if persona works with any book
  final bool isDefault;                 // True if this is the default persona for a book
  final int sortOrder;                  // Display order for book-specific personas

  Persona({
    required this.id,
    required this.name,
    required this.displayName,
    required this.description,
    this.basePrompt,
    required this.voice,
    this.voiceConfig = const {},
    this.generationConfig = const {},
    this.ttsConfig = const {},
    this.isGlobal = false,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  /// Creates Persona from JSON configuration data from API Gateway
  /// Supports both book-specific persona responses and general persona data
  factory Persona.fromJson(Map<String, dynamic> json) {
    // Handle book-specific persona format (from /bookstore/books/{id}/personas)
    if (json.containsKey('persona_id')) {
      return Persona(
        id: json['persona_id'] ?? '',
        name: json['persona_name'] ?? '',
        displayName: json['persona_display_name'] ?? json['persona_name'] ?? '',
        description: json['persona_description'] ?? '',
        basePrompt: json['custom_prompt'], // Book-specific custom prompt
        voice: _extractVoiceFromTtsConfig(json['tts_config']),
        voiceConfig: json['voice_config'] ?? {},
        generationConfig: json['generation_config'] ?? {},
        ttsConfig: json['tts_config'] ?? {},
        isGlobal: false, // Book-specific personas are not global
        isDefault: json['is_default'] ?? false,
        sortOrder: json['sort_order'] ?? 0,
      );
    }
    
    // Handle general persona format (from /personas/{id} or /personas)
    return Persona(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      displayName: json['display_name'] ?? json['name'] ?? '',
      description: json['description'] ?? '',
      basePrompt: json['base_prompt'],
      voice: _extractVoiceFromTtsConfig(json['tts_config']) ?? 'en-US-Neural2-C',
      voiceConfig: json['voice_config'] ?? {},
      generationConfig: json['generation_config'] ?? {},
      ttsConfig: json['tts_config'] ?? {},
      isGlobal: json['is_global'] ?? false,
      isDefault: false, // Not applicable for general persona list
      sortOrder: 0,
    );
  }

  /// Extract voice name from TTS config structure
  static String? _extractVoiceFromTtsConfig(dynamic ttsConfig) {
    if (ttsConfig is Map<String, dynamic>) {
      final voice = ttsConfig['voice'];
      if (voice is Map<String, dynamic>) {
        return voice['name'] ?? 'en-US-Neural2-C';
      }
    }
    return null;
  }

  /// Convert persona to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'description': description,
      'base_prompt': basePrompt,
      'voice_config': voiceConfig,
      'generation_config': generationConfig,
      'tts_config': ttsConfig,
      'is_global': isGlobal,
    };
  }
}