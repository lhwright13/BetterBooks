/**
 * persona.dart - AI persona configuration model for Muuchi
 * 
 * This file defines the Persona model that represents different AI characters
 * users can interact with in the Muuchi audiobook companion app. Each persona
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
  final String name;                    // Internal persona identifier (maps to config file)
  final String displayName;             // User-friendly name shown in UI
  final String description;             // Description of persona's role and style
  final String voice;                   // Voice model ID for text-to-speech synthesis
  final Map<String, dynamic> voiceConfig; // Additional voice synthesis parameters

  Persona({
    required this.name,
    required this.displayName,
    required this.description,
    required this.voice,
    required this.voiceConfig,
  });

  /// Creates Persona from JSON configuration data
  /// Typically loaded from LLM Gateway's persona endpoint
  /// Provides sensible defaults for missing configuration values
  factory Persona.fromJson(Map<String, dynamic> json) {
    return Persona(
      name: json['name'] ?? '',
      displayName: json['display_name'] ?? json['name'] ?? '',
      description: json['description'] ?? '',
      voice: json['voice'] ?? 'en-US-Neural2-C', // Default Google TTS voice
      voiceConfig: json['voice_config'] ?? {},
    );
  }
}